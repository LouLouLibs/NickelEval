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
    nickel_eval(code::String) -> JSON.Object

Evaluate Nickel code and return a Julia value.

Returns a `JSON.Object` for records (supports dot-access), or native Julia types
for primitives and arrays.

# Arguments
- `code::String`: Nickel code to evaluate

# Returns
- Result as Julia value (JSON.Object for records, Vector for arrays, etc.)

# Examples
```julia
julia> nickel_eval("1 + 2")
3

julia> result = nickel_eval("{ a = 1, b = 2 }")
julia> result.a  # dot-access supported
1

julia> nickel_eval("let x = 5 in x * 2")
10
```
"""
function nickel_eval(code::String)
    json_str = nickel_export(code; format=:json)
    return JSON.parse(json_str)
end

"""
    nickel_eval(code::String, ::Type{T}) -> T

Evaluate Nickel code and parse the result directly into a specific Julia type.

Uses JSON.jl 1.0's native typed parsing. Works with:
- Primitive types: `Int`, `Float64`, `String`, `Bool`
- Typed dictionaries: `Dict{String, Int}`, `Dict{Symbol, Float64}`
- Typed arrays: `Vector{Int}`, `Vector{String}`
- NamedTuples for quick typed record access
- Custom structs

# Arguments
- `code::String`: Nickel code to evaluate
- `T::Type`: Target Julia type

# Returns
- `T`: The evaluated result as the specified type

# Examples
```julia
julia> nickel_eval("1 + 2", Int)
3

julia> nickel_eval("{ a = 1, b = 2 }", Dict{String, Int})
Dict{String, Int64}("a" => 1, "b" => 2)

julia> nickel_eval("[1, 2, 3]", Vector{Int})
[1, 2, 3]

julia> nickel_eval("{ x = 1.5, y = 2.5 }", @NamedTuple{x::Float64, y::Float64})
(x = 1.5, y = 2.5)
```
"""
function nickel_eval(code::String, ::Type{T}) where T
    json_str = nickel_export(code; format=:json)
    return JSON.parse(json_str, T)
end

"""
    nickel_read(code::String, ::Type{T}) -> T

Alias for `nickel_eval(code, T)`. Evaluate Nickel code into a typed Julia value.

# Examples
```julia
julia> nickel_read("{ port = 8080, host = \"localhost\" }", @NamedTuple{port::Int, host::String})
(port = 8080, host = "localhost")
```
"""
nickel_read(code::String, ::Type{T}) where T = nickel_eval(code, T)

"""
    nickel_eval_file(path::String) -> JSON.Object
    nickel_eval_file(path::String, ::Type{T}) -> T

Evaluate a Nickel file and return a Julia value.

# Arguments
- `path::String`: Path to the Nickel file
- `T::Type`: (optional) Target Julia type for typed parsing

# Returns
- `JSON.Object` or `T`: The evaluated result as a Julia value

# Throws
- `NickelError`: If file doesn't exist or evaluation fails

# Examples
```julia
# Untyped evaluation (returns JSON.Object with dot-access)
julia> config = nickel_eval_file("config.ncl")
julia> config.port
8080

# Typed evaluation
julia> nickel_eval_file("config.ncl", @NamedTuple{port::Int, host::String})
(port = 8080, host = "localhost")
```
"""
function nickel_eval_file(path::String)
    json_str = _eval_file_to_json(path)
    return JSON.parse(json_str)
end

function nickel_eval_file(path::String, ::Type{T}) where T
    json_str = _eval_file_to_json(path)
    return JSON.parse(json_str, T)
end

function _eval_file_to_json(path::String)
    if !isfile(path)
        throw(NickelError("File not found: $path"))
    end

    nickel_path = find_nickel_executable()

    cmd = `$nickel_path export --format=json $path`

    stdout_buf = IOBuffer()
    stderr_buf = IOBuffer()

    try
        run(pipeline(cmd, stdout=stdout_buf, stderr=stderr_buf), wait=true)
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

"""
    @ncl_str -> Any

String macro for inline Nickel evaluation.

# Examples
```julia
julia> ncl"1 + 2"
3

julia> ncl"{ name = \"test\", value = 42 }".name
"test"

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

# Convenience export functions

"""
    nickel_to_json(code::String) -> String

Export Nickel code to JSON string.

# Examples
```julia
julia> nickel_to_json("{ a = 1, b = 2 }")
"{\\n  \\"a\\": 1,\\n  \\"b\\": 2\\n}"
```
"""
nickel_to_json(code::String) = nickel_export(code; format=:json)

"""
    nickel_to_toml(code::String) -> String

Export Nickel code to TOML string.

# Examples
```julia
julia> nickel_to_toml("{ name = \"myapp\", port = 8080 }")
"name = \\"myapp\\"\\nport = 8080\\n"
```
"""
nickel_to_toml(code::String) = nickel_export(code; format=:toml)

"""
    nickel_to_yaml(code::String) -> String

Export Nickel code to YAML string.

# Examples
```julia
julia> nickel_to_yaml("{ name = \"myapp\", port = 8080 }")
"name: myapp\\nport: 8080\\n"
```
"""
nickel_to_yaml(code::String) = nickel_export(code; format=:yaml)
