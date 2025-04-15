using Documenter, OSC, Test, Logging

# makedocs(modules=[OSC], sitename="Test", checkdocs=:exports)

logger = Test.TestLogger(min_level=Info);
with_logger(logger) do
    makedocs(
        modules=[OSC],
        sitename="OSC.jl Documentation",
        checkdocs=:exports,
        pages=Any[
            "Home"=>"index.md",
            "Encode and Parse"=>"parse_encode.md",
            "Client and Server"=>"client_server.md",
            "API"=>"api.md",],
        repo="github.com/jsager621/OSC.jl",
    )
end

deploydocs(
    repo="github.com/jsager621/OSC.jl",
    push_preview=true,
    devbranch="main"
)