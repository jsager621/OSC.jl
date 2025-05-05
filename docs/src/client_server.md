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

The `invert_matching` flag allows servers to invert pattern and address on incoming messages.
This can be used to match multiple addresses to the same callback:

```julia
# matches any incoming message with address starting with "/abc/".
callbacks = Dict{String, Function}(
        "/abc/*" => (s, args) -> myOtherCallback(s, args)
    )

srv = OSCServerUDP(HOST, PORT, callbacks, invert_matching=true)
```

The `timed_callbacks` flag lets servers execute OSCBundle contents at the time given by their timestamp.
OSC.jl provides the internal helper functions `OSC.toDate` and `OSC.fromDate` to convert `UInt64` timestamps from and to julias `DateTime` format.

NOTE: timestamps are handled in whole second accuracy.

```julia
using OSC
using Dates
using Sockets
using StringViews

COUNT = 0

function myCallback(s, args)
    global COUNT += 1
    println(args)
end

callbacks = Dict{String, Function}(
        "/testmsg" => (s, args) -> myCallback(s, args)
    )

SOCK = UDPSocket()
HOST = ip"127.0.0.1"
PORT = 8000
srv = OSCServerUDP(HOST, PORT, callbacks, timed_callbacks=true)
 t = Threads.@spawn listenForever(srv)

timed_bundle = OSCBundle(
    OSC.fromDate(now() + Dates.Second(3)),
    [
        OSCBundleElement(OSCMessage(
            StringView("/testmsg"), 
            StringView("i"), 
            Int32(5),
        ))
    ]
)

client = OSCClientUDP(1024)
send(client, HOST, PORT, timed_bundle)

sleep(4)
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