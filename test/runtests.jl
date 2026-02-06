using NickelEval
using Test

# Check if Nickel is available
function nickel_available()
    try
        Sys.which("nickel") !== nothing
    catch
        false
    end
end

@testset "NickelEval.jl" begin
    if nickel_available()
        include("test_subprocess.jl")
    else
        @warn "Nickel executable not found in PATH, skipping tests. Install from: https://nickel-lang.org/"
        @test_skip "Nickel not available"
    end
end
