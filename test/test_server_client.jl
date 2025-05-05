function get_msg()
    blob = OSCBlob(UInt32(8), UInt8[0x1, 0x2, 0x3, 0x4, 0x5, 0x6, 0x7, 0x8])
    base_types = OSCMessage(
        StringView("/testmsg"), 
        StringView("ifsb"), 
        Int32(5),
        Float32(6),
        StringView("test"),
        blob)

    return base_types
end

function get_bundle()
    return OSCBundle(
        UInt64(0xC0FFEE), 
        [OSCBundleElement(get_msg()), 
        OSCBundleElement(get_msg()), 
        OSCBundleElement(get_msg())])
end

function get_bundle(timestamp)
    return OSCBundle(
        timestamp, 
        [OSCBundleElement(get_msg()), 
        OSCBundleElement(get_msg()), 
        OSCBundleElement(get_msg())])
end

function get_other_msg(address::StringView)
    blob = OSCBlob(UInt32(8), UInt8[0x1, 0x2, 0x3, 0x4, 0x5, 0x6, 0x7, 0x8])
    base_types = OSCMessage(
        address, 
        StringView("ifsb"), 
        Int32(5),
        Float32(6),
        StringView("test"),
        blob)

    return base_types
end

function get_other_bundle()
    return OSCBundle(
        UInt64(0xC0FFEE), 
        [OSCBundleElement(get_other_msg(StringView("/abc/123"))), 
        OSCBundleElement(get_other_msg(StringView("/def/123"))), 
        OSCBundleElement(get_other_msg(StringView("/abc/something")))])
end

HOST = ip"127.0.0.1"
PORT = 8000

function send_udp(sd)
    sock = UDPSocket()
    host = HOST
    port = PORT
    send(sock, host, port, sd)
end

function send_other_udp(sd)
    sock = UDPSocket()
    host = HOST
    port = PORT+1
    send(sock, host, port, sd)
end

MSG_COUNTER = 0
CORRECT_MSG_COUNTER = 0
function myCallback(srv, args)
    global MSG_COUNTER += 1

    if args == arguments(get_msg())
        global CORRECT_MSG_COUNTER += 1  
    end
end

OTHER_MSG_COUNTER = 0
OTHER_CORRECT_MSG_COUNTER = 0
function myOtherCallback(srv, args)
    global OTHER_MSG_COUNTER += 1
    if args == arguments(get_msg())
        global OTHER_CORRECT_MSG_COUNTER += 1  
    end
end

function reset_msg_counters()
    global MSG_COUNTER = 0
    global CORRECT_MSG_COUNTER = 0
    global OTHER_MSG_COUNTER = 0
    global OTHER_CORRECT_MSG_COUNTER = 0
end

@testset "UDPServerClient" begin
    #------------------------------
    # Server
    #------------------------------
    callbacks = Dict{String, Function}(
        "/testmsg" => (s, args) -> myCallback(s, args),
        "/abc/*" => (s, args) -> myOtherCallback(s, args)
    )

    # reggular matching
    srv = OSCServerUDP(HOST, PORT, callbacks)
    t = Threads.@spawn listenForever(srv)

    sleep(0.2)
    send_udp(encodeOSC(get_msg()))
    sleep(0.2)
    send_udp(encodeOSC(get_bundle()))
    sleep(0.2)

    @test MSG_COUNTER == 4
    @test CORRECT_MSG_COUNTER == 4
    @test OTHER_MSG_COUNTER == 0
    @test OTHER_CORRECT_MSG_COUNTER == 0

    # inverse matching
    srv2 = OSCServerUDP(HOST, PORT+1, callbacks, invert_matching=true)
    t2 = Threads.@spawn listenForever(srv2)

    sleep(0.2)
    send_other_udp(encodeOSC(get_other_msg(StringView("/abc/dont/match/me"))))
    sleep(0.2)
    send_other_udp(encodeOSC(get_other_bundle()))
    sleep(0.2)

    @test MSG_COUNTER == 4
    @test CORRECT_MSG_COUNTER == 4
    @test OTHER_MSG_COUNTER == 2
    @test OTHER_CORRECT_MSG_COUNTER == 2

    #------------------------------
    # client
    #------------------------------
    # sending from OSC specific send
    sock = UDPSocket()

    send(sock, HOST, PORT, get_msg())
    sleep(0.2)
    send(sock, HOST, PORT, get_bundle())
    sleep(0.2)

    @test MSG_COUNTER == 8
    @test CORRECT_MSG_COUNTER == 8

    c1 = OSCClientUDP(1024)
    send(c1, HOST, PORT, get_msg())
    sleep(0.2)
    send(c1, HOST, PORT, get_bundle())
    sleep(0.2)

    @test MSG_COUNTER == 12
    @test CORRECT_MSG_COUNTER == 12

    c2 = OSCClientUDP(20)
    @test_throws ArgumentError send(c2, HOST, PORT, get_msg())
    @test_throws ArgumentError send(c2, HOST, PORT, get_bundle())

    close(srv)
    close(srv2)
end


@testset "TimedCallbacks" begin
    # test helper functions for dates
    t = DateTime(2013,7,1,12,30,59)
    @test OSC.toDate(OSC.fromDate(t)) == t

    # test correct timing of callbacks
    callbacks = Dict{String, Function}(
        "/testmsg" => (s, args) -> myCallback(s, args),
        "/abc/*" => (s, args) -> myOtherCallback(s, args)
    )

    reset_msg_counters()


    srv = OSCServerUDP(HOST, PORT, callbacks, timed_callbacks=true)
    t = Threads.@spawn listenForever(srv)

    # execute immediately
    send_udp(encodeOSC(get_bundle(UInt64(1))))
    sleep(0.2)

    @test MSG_COUNTER == 3
    @test CORRECT_MSG_COUNTER == 3

    # execute with 2 second delays
    send_udp(encodeOSC(get_bundle(OSC.fromDate(now() + Dates.Second(2)))))

    sleep(0.2)
    @test MSG_COUNTER == 3
    @test CORRECT_MSG_COUNTER == 3

    sleep(3)

    @test MSG_COUNTER == 6
    @test CORRECT_MSG_COUNTER == 6

    close(srv)
end