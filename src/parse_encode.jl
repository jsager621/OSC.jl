"""
Note: Input buffers for all functions are assumed to be 
UInt8 in big endian order as specified by the OSC protocol.
"""

# "#bundle"
const BUNDLE_VEC = UInt8[0x23, 0x62, 0x75, 0x6e, 0x64, 0x6c, 0x65, 0x00]
const BUNDLE_ID = unsafe_load(Ptr{UInt64}(Base.pointer(BUNDLE_VEC)), 1)

#-------------------------------------------
# Helper Functions
#-------------------------------------------
# set x to the next 32 bit aligned starting index
# i.e. x = 3 => align_32(x) = 5
align_32(x) = 4 - (x - 1) % 4 + x

function pad_32(data::Vector{UInt8})::Vector{UInt8}
    pad_len = align_32(length(data)) - 1 - length(data)
    data = vcat(data, zeros(UInt8, pad_len))
    return data
end

# put UInt32 into big endian byte array
function encode_uint32(val::UInt32)::Vector{UInt8}
    ptr = pointer(reinterpret(UInt8, [val]))
    out = zeros(UInt8, 4)
    out[4] = unsafe_load(ptr)
    out[3] = unsafe_load(ptr+1)
    out[2] = unsafe_load(ptr+2)
    out[1] = unsafe_load(ptr+3)
    return out
end

# read uint32 from big endian vector
function decode_uint32(data::Vector{UInt8})::UInt32
    return (UInt32(data[4]) << 0) | (UInt32(data[3]) << 8) | (UInt32(data[2]) << 16) | (UInt32(data[1]) << 24)
end

# put UInt64 into big endian byte array
function encode_uint64(val::UInt64)::Vector{UInt8}
    ptr = pointer(reinterpret(UInt8, [val]))
    out = zeros(UInt8, 8)
    out[8] = unsafe_load(ptr)
    out[7] = unsafe_load(ptr+1)
    out[6] = unsafe_load(ptr+2)
    out[5] = unsafe_load(ptr+3)
    out[4] = unsafe_load(ptr+4)
    out[3] = unsafe_load(ptr+5)
    out[2] = unsafe_load(ptr+6)
    out[1] = unsafe_load(ptr+7)
    return out
end

# read uint64 from big endian vector
function decode_uint64(data::Vector{UInt8})::UInt64
    return ((UInt64(data[8]) << 0) | (UInt64(data[7]) << 8) | (UInt64(data[6]) << 16) | (UInt64(data[5]) << 24) |
            (UInt64(data[4]) << 32) | (UInt64(data[3]) << 40) | (UInt64(data[2]) << 48) | (UInt64(data[1]) << 56))
end
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
    timetag = decode_uint64(buffer[9:16])

    # we already know the bundle is 32 bit aligned
    elements = Vector{BundleElement}()
    idx = 17
    while idx < length(buffer)
        # size of bundle element
        size = decode_uint32(buffer[idx:idx+3])

        # align with end of data
        new_idx = align_32(idx + size)

        if new_idx-1 > length(buffer)
            throw(OSCParseException("Bundle element size extends beyond buffer. Index: $(new_idx-1)"))
        end

        # this many bytes to parse
        data_section = buffer[idx+4:new_idx-1]
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
        @inbounds return OSCMessage(String(buffer[1:addr_end]))
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
    # function map here per type
    idx = align_32(format_end+1)
    arguments = Vector{Any}()
    @inbounds format = String(buffer[format_start:format_end])
    for c in format
        arg, idx = parseArgument(idx, buffer, c)
        push!(arguments, arg)
    end

    @inbounds return OSCMessage(String(buffer[1:addr_end]), format, arguments)
end

"""
Parse the argument of type `c` starting at `idx` in the `buffer`.
Return the argument and the following 32 bit aligned index.
"""
@inline function parseArgument(idx::Int64, buffer::Vector{UInt8}, c::Char)::Tuple{Any, Int64}
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
                return String(buffer[idx:i-1]), align_32(i)
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
function encodeArgument(c::Char, arg::Any)::Vector{UInt8}
    # numbers that care about endianness
    if c ∈ "if"
        return encode_uint32(reinterpret(UInt32, arg))
    end

    if c ∈ "hdt"
        return encode_uint64(reinterpret(UInt64, arg))
    end

    # midi is just 4 byte vector
    if c == 'm'
        return arg
    end

    # strings can just be converted directly and padded
    if c ∈ "Ss"
        return pad_32(vcat(Vector{UInt8}(arg), 0x00))
    end

    # RGBA and ascii stay in the same order and are already 32 bit
    if c ∈ "rc"
        return reinterpret(UInt8, [arg])
    end

    # blobs are 32 bit size followed by arbitrary data
    if c == 'b'
        s = encode_uint32(arg.size)
        return vcat(s, arg.data)
    end

    # NI
    if c ∈ "TFNI"
        return UInt8[]
    end

    # TODO '[' and ']'
end

"""
    encodedOSCSize(msg)
    encodedOSCSize(bundle)

Calculate the encoded size of the given `msg` or `bundle` in bytes.
"""
function encodedOSCSize(msg::OSCMessage)::Int64
    # address length + 0x00 + padding
    size = align_32(length(msg.address) + 1) - 1

    # ',' + length of format string + 0x00 + padding
    size += align_32(length(msg.format) + 2) - 1

    # args
    for i in eachindex(msg.format)
        c = msg.format[i]

        # TODO '[' and ']'
        if c ∈ "ifrmc"
            size += 4
        elseif c ∈ "htd"
            size += 8
        elseif c ∈ "TFNI"
            size += 0
        elseif c ∈ "Ss"
            # string + null + padding
            size += align_32(length(msg.args[i]) + 1) - 1
        elseif c == 'b'
            # 4 byte size
            # that many bytes and padding
            size += align_32(4 + msg.args[i].size) - 1 
        else
            throw(OSCParseException("Got format string with unknown char: $c"))
        end
    end

    return size
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
    #---------------
    # address
    #---------------
    data = Vector{UInt8}(msg.address)
    data = vcat(data, 0x00)
    data = pad_32(data)

    #---------------
    # format
    #---------------
    # begin with ',' followed by the format string, followed by padding
    data = vcat(data, UInt8(','))
    data = vcat(data, Vector{UInt8}(msg.format), 0x00)
    data = pad_32(data)

    #---------------
    # arguments
    #---------------
    for i in eachindex(msg.format)
        data = vcat(data, encodeArgument(msg.format[i], msg.args[i]))
    end

    return data
end

function encodeOSC(bundle::OSCBundle)::Vector{UInt8}
    # add "#bundle"
    data = copy(BUNDLE_VEC)

    # encode timetag
    data = vcat(data, encode_uint64(bundle.timetag))

    # encode elements
    for e in bundle.elements
        data = vcat(data, encode_uint32(e.size))
        data = vcat(data, encodeOSC(e.content))
    end

    return data
end