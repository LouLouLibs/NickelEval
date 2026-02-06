module NickelEval

using JSON

export nickel_eval, nickel_eval_file, nickel_export, nickel_read, @ncl_str, NickelError
export nickel_to_json, nickel_to_toml, nickel_to_yaml
export check_ffi_available, nickel_eval_ffi, nickel_eval_native
export find_nickel_executable
export NickelEnum

"""
    NickelError <: Exception

Exception thrown when Nickel evaluation fails.

# Fields
- `message::String`: The error message from Nickel

# Examples
```julia
try
    nickel_eval("{ x = }")  # syntax error
catch e
    if e isa NickelError
        println("Nickel error: ", e.message)
    end
end
```
"""
struct NickelError <: Exception
    message::String
end

Base.showerror(io::IO, e::NickelError) = print(io, "NickelError: ", e.message)

"""
    NickelEnum

Represents a Nickel enum value. Matches the format of `std.enum.to_tag_and_arg`.

# Fields
- `tag::Symbol`: The enum variant name
- `arg::Any`: The argument (nothing for simple enums)

# Examples
```julia
result = nickel_eval_native("let x = 'Some 42 in x")
result.tag   # => :Some
result.arg   # => 42
result == :Some  # => true

result = nickel_eval_native("let x = 'None in x")
result.tag   # => :None
result.arg   # => nothing
```
"""
struct NickelEnum
    tag::Symbol
    arg::Any
end

# Convenience: compare enum to symbol
Base.:(==)(e::NickelEnum, s::Symbol) = e.tag == s
Base.:(==)(s::Symbol, e::NickelEnum) = e.tag == s

# Pretty printing
function Base.show(io::IO, e::NickelEnum)
    if e.arg === nothing
        print(io, "'", e.tag)
    else
        print(io, "'", e.tag, " ", repr(e.arg))
    end
end

include("subprocess.jl")
include("ffi.jl")

end # module
