module NickelEval

using JSON

export nickel_eval, nickel_eval_file, nickel_export, nickel_read, @ncl_str, NickelError
export nickel_to_json, nickel_to_toml, nickel_to_yaml
export check_ffi_available, nickel_eval_ffi

# Custom exception for Nickel errors
struct NickelError <: Exception
    message::String
end

Base.showerror(io::IO, e::NickelError) = print(io, "NickelError: ", e.message)

include("subprocess.jl")
include("ffi.jl")

end # module
