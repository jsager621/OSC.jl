using Sockets
using OSC

HOST = ip"127.0.0.1"
PORT = 7770

function main()
    blob = OSCBlob(UInt32(8), UInt8[0x23, 0x24, 0x25, 0x26, 0x27, 0x28, 0x29, 0x30])
    blob_msg = OSCMessage(
        "/blobtest",
        "b",
        blob
    )

    foo_msg = OSCMessage(
        "/foo/bar",
        "fi",
        Float32(47.11),
        Int32(1337)
    )

    generic_msg = OSCMessage(
        "/test1", 
        "ifsbhtdScmTFNI",  # liblo does not support 'r'
        Int32(5),
        Float32(6),
        "test",
        blob,
        Int64(12345),
        UInt64(0xFF00FF00C0FFEE00),
        Float64(47.11),
        "Symbol",
        UInt32(255),
        UInt8[0x10, 0x20, 0x30, 0x40],
        true,
        false,
        nothing,
        nothing)

    quit_msg = OSCMessage(
        "/quit"
    )

    client = OSCClientUDP(1024)

    # base_types = OSCMessage("/hello world", "sSif", "strings", "symbols", Int32(234), Float32(2.3))
    
    send(client, HOST, PORT, blob_msg)
    sleep(0.2)
    send(client, HOST, PORT, foo_msg)
    sleep(0.2)
    send(client, HOST, PORT, generic_msg)
    sleep(0.2)
    send(client, HOST, PORT, quit_msg)
    sleep(0.2)
end

main()

"""
Server side expected output:

> ./liblo_example_server
path: </blobtest>
arg 0 'b' [8b 0x23 0x24 0x25 0x26 0x27 0x28 0x29 0x30]

/blobtest <- length:8 '.....'
path: </foo/bar>
arg 0 'f' 47.110001
arg 1 'i' 1337

/foo/bar <- f:47.110001, i:1337

path: </test1>
arg 0 'i' 5
arg 1 'f' 6.000000
arg 2 's' "test"
arg 3 'b' [8b 0x23 0x24 0x25 0x26 0x27 0x28 0x29 0x30]
arg 4 'h' 12345
arg 5 't' ff00ff00.c0ffee00
arg 6 'd' 47.110000
arg 7 'S' 'Symbol
arg 8 'c' ''
arg 9 'm' MIDI [0x10 0x20 0x30 0x40]
arg 10 'T' #T
arg 11 'F' #F
arg 12 'N' Nil
arg 13 'I' Infinitum

path: </quit>

quiting

"""