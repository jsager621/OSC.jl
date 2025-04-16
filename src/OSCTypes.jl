
abstract type BundleElement end

#-------------------------------------------
# Blob
#-------------------------------------------
"""
OSCBlob type to send `blob` elements via OSC.
Consists of the 32 bit `size` and the corresponding `data` vector.
"""
struct OSCBlob
    size::UInt32
    data::Vector{UInt8}

    function OSCBlob(size::UInt32, data::Vector{UInt8})
        if length(data) != size
            throw(ArgumentError("Blob size and data length do not match: $size vs $(length(data))"))
        end
        return new(size, data)
    end
end

function Base.show(io::IO, blob::OSCBlob)
    blob_repr = """
    OSCBlob:
    size: $(blob.size)
    data: $(blob.data)
    """
    print(io, blob_repr)
end

function Base.:(==)(x::OSCBlob, y::OSCBlob)
    return x.size == y.size && x.data==y.data
end

#-------------------------------------------
# Message
#-------------------------------------------
"""
Basic OSCMessage consisting of an `address`, `format` and a list of `args`.
Contents are in parsed form, meaning the initial ',' in the format string or any
trailing null bytes in the data are not present here.
"""
struct OSCMessage
    data::Vector{UInt8}
    size::UInt32
    address_end::UInt32
    format_start::UInt32
    format_end::UInt32
    args_start::UInt32
end

function OSCMessage(
    address::StringView, 
    format::StringView, 
    args...;
    initial_alloc::UInt32=UInt32(256))

    initial_alloc = max(initial_alloc, length(address) + length(format) + 8)
    data = zeros(UInt8, initial_alloc)

    # insert address
    @inbounds data[1:length(address.data)] = address.data
    idx = align_32(length(address)+1)
    format_start = idx + 1

    # no format, no args
    if isempty(format)
        return OSCMessage(data, idx-1, length(address), 0, 0, 0)
    end

    # insert format
    @inbounds data[idx] = UInt8(',')
    format_end = idx + length(format.data)
    @inbounds data[idx + 1:format_end] = format.data
    idx = align_32(format_end+1) # null terminate + align
    args_start = idx

    # insert arguments
    for a in args
        if idx > length(data)
            extend_buffer!(data)
        end

        idx = encodeArgument!(data, idx, a)
    end

    # create msg object
    return OSCMessage(data, idx-1, length(address), format_start, format_end, args_start)
end

function OSCMessage(address::StringView)
    return OSCMessage(address, StringView(""))
end

function address(msg::OSCMessage)::StringView
    return StringView(msg.data[1:msg.address_end])
end
function format(msg::OSCMessage)::StringView
    return StringView(msg.data[msg.format_start:msg.format_end])
end
function arguments(msg::OSCMessage)::Vector{Any}
    arg_vec = Vector{Any}()
    idx = msg.args_start
    for i in msg.format_start:msg.format_end
        arg, idx = parseArgument(idx, msg.data, Char(msg.data[i]))
        push!(arg_vec, arg)
    end
    return arg_vec
end


function Base.show(io::IO, msg::OSCMessage)
    form = msg.format_start != 0 ? format(msg) : ""
    args = msg.args_start != 0 ? arguments(msg) : ""
    msg_repr = """
    OSCMessage:
    address: $(address(msg))
    format: $form
    args: $args
    """
    print(io, msg_repr)
end

function Base.:(==)(x::OSCMessage, y::OSCMessage)
    return x.data[1:x.size] == y.data[1:y.size]
end

#-------------------------------------------
# Bundle
#-------------------------------------------
"""
OSCBundle type consisting of a `timetag` and a vector of `BundleElement`s.
"""
struct OSCBundle
    timetag::UInt64
    elements::Vector{BundleElement}
end

function Base.show(io::IO, bundle::OSCBundle)
    bundle_repr = """
    OSCBundle:
    timetag: $(bundle.timetag)
    """
    for e in bundle.elements
        bundle_repr *= "\nelement:"
        bundle_repr *= repr(e)
    end
    print(io, bundle_repr)
end

function Base.:(==)(x::OSCBundle, y::OSCBundle)
    return x.timetag == y.timetag && x.elements==y.elements
end

#-------------------------------------------
# Element
#-------------------------------------------
"""
Parent type for elements in an `OSCBundle`.
Consists of the element `size` and its `content`.
"""
struct OSCBundleElement <: BundleElement
    size::UInt32
    content::Union{OSCBundle, OSCMessage}
end

OSCBundleElement(msg::OSCMessage) = OSCBundleElement(encodedOSCSize(msg), msg)
OSCBundleElement(bundle::OSCBundle) = OSCBundleElement(encodedOSCSize(bundle), bundle)

function Base.show(io::IO, element::OSCBundleElement)
    element_repr = """
    OSCBundleElement:
    size: $(element.size)
    content: $(element.content)
    """
    print(io, element_repr)
end

function Base.:(==)(x::OSCBundleElement, y::OSCBundleElement)
    return x.size == y.size && x.content==y.content
end

#-------------------------------------------
# Custom Exception for Parsing
#-------------------------------------------
"""
Exception indicating an error while parsing an OSCMessage or OSCBundle
from an input buffer.
"""
struct OSCParseException <: Exception
    message::String
end
function Base.showerror(io::IO, err::OSCParseException) 
    print(io, "OSCParseException: ")
    print(io, err.message)
end