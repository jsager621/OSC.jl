
@testset "matching" begin
    # test cases from the 1.1 spec paper:
    addresses = [
        "/body",

        "/body/arm",
        "/body/arm/right",
        "/body/arm/right/hand",
        "/body/arm/right/hand/position",
        "/body/arm/right/hand/orientation",

        "/body/arm/left",
        "/body/arm/left/hand",
        "/body/arm/left/hand/position",
        "/body/arm/left/hand/orientation",

        "/body/leg/something/position"
    ]

    @test length([x for x in addresses if matchOSC(x, x)]) == length(addresses)
    @test length([x for x in addresses if matchOSC(x, "//position")]) == 3

    pattern_addresses = [
        "/input/0/test/something",
        "/output/0/test/something",
        "/input/1/test/something",
        "/output/1/test/something",
        "/input/2/test/something",
        "/output/2/test/something",
        "/input/3/test/something",
        "/output/3/test/something",
        "/input/0/a/something",
        "/output/0/b/something",
    ]
    patterned_test = "/{input,output}/[0-2]/[!ab]/*"

    p_test = [x for x in pattern_addresses if matchOSC(x, patterned_test)]
    @test length(p_test) == 6

    new_spec_addresses = [
        "/a/b/c/target",
        "/a/b/target",
        "/a/target",
        "/target",
        "/d/e/f/target",
        "/blubb/f/target",
    ]

    p1 = "//target"
    @test length([x for x in new_spec_addresses if matchOSC(x, p1)]) == 6

    p2 = "//f/target"
    @test length([x for x in new_spec_addresses if matchOSC(x, p2)]) == 2
end