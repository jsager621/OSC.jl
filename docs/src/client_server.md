# Server and Client

# Server

You can run an `OSCUDPServer` that automatically dispatches callbacks via address matching like this:

```julia
using Sockets
using OSC

function myCallback(srv, args)
    println(args)
end

function myOtherCallback(srv, args)
    println(srv)
end

callbacks = Dict{String, Function}(
        "/testmsg" => (s, args) -> myCallback(s, args),
        "/another/msg" => (s, args) -> myOtherCallback(s, args)
    )

srv = OSCServerUDP(ip"127.0.0.1", 8000, callbacks)

# server now automatically handles incoming OSC messages
# and calls myCallback or myOtherCallback if the messages
# address pattern fits.
t = Threads.@spawn listenForever(srv)

# do some other things
# ....
sleep(5)

# close the server socket
close(srv)
```

# Client

The `OSCClientUDP` is a simple wrapper around a `UDPSocket` that ensures sending a packet does not exceed the `max_payload` size.
Additionally, the package defines `send` functions on top of `Sockets.send` to directly pass `OSCMessage` and `OSCBundle` objects to a `UDPSocket`.

```julia
using OSC
using Sockets
using StringViews

HOST = ip"127.0.0.1"
PORT = 8000
sock = UDPSocket()

blob = OSCBlob(UInt32(8), UInt8[0x1, 0x2, 0x3, 0x4, 0x5, 0x6, 0x7, 0x8])
base_types = OSCMessage(
        StringView("/testmsg"), 
        StringView("ifsb"), 
        Int32(5),
        Float32(6),
        StringView("test"),
        blob)

println(base_types)
println(encodeOSC(base_types))

# object will be encoded automatically
send(sock, HOST, PORT, base_types)

# equivalent to
send(sock, HOST, PORT, encodeOSC(base_types))

# or via the client object that ensures payload size limits
client = OSCClientUDP(1024)
send(client, HOST, PORT, base_types)
```