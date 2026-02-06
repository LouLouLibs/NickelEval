module NickelEval

using JSON3

export nickel_eval, nickel_eval_file, nickel_export, @ncl_str, NickelError

# Custom exception for Nickel errors
struct NickelError <: Exception
    message::String
end

Base.showerror(io::IO, e::NickelError) = print(io, "NickelError: ", e.message)

include("subprocess.jl")
include("ffi.jl")

end # module
