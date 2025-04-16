"""
Note: Input buffers for all functions are assumed to be 
UInt8 in big endian order as specified by the OSC protocol.
"""
#-------------------------------------------
# API Functions
#-------------------------------------------
"""
    parseOSC(buffer)

Parse `buffer` into an `OSCBundle` if it starts with '#bundle'.
Otherwise parse buffer into an `OSCMessage`

# Examples
```julia-repl
julia> parseOSC(UInt8[0x2f, 0x74, 0x65, 0x73, 0x74, 0x00, 0x00, 0x00, 0x2c, 0x00, 0x00, 0x00])
OSCMessage:
address: /test
format: 
args: Any[]

julia> parseOSC(UInt8[0x23, 0x62, 0x75, 0x6e, 0x64, 0x6c, 0x65, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x04, 0xd2, 0x00, 0x00, 0x00, 0x0c, 0x2f, 0x74, 0x65, 0x73, 0x74, 0x00, 0x00, 0x00, 0x2c, 0x00, 0x00, 0x00]
       )
OSCBundle:
timetag: 1234

element:OSCBundleElement:
size: 12
content: OSCMessage:
address: /test
format: 
args: Any[]
```
"""
function parseOSC(buffer::Vector{UInt8})::Union{OSCBundle, OSCMessage}
    if length(buffer) % 4 != 0
        throw(OSCParseException("Buffer is not 32 bit aligned."))
    end

    if isBundle(buffer)
        return parseBundle(buffer)
    else
        return parseMessage(buffer)
    end
end


"""
Returns true if the buffer refers to a bundle of OSC messages. False otherwise.
"""
function isBundle(buffer::Vector{UInt8})::Bool
    # check if first 8 bytes are "#bundle"
    return length(buffer) > 7 && unsafe_load(Ptr{UInt64}(Base.pointer(buffer)), 1) == BUNDLE_ID
end

"""
Parse a buffer containing a bundle of OSC messages.
"""
function parseBundle(buffer::Vector{UInt8})::OSCBundle
    # first 8 bytes are '#bundle '
    # second 8 bytes are time tag
    if length(buffer) < 16
        throw(OSCParseException("Bundle is shorter than 16 bytes and can not contain a valid time tag!"))
    end
    @inbounds timetag = decode_uint64(buffer[9:16])

    # we already know the bundle is 32 bit aligned
    elements = Vector{BundleElement}()
    idx = 17
    while idx < length(buffer)
        # size of bundle element
        @inbounds size = decode_uint32(buffer[idx:idx+3])

        # align with end of data
        new_idx = align_32(idx + size)

        if new_idx-1 > length(buffer)
            throw(OSCParseException("Bundle element size extends beyond buffer. Index: $(new_idx-1)"))
        end

        # this many bytes to parse
        @inbounds data_section = buffer[idx+4:new_idx-1]
        elem = OSCBundleElement(length(data_section), parseOSC(data_section))
        push!(elements, elem)
        idx = new_idx
    end
    
    return OSCBundle(timetag, elements)
end

"""
Parse a buffer containing an OSC message
"""
function parseMessage(buffer::Vector{UInt8})::OSCMessage
    # extract address
    # - begins with '/'
    # - ends on 1 to 3 null bytes
    if buffer[1] != UInt8('/')
        throw(OSCParseException("Message string does not start with '/'."))
    end

    # get address string
    null_found = false
    format_start = 0
    addr_end = 0
    comma = 0
    for i in 2:length(buffer)
        if buffer[i] == 0x00
            null_found = true
            comma = align_32(i)
            addr_end = i-1
            break
        end
    end

    if !null_found
        throw(OSCParseException("Address string is not null terminated."))
    end

    if comma > length(buffer) || buffer[comma] != UInt8(',')
        # no format string here
        return OSCMessage(buffer, length(buffer), addr_end, -1, -1, -1)
    end

    # get format string
    null_found = false
    format_start = comma + 1
    format_end = format_start
    for i in format_start:length(buffer)
        if buffer[i] == 0x00
            null_found = true
            format_end = i-1
            break
        end
    end

    if !null_found
        throw(OSCParseException("Format string is not null terminated."))
    end

    # for element in format: parse type + forward pointer
    # TODO should we actually parse here or just trust whatever
    # we got is a valid OSC packet?

    return OSCMessage(buffer, length(buffer), addr_end, format_start, format_end, align_32(format_end+1))
end

"""
Parse the argument of type `c` starting at `idx` in the `buffer`.
Return the argument and the following 32 bit aligned index.
"""
@inline function parseArgument(idx::UInt64, buffer::Vector{UInt8}, c::Char)::Tuple{Any, UInt64}
    # 32 bit number types
    if c ∈ "ifrc"
        if length(buffer) < idx+3
            throw(OSCParseException("Out of space to parse a 32 bit number from buffer!"))
        end

        if c ∈ "rc"
            # RGBA and ascii character don't change with endianness
            @inbounds arg = reinterpret(UInt32, buffer[idx:idx+3])[1]
        end
        if c == 'i'
            @inbounds arg = reinterpret(Int32, decode_uint32(buffer[idx:idx+3]))[1]
        end
        if c == 'f'
            @inbounds arg = reinterpret(Float32, decode_uint32(buffer[idx:idx+3]))[1]
        end
        return arg, idx+4
    end

    # osc string and "Symbol" string
    if c ∈ "sS"
        for i in idx:length(buffer)
            if buffer[i] == 0x00
                return StringView(buffer[idx:i-1]), align_32(i)
            end
        end

        throw(OSCParseException("Argument string is not null terminated."))       
    end

    # binary blob
    if c == 'b'
        # 32 bit big endian size count
        # followed by that many bytes and additional null bytes for alignment
        if length(buffer) < idx+3
            throw(OSCParseException("Out of space to parse a 32 bit blob size from buffer!"))
        end

        data_length = decode_uint32(buffer[idx:idx+3])
        total_length = 4 + data_length

        if length(buffer) < idx + total_length - 1
            throw(OSCParseException("Out of space to parse blob of size $(total_length)!"))
        end

        @inbounds data = buffer[idx+4:idx+3+data_length]
        arg = OSCBlob(data_length, data)

        return arg, align_32(idx+data_length)
    end

    # 64 bit number types
    if c ∈ "hdt"
        if length(buffer) < idx+7
            throw(OSCParseException("Out of space to parse a 64 bit number from buffer!"))
        end

        if c == 'h'
            @inbounds arg = reinterpret(Int64, decode_uint64(buffer[idx:idx+7]))
        end
        if c == 'd'
            @inbounds arg = reinterpret(Float64, decode_uint64(buffer[idx:idx+7]))
        end
        if c == 't'
            @inbounds arg = decode_uint64(buffer[idx:idx+7])
        end

        return arg, idx+8
    end
    

    # midi - 4 byte vector
    if c == 'm'
        if length(buffer) < idx+3
            throw(OSCParseException("Out of space to parse a 32 bit midi from buffer!"))
        end

        @inbounds arg = buffer[idx:idx+3]
        return arg, idx+4
    end

    # empty fields: T, F, N, I - allocate no bytes!
    if c ∈ "TFNI"
        if c == 'T'
            arg = true
        elseif c == 'F'
            arg = false
        elseif c ∈ "IN"
            arg = nothing
        end

        return arg, idx
    end

    # TODO not yet supported: array type '[' and ']'
    throw(OSCParseException("Got argument of unsupported type: $c"))
end

"""
Encode the given `arg` of type `c` to its network output byte vector.
"""
function encodeArgument!(data::Vector{UInt8}, idx::Int64, arg::Union{Int32, Float32})::Int64
    # if
    encode_uint32!(data, idx, arg)
    return idx+4
end

function encodeArgument!(data::Vector{UInt8}, idx::Int64, arg::Union{Int64, UInt64, Float64})::Int64
    # hdt
    encode_uint64!(data, idx, arg)
    return idx+8
end

function encodeArgument!(data::Vector{UInt8}, idx::Int64, arg::StringView)::Int64
    # Ss
    @inbounds data[idx:idx+length(arg.data)-1] = arg.data
    return align_32(idx+length(arg.data)+1)
end

function encodeArgument!(data::Vector{UInt8}, idx::Int64, arg::Vector{UInt8})::Int64
    # m
    data[idx:idx+3] = arg
    return idx+4
end

function encodeArgument!(data::Vector{UInt8}, idx::Int64, arg::UInt32)::Int64
    # rc
    data[idx:idx+3] = reinterpret(UInt8, [arg])
    return idx+4
end

function encodeArgument!(data::Vector{UInt8}, idx::Int64, arg::OSCBlob)::Int64
    # b
    encode_uint32!(data, idx, arg.size)
    @inbounds data[idx+4:idx+3+arg.size] = arg.data
    return idx + 4 + arg.size
end

function encodeArgument!(data::Vector{UInt8}, idx::Int64, arg::Union{Nothing, Bool})::Int64
    # TFNI
    return idx
end

"""
    encodedOSCSize(msg)
    encodedOSCSize(bundle)

Calculate the encoded size of the given `msg` or `bundle` in bytes.
"""
function encodedOSCSize(msg::OSCMessage)::Int64
    return msg.size
end

function encodedOSCSize(bundle::OSCBundle)::Int64
    # 8 bytes for #bundle
    # 8 bytes for timetag
    size = 16

    # 4 bytes per element (size number)
    # size of each element
    # no padding because by definition size must be 32 bit aligned
    for e in bundle.elements
        size += 4 + e.size
    end

    return size
end

"""
    encodeOSC(msg)
    encodeOSC(bundle)

Encode the given `msg` or `bundle` into its network output byte vector.

# Examples
```julia-repl
julia> println(encodeOSC(OSCMessage("/test", "T", true)))
UInt8[0x2f, 0x74, 0x65, 0x73, 0x74, 0x00, 0x00, 0x00, 0x2c, 0x54, 0x00, 0x00]


julia> println(encodeOSC(OSCBundle(UInt64(1234), [OSCBundleElement(OSCMessage("/test", "T", true))])))
UInt8[0x23, 0x62, 0x75, 0x6e, 0x64, 0x6c, 0x65, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x04, 0xd2, 0x00, 0x00, 0x00, 0x0c, 0x2f, 0x74, 0x65, 0x73, 0x74, 0x00, 0x00, 0x00, 0x2c, 0x54, 0x00, 0x00]
```
"""
function encodeOSC(msg::OSCMessage)::Vector{UInt8}
    return msg.data[1:msg.size]
end

function encodeOSC(bundle::OSCBundle)::Vector{UInt8}
    # add "#bundle"
    data = zeros(UInt8, encodedOSCSize(bundle))
    @inbounds data[1:8] = BUNDLE_VEC

    # encode timetag
    encode_uint64!(data, 9, bundle.timetag)
    idx = 17

    # encode elements
    for e in bundle.elements
        encoded_content = encodeOSC(e.content)
        encode_uint32!(data, idx, e.size)
        @inbounds data[idx+4:idx+3+length(encoded_content)] = encoded_content
        idx += 4 + length(encoded_content)
    end

    return data
end