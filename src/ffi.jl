# FFI bindings for Nickel
#
# Native FFI bindings to a Rust wrapper around Nickel for high-performance evaluation
# without subprocess overhead.
#
# API:
#   - nickel_eval_ffi(code::String) -> Any
#   - Direct ccall to libnickel_jl
#   - Memory management via nickel_free_string
#
# Benefits over subprocess:
#   - No process spawn overhead
#   - Direct memory sharing
#   - Better performance for repeated evaluations

using JSON3

# Determine platform-specific library name
const LIB_NAME = if Sys.iswindows()
    "nickel_jl.dll"
elseif Sys.isapple()
    "libnickel_jl.dylib"
else
    "libnickel_jl.so"
end

# Path to the compiled library
const LIB_PATH = joinpath(@__DIR__, "..", "deps", LIB_NAME)

# Check if FFI library is available
const FFI_AVAILABLE = isfile(LIB_PATH)

"""
    check_ffi_available() -> Bool

Check if FFI bindings are available.
Returns true if the native library is compiled and available.
"""
function check_ffi_available()
    return FFI_AVAILABLE
end

"""
    nickel_eval_ffi(code::String) -> Any

Evaluate Nickel code using native FFI bindings.
Returns the parsed JSON result.

Throws an error if FFI is not available or if evaluation fails.
"""
function nickel_eval_ffi(code::String)
    if !FFI_AVAILABLE
        error("FFI not available. Build the Rust library with: NICKELEVAL_BUILD_FFI=true julia --project=. -e 'using Pkg; Pkg.build()'")
    end

    # Call the Rust function
    result_ptr = ccall((:nickel_eval_string, LIB_PATH),
                       Ptr{Cchar}, (Cstring,), code)

    if result_ptr == C_NULL
        # Get error message
        error_ptr = ccall((:nickel_get_error, LIB_PATH), Ptr{Cchar}, ())
        if error_ptr != C_NULL
            error_msg = unsafe_string(error_ptr)
            error("Nickel evaluation error: $error_msg")
        else
            error("Nickel evaluation failed with unknown error")
        end
    end

    # Convert result to Julia string
    result_json = unsafe_string(result_ptr)

    # Free the allocated memory
    ccall((:nickel_free_string, LIB_PATH), Cvoid, (Ptr{Cchar},), result_ptr)

    # Parse JSON and return
    return JSON3.read(result_json)
end
