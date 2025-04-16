# OSC.jl


[Docs](https://jsager621.github.io/OSC.jl/dev/) | [GitHub](https://github.com/jsager621/OSC.jl)

Pure Julia implementation of the Open Sound Control format.
The aim of this library is to provide full OSC 1.1 spec support and convenient APIs for its use.

The project is in early development and almost certainly still contains bugs. As such, contributions and feature suggestions are greatly encouraged.


# Features
* message generation
* message parsing
* bundle generation
* bundle parsing
* address matching
* UDP server with address-based dispatching
* UDP client
* all OSC 1.0 types except `[` and `]` which is in TODOs
* OSC 1.1 `//` path operator

# Sample Usage
Creating and sending messages:
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


Receiving and handling messages:
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

# Compatibility
To ensure correctness and interoperability, this package has been tested to correctly send messages to and receive messages from other OSC libraries.
This includes tests against:
* liblo - https://liblo.sourceforge.net/
* oscpack - http://www.rossbencina.com/code/oscpack

So far, these tests have been done manually but they will eventually be automated.
For now, the folder `test/manual/` contains the package files and the corresponding other implementations they were run against.
Note that compiling the C and C++ files there requires the rest of the liblo and oscpack libraries, respectively.

# Performance
Raw read/write performance is now comparable to Liblo. 
Note that parse/read performance works by directly writing the incoming buffer into the data structure.
To use the OSC arguments in convenient Julia types they still need to be parsed which is slower (probably improvable).

```
Liblo parse:  56.270000 ns per message
Liblo encode:  96.135000 ns per message

OSC.jl parse: 53.934574127197266 ns per message
OSC.jl encode: 122.9095458984375 ns per message

With parsing to convenient types:
OSC.jl Read Performance: 209.98108386993408 nanoseconds per message
```

# TODO
* timetag handling (currently only handles as UInt64)
* array (`[` and `]`) support
* convenience constructor that infers format string
* automate compatibility tests
* benchmarking and performance improvements
* TCP support

