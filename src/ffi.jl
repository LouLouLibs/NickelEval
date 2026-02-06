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
    nickel_eval_ffi(code::String) -> JSON.Object
    nickel_eval_ffi(code::String, ::Type{T}) -> T

Evaluate Nickel code using native FFI bindings (faster than subprocess).
Returns the parsed JSON result, optionally typed.

Throws `NickelError` if FFI is not available or if evaluation fails.

# Examples
```julia
julia> nickel_eval_ffi("1 + 2")
3

julia> result = nickel_eval_ffi("{ x = 1, y = 2 }")
julia> result.x  # dot-access supported
1

julia> nickel_eval_ffi("{ x = 1, y = 2 }", Dict{String, Int})
Dict{String, Int64}("x" => 1, "y" => 2)
```
"""
function nickel_eval_ffi(code::String)
    result_json = _eval_ffi_to_json(code)
    return JSON.parse(result_json)
end

function nickel_eval_ffi(code::String, ::Type{T}) where T
    result_json = _eval_ffi_to_json(code)
    return JSON.parse(result_json, T)
end

function _eval_ffi_to_json(code::String)
    if !FFI_AVAILABLE
        error("FFI not available. Build the Rust library with: cd rust/nickel-jl && cargo build --release && cp target/release/libnickel_jl.dylib ../../deps/")
    end

    # Call the Rust function
    result_ptr = ccall((:nickel_eval_string, LIB_PATH),
                       Ptr{Cchar}, (Cstring,), code)

    if result_ptr == C_NULL
        # Get error message
        error_ptr = ccall((:nickel_get_error, LIB_PATH), Ptr{Cchar}, ())
        if error_ptr != C_NULL
            error_msg = unsafe_string(error_ptr)
            throw(NickelError(error_msg))
        else
            throw(NickelError("Nickel evaluation failed with unknown error"))
        end
    end

    # Convert result to Julia string
    result_json = unsafe_string(result_ptr)

    # Free the allocated memory
    ccall((:nickel_free_string, LIB_PATH), Cvoid, (Ptr{Cchar},), result_ptr)

    return result_json
end
