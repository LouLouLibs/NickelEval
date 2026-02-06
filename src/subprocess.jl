# Subprocess-based Nickel evaluation using CLI

"""
    find_nickel_executable() -> String

Find the Nickel executable in PATH.
"""
function find_nickel_executable()
    nickel_cmd = Sys.iswindows() ? "nickel.exe" : "nickel"
    nickel_path = Sys.which(nickel_cmd)
    if nickel_path === nothing
        throw(NickelError("Nickel executable not found in PATH. Please install Nickel: https://nickel-lang.org/"))
    end
    return nickel_path
end

"""
    nickel_export(code::String; format::Symbol=:json) -> String

Export Nickel code to the specified format string.

# Arguments
- `code::String`: Nickel code to evaluate
- `format::Symbol`: Output format, one of `:json`, `:yaml`, `:toml` (default: `:json`)

# Returns
- `String`: The exported content in the specified format

# Throws
- `NickelError`: If evaluation fails or format is unsupported
"""
function nickel_export(code::String; format::Symbol=:json)
    valid_formats = (:json, :yaml, :toml, :raw)
    if format ∉ valid_formats
        throw(NickelError("Unsupported format: $format. Valid formats: $(join(valid_formats, ", "))"))
    end

    nickel_path = find_nickel_executable()

    # Create a temporary file for the Nickel code
    result = mktempdir() do tmpdir
        ncl_file = joinpath(tmpdir, "input.ncl")
        write(ncl_file, code)

        # Build the command
        cmd = `$nickel_path export --format=$(string(format)) $ncl_file`

        # Run the command and capture output
        stdout_buf = IOBuffer()
        stderr_buf = IOBuffer()

        try
            proc = run(pipeline(cmd, stdout=stdout_buf, stderr=stderr_buf), wait=true)
            return String(take!(stdout_buf))
        catch e
            stderr_content = String(take!(stderr_buf))
            stdout_content = String(take!(stdout_buf))
            error_msg = isempty(stderr_content) ? stdout_content : stderr_content
            if isempty(error_msg)
                error_msg = "Nickel evaluation failed with unknown error"
            end
            throw(NickelError(strip(error_msg)))
        end
    end

    return result
end

"""
    nickel_eval(code::String) -> Any

Evaluate Nickel code and return a Julia value.

The Nickel code is exported to JSON and parsed into Julia types:
- Objects become `Dict{String, Any}`
- Arrays become `Vector{Any}`
- Numbers, strings, booleans map directly

# Arguments
- `code::String`: Nickel code to evaluate

# Returns
- `Any`: The evaluated result as a Julia value

# Examples
```julia
julia> nickel_eval("1 + 2")
3

julia> nickel_eval("{ a = 1, b = 2 }")
Dict{String, Any}("a" => 1, "b" => 2)

julia> nickel_eval("let x = 5 in x * 2")
10
```
"""
function nickel_eval(code::String)
    json_str = nickel_export(code; format=:json)
    return JSON3.read(json_str)
end

"""
    nickel_eval_file(path::String) -> Any

Evaluate a Nickel file and return a Julia value.

# Arguments
- `path::String`: Path to the Nickel file

# Returns
- `Any`: The evaluated result as a Julia value

# Throws
- `NickelError`: If file doesn't exist or evaluation fails
"""
function nickel_eval_file(path::String)
    if !isfile(path)
        throw(NickelError("File not found: $path"))
    end

    nickel_path = find_nickel_executable()

    cmd = `$nickel_path export --format=json $path`

    stdout_buf = IOBuffer()
    stderr_buf = IOBuffer()

    try
        run(pipeline(cmd, stdout=stdout_buf, stderr=stderr_buf), wait=true)
        json_str = String(take!(stdout_buf))
        return JSON3.read(json_str)
    catch e
        stderr_content = String(take!(stderr_buf))
        stdout_content = String(take!(stdout_buf))
        error_msg = isempty(stderr_content) ? stdout_content : stderr_content
        if isempty(error_msg)
            error_msg = "Nickel evaluation failed with unknown error"
        end
        throw(NickelError(strip(error_msg)))
    end
end

"""
    @ncl_str -> Any

String macro for inline Nickel evaluation.

# Examples
```julia
julia> ncl"1 + 2"
3

julia> ncl"{ name = \"test\", value = 42 }"
Dict{String, Any}("name" => "test", "value" => 42)

julia> ncl\"\"\"
       let
         x = 1,
         y = 2
       in x + y
       \"\"\"
3
```
"""
macro ncl_str(code)
    quote
        nickel_eval($code)
    end
end
