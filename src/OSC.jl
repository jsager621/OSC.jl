module OSC
export OSCMessage, OSCBundle, OSCBundleElement, OSCBlob, arguments, format, address
export parseOSC, encodeOSC, encodedOSCSize, OSCParseException
export validateOSC
export matchOSC
export OSCServerUDP, listenForever
export OSCClientUDP

using Sockets
using StringViews

include("helpers.jl")
include("OSCTypes.jl")
include("parse_encode.jl")
include("validate.jl")
include("matching.jl")
include("server.jl")
include("client.jl")

end 
