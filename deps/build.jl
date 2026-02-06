# Build script for the Rust FFI library
#
# This script is run by Pkg.build() to compile the Rust wrapper library.
# Currently a stub for Phase 2 implementation.

using Libdl

const RUST_PROJECT = joinpath(@__DIR__, "..", "rust", "nickel-jl")

# Determine the correct library extension for the platform
function library_extension()
    if Sys.iswindows()
        return ".dll"
    elseif Sys.isapple()
        return ".dylib"
    else
        return ".so"
    end
end

# Determine library name with platform-specific prefix
function library_name()
    if Sys.iswindows()
        return "nickel_jl$(library_extension())"
    else
        return "libnickel_jl$(library_extension())"
    end
end

function build_rust_library()
    if !isdir(RUST_PROJECT)
        @warn "Rust project not found at $RUST_PROJECT, skipping FFI build"
        return false
    end

    # Check if cargo is available
    cargo = Sys.which("cargo")
    if cargo === nothing
        @warn "Cargo not found in PATH, skipping FFI build. Install Rust: https://rustup.rs/"
        return false
    end

    @info "Building Rust FFI library..."

    try
        cd(RUST_PROJECT) do
            run(`cargo build --release`)
        end

        # Copy the built library to deps/
        src_lib = joinpath(RUST_PROJECT, "target", "release", library_name())
        dst_lib = joinpath(@__DIR__, library_name())

        if isfile(src_lib)
            cp(src_lib, dst_lib; force=true)
            @info "FFI library built successfully: $dst_lib"
            return true
        else
            @warn "Built library not found at $src_lib"
            return false
        end
    catch e
        @warn "Failed to build Rust library: $e"
        return false
    end
end

# Only build if explicitly requested or in a CI environment
if get(ENV, "NICKELEVAL_BUILD_FFI", "false") == "true"
    build_rust_library()
else
    @info "Skipping FFI build (set NICKELEVAL_BUILD_FFI=true to enable)"
end
