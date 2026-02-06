using NickelEval
using Test

# Check if Nickel CLI is available
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
        @warn "Nickel executable not found in PATH, skipping subprocess tests. Install from: https://nickel-lang.org/"
        @test_skip "Nickel CLI not available"
    end

    if check_ffi_available()
        include("test_ffi.jl")
    else
        @warn "FFI library not available, skipping FFI tests. Build with: cd rust/nickel-jl && cargo build --release"
        @test_skip "FFI not available"
    end
end
