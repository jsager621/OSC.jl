using OSC
using Sockets

function main()
    HOST = ip"127.0.0.1"
    PORT = 8000

    callbacks = Dict{String, Function}(
        "/test1" => (s, args) -> println("/test1: $args"),
        "/test2" => (s, args) -> println("/test2: $args")
    )

    srv = OSCServerUDP(HOST, PORT, callbacks)

    t = listenForever(srv)
end

main()

"""
expected output:

> julia oscpack_recv.jl 
/test1: Any[true, 23, 3.1415f0, "hello"]
/test2: Any[true, 24, 10.8f0, "world"]
"""