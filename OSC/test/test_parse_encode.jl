function osc_messages()
    blob = OSCBlob(UInt32(8), UInt8[0x1, 0x2, 0x3, 0x4, 0x5, 0x6, 0x7, 0x8])
    everything = OSCMessage(
        "/addr/osc", 
        "ifsbhtdScrmTFNI", 
        Int32(5),
        Float32(6),
        "test",
        blob,
        Int64(12345),
        UInt64(12345),
        Float64(47.11),
        "Symbol",
        UInt32(12),
        UInt32(255),
        UInt8[0x10, 0x20, 0x30, 0x40],
        true,
        false,
        nothing,
        nothing)

    base_types = OSCMessage(
        "/addr/osc", 
        "ifsb", 
        Int32(5),
        Float32(6),
        "test",
        blob)

    extended_types = OSCMessage(
        "/addr/osc", 
        "htdScrmTFNI", 
        Int64(12345),
        UInt64(12345),
        Float64(47.11),
        "Symbol",
        UInt32(12),
        UInt32(255),
        UInt8[0x10, 0x20, 0x30, 0x40],
        true,
        false,
        nothing,
        nothing)

    return base_types, extended_types, everything
end

@testset "encoding" begin
    base_types, extended_types, everything = osc_messages()

    """
    Encodes to:
    /addr/osc\0\0\0                 # addr
    ,ifsbhtdScrmTFNI\0\0\0\0        # format
    \0\0\0\x05                      # Int32 5
    @\xc0\0\0                       # Float32 6
    test\0\0\0\0                    # "test"
    \0\0\0\b                        # size of blob (8)
    \x01\x02\x03\x04\x05\x06\a\b    # blob contents
    \0\0\0\0\0\x0009                # 12345
    \0\0\0\0\0\x0009                # 12345
    @G\x8e\x14z\xe1G\xae            # 47.11
    Symbol\0\0                      # "Symbol"
    \f\0\0\0                        # 12 (endianness unchanged)
    \xff\0\0\0                      # 255 (endianness unchanged)
    \x10 0@                         # [0x10, 0x20, 0x30, 0x40]
                                    # TFNI => no contents
    """

    expected_output = Vector{UInt8}(
                    "/addr/osc\0\0\0"*
                    ",ifsbhtdScrmTFNI\0\0\0\0"*
                    "\0\0\0\x05"*
                    "@\xc0\0\0"*
                    "test\0\0\0\0"*
                    "\0\0\0\b"*
                    "\x01\x02\x03\x04\x05\x06\a\b"*
                    "\0\0\0\0\0\x0009"*
                    "\0\0\0\0\0\x0009"*
                    "@G\x8e\x14z\xe1G\xae"*
                    "Symbol\0\0"*
                    "\f\0\0\0"*
                    "\xff\0\0\0"*
                    "\x10 0@")
    
    @test encodeOSC(everything) == expected_output

    bundle = OSCBundle(UInt64(0xC0FFEE), [OSCBundleElement(everything)])
    bundle_front = Vector{UInt8}(
        "#bundle\0"*                # "#bundle"
        "\0\0\0\0\0\xc0\xff\xee"*   # timetag
        "\0\0\0h"                 # len(expected_output) == 104
    )
    @test encodeOSC(bundle) == vcat(bundle_front, expected_output)
end

@testset "parsing" begin
    base_types, extended_types, everything = osc_messages()

    @test validateOSC(base_types, encodeOSC(base_types))
    @test validateOSC(extended_types, encodeOSC(extended_types))
    @test validateOSC(everything, encodeOSC(everything))


    x = OSCBundleElement(everything)
    y = OSCBundleElement(base_types)
    bundle = OSCBundle(UInt64(0xC0FFEE), [x,y])
    @test validateOSC(bundle, encodeOSC(bundle))

    # malformed OSC bundle
    bad_bundle = UInt8[0x23, 0x62, 0x75, 0x6e, 0x64, 0x6c, 0x65, 0x00, 0x0c, 0x00, 0x00, 0x00,  0x2f, 0x74, 0x65, 0x73, 0x74, 0x00, 0x00, 0x00, 0x2c, 0x00, 0x00, 0x00]
    @test_throws OSCParseException parseOSC(bad_bundle)
end