using Sockets
using OSC

HOST = ip"127.0.0.1"
PORT = 8000

function main()
    test1 = OSCBundleElement(OSCMessage(
        "/test1",
        "Tifs",
        true,
        Int32(1337),
        Float32(47.11),
        "test"        
    ))

    test2 = OSCBundleElement(OSCMessage(
        "/test2",
        "Tifs",
        true,
        Int32(1337),
        Float32(47.11),
        "test"        
    ))


    client = OSCClientUDP(1024)

    bundle = OSCBundle(UInt64(12345), [test1, test2, test1, test2])

    send(client, HOST, PORT, bundle)
    sleep(0.2)   
end

main()

"""
output:

./oscpackSimpleReceive
press ctrl-c to end
received '/test1' message with arguments: 1 1337 47.11 test
received '/test2' message with arguments: 1 1337 47.11 test
received '/test1' message with arguments: 1 1337 47.11 test
received '/test2' message with arguments: 1 1337 47.11 test
"""