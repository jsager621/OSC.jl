
abstract type BundleElement end

#-------------------------------------------
# Message
#-------------------------------------------
"""
Basic OSCMessage consisting of an `address`, `format` and a list of `args`.
Contents are in parsed form, meaning the initial ',' in the format string or any
trailing null bytes in the data are not present here.
"""
struct OSCMessage
    address::StringView
    format::StringView
    args::Vector{Any} # parsed arguments
end

function OSCMessage(address::StringView, format::StringView, args...)
    return OSCMessage(address, format, Any[args...])
end

function Base.show(io::IO, msg::OSCMessage)
    msg_repr = """
    OSCMessage:
    address: $(msg.address)
    format: $(msg.format)
    args: $(msg.args)
    """
    print(io, msg_repr)
end

function Base.:(==)(x::OSCMessage, y::OSCMessage)
    return x.address == y.address && x.format==y.format && x.args == y.args
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