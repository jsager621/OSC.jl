using OSC
using Sockets

function main()
    HOST = ip"127.0.0.1"
    PORT = 7770

    callbacks = Dict{String, Function}(
        "/foo/bar" => (s, args) -> println("/foo/bar: $args"),
        "/a/b/c/d" => (s, args) -> println("/a/b/c/d: $args"),
        "/blobtest" => (s, args) -> println("/blobtest: $args"),
        "/jamin/scene" => (s, args) -> println("/jamin/scene: $args"),
        "/quit" => (s, args) -> (println("/quit: $args"); close(srv)),
    )

    srv = OSCServerUDP(HOST, PORT, callbacks)

    t = listenForever(srv)
end

main()

"""
Expected calls and outputs terminal 1:

> julia liblo_recv.jl
/foo/bar: Any[0.12345678f0, 23.0f0]
/a/b/c/d: Any["one", 0.12345678f0, "three", -2.3001f-7, 1.0f0]
/a/b/c/d: Any[OSCBlob:
size: 6
data: UInt8[0x41, 0x42, 0x43, 0x44, 0x45, 0x00]
]
/blobtest: Any[OSCBlob:
size: 6
data: UInt8[0x41, 0x42, 0x43, 0x44, 0x45, 0x00]
]
/jamin/scene: Any[2]
/quit: Any[]
[ Info: Closing OSC UDP server.
"""

"""
Expected calls and outputs terminal 2:
> ./liblo_example_client 
> ./liblo_example_client -q 
"""