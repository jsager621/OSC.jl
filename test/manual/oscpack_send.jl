using Sockets
using OSC
using StringViews

HOST = ip"127.0.0.1"
PORT = 7000

function main()
    test1 = OSCBundleElement(OSCMessage(
        StringView("/test1"),
        StringView("Tifs"),
        true,
        Int32(1337),
        Float32(47.11),
        StringView("test")        
    ))

    test2 = OSCBundleElement(OSCMessage(
        StringView("/test2"),
        StringView("Tifs"),
        true,
        Int32(1337),
        Float32(47.11),
        StringView("test")        
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