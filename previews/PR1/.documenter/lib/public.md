
# Public API {#Public-API}

## Evaluation Functions {#Evaluation-Functions}
<details class='jldocstring custom-block' open>
<summary><a id='NickelEval.nickel_eval' href='#NickelEval.nickel_eval'><span class="jlbinding">NickelEval.nickel_eval</span></a> <Badge type="info" class="jlObjectType jlFunction" text="Function" /></summary>



```julia
nickel_eval(code::String) -> JSON.Object
```


Evaluate Nickel code and return a Julia value.

Returns a `JSON.Object` for records (supports dot-access), or native Julia types for primitives and arrays.

**Arguments**
- `code::String`: Nickel code to evaluate
  

**Returns**
- Result as Julia value (JSON.Object for records, Vector for arrays, etc.)
  

**Examples**

```julia
julia> nickel_eval("1 + 2")
3

julia> result = nickel_eval("{ a = 1, b = 2 }")
julia> result.a  # dot-access supported
1

julia> nickel_eval("let x = 5 in x * 2")
10
```



<Badge type="info" class="source-link" text="source"><a href="https://github.com/LouLouLibs/NickelEval/blob/09604404a548ff8606640ed4e6086e9aa20c35d4/src/subprocess.jl#L69-L95" target="_blank" rel="noreferrer">source</a></Badge>



```julia
nickel_eval(code::String, ::Type{T}) -> T
```


Evaluate Nickel code and parse the result directly into a specific Julia type.

Uses JSON.jl 1.0&#39;s native typed parsing. Works with:
- Primitive types: `Int`, `Float64`, `String`, `Bool`
  
- Typed dictionaries: `Dict{String, Int}`, `Dict{Symbol, Float64}`
  
- Typed arrays: `Vector{Int}`, `Vector{String}`
  
- NamedTuples for quick typed record access
  
- Custom structs
  

**Arguments**
- `code::String`: Nickel code to evaluate
  
- `T::Type`: Target Julia type
  

**Returns**
- `T`: The evaluated result as the specified type
  

**Examples**

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



<Badge type="info" class="source-link" text="source"><a href="https://github.com/LouLouLibs/NickelEval/blob/09604404a548ff8606640ed4e6086e9aa20c35d4/src/subprocess.jl#L101-L134" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='NickelEval.nickel_eval_file' href='#NickelEval.nickel_eval_file'><span class="jlbinding">NickelEval.nickel_eval_file</span></a> <Badge type="info" class="jlObjectType jlFunction" text="Function" /></summary>



```julia
nickel_eval_file(path::String) -> JSON.Object
nickel_eval_file(path::String, ::Type{T}) -> T
```


Evaluate a Nickel file and return a Julia value.

**Arguments**
- `path::String`: Path to the Nickel file
  
- `T::Type`: (optional) Target Julia type for typed parsing
  

**Returns**
- `JSON.Object` or `T`: The evaluated result as a Julia value
  

**Throws**
- `NickelError`: If file doesn&#39;t exist or evaluation fails
  

**Examples**

```julia
# Untyped evaluation (returns JSON.Object with dot-access)
julia> config = nickel_eval_file("config.ncl")
julia> config.port
8080

# Typed evaluation
julia> nickel_eval_file("config.ncl", @NamedTuple{port::Int, host::String})
(port = 8080, host = "localhost")
```



<Badge type="info" class="source-link" text="source"><a href="https://github.com/LouLouLibs/NickelEval/blob/09604404a548ff8606640ed4e6086e9aa20c35d4/src/subprocess.jl#L153-L180" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='NickelEval.nickel_read' href='#NickelEval.nickel_read'><span class="jlbinding">NickelEval.nickel_read</span></a> <Badge type="info" class="jlObjectType jlFunction" text="Function" /></summary>



```julia
nickel_read(code::String, ::Type{T}) -> T
```


Alias for `nickel_eval(code, T)`. Evaluate Nickel code into a typed Julia value.

**Examples**

```julia
julia> nickel_read("{ port = 8080, host = "localhost" }", @NamedTuple{port::Int, host::String})
(port = 8080, host = "localhost")
```



<Badge type="info" class="source-link" text="source"><a href="https://github.com/LouLouLibs/NickelEval/blob/09604404a548ff8606640ed4e6086e9aa20c35d4/src/subprocess.jl#L140-L150" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='NickelEval.find_nickel_executable' href='#NickelEval.find_nickel_executable'><span class="jlbinding">NickelEval.find_nickel_executable</span></a> <Badge type="info" class="jlObjectType jlFunction" text="Function" /></summary>



```julia
find_nickel_executable() -> String
```


Find the Nickel executable in PATH.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/LouLouLibs/NickelEval/blob/09604404a548ff8606640ed4e6086e9aa20c35d4/src/subprocess.jl#L3-L7" target="_blank" rel="noreferrer">source</a></Badge>

</details>


## Export Functions {#Export-Functions}
<details class='jldocstring custom-block' open>
<summary><a id='NickelEval.nickel_export' href='#NickelEval.nickel_export'><span class="jlbinding">NickelEval.nickel_export</span></a> <Badge type="info" class="jlObjectType jlFunction" text="Function" /></summary>



```julia
nickel_export(code::String; format::Symbol=:json) -> String
```


Export Nickel code to the specified format string.

**Arguments**
- `code::String`: Nickel code to evaluate
  
- `format::Symbol`: Output format, one of `:json`, `:yaml`, `:toml` (default: `:json`)
  

**Returns**
- `String`: The exported content in the specified format
  

**Throws**
- `NickelError`: If evaluation fails or format is unsupported
  


<Badge type="info" class="source-link" text="source"><a href="https://github.com/LouLouLibs/NickelEval/blob/09604404a548ff8606640ed4e6086e9aa20c35d4/src/subprocess.jl#L17-L31" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='NickelEval.nickel_to_json' href='#NickelEval.nickel_to_json'><span class="jlbinding">NickelEval.nickel_to_json</span></a> <Badge type="info" class="jlObjectType jlFunction" text="Function" /></summary>



```julia
nickel_to_json(code::String) -> String
```


Export Nickel code to JSON string.

**Examples**

```julia
julia> nickel_to_json("{ a = 1, b = 2 }")
"{\n  \"a\": 1,\n  \"b\": 2\n}"
```



<Badge type="info" class="source-link" text="source"><a href="https://github.com/LouLouLibs/NickelEval/blob/09604404a548ff8606640ed4e6086e9aa20c35d4/src/subprocess.jl#L247-L257" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='NickelEval.nickel_to_toml' href='#NickelEval.nickel_to_toml'><span class="jlbinding">NickelEval.nickel_to_toml</span></a> <Badge type="info" class="jlObjectType jlFunction" text="Function" /></summary>



```julia
nickel_to_toml(code::String) -> String
```


Export Nickel code to TOML string.

**Examples**

```julia
julia> nickel_to_toml("{ name = "myapp", port = 8080 }")
"name = \"myapp\"\nport = 8080\n"
```



<Badge type="info" class="source-link" text="source"><a href="https://github.com/LouLouLibs/NickelEval/blob/09604404a548ff8606640ed4e6086e9aa20c35d4/src/subprocess.jl#L260-L270" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='NickelEval.nickel_to_yaml' href='#NickelEval.nickel_to_yaml'><span class="jlbinding">NickelEval.nickel_to_yaml</span></a> <Badge type="info" class="jlObjectType jlFunction" text="Function" /></summary>



```julia
nickel_to_yaml(code::String) -> String
```


Export Nickel code to YAML string.

**Examples**

```julia
julia> nickel_to_yaml("{ name = "myapp", port = 8080 }")
"name: myapp\nport: 8080\n"
```



<Badge type="info" class="source-link" text="source"><a href="https://github.com/LouLouLibs/NickelEval/blob/09604404a548ff8606640ed4e6086e9aa20c35d4/src/subprocess.jl#L273-L283" target="_blank" rel="noreferrer">source</a></Badge>

</details>


## FFI Functions {#FFI-Functions}
<details class='jldocstring custom-block' open>
<summary><a id='NickelEval.check_ffi_available' href='#NickelEval.check_ffi_available'><span class="jlbinding">NickelEval.check_ffi_available</span></a> <Badge type="info" class="jlObjectType jlFunction" text="Function" /></summary>



```julia
check_ffi_available() -> Bool
```


Check if FFI bindings are available. Returns true if the native library is compiled and available.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/LouLouLibs/NickelEval/blob/09604404a548ff8606640ed4e6086e9aa20c35d4/src/ffi.jl#L31-L36" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='NickelEval.nickel_eval_ffi' href='#NickelEval.nickel_eval_ffi'><span class="jlbinding">NickelEval.nickel_eval_ffi</span></a> <Badge type="info" class="jlObjectType jlFunction" text="Function" /></summary>



```julia
nickel_eval_ffi(code::String) -> JSON.Object
nickel_eval_ffi(code::String, ::Type{T}) -> T
```


Evaluate Nickel code using native FFI bindings (faster than subprocess). Returns the parsed JSON result, optionally typed.

Throws `NickelError` if FFI is not available or if evaluation fails.

**Examples**

```julia
julia> nickel_eval_ffi("1 + 2")
3

julia> result = nickel_eval_ffi("{ x = 1, y = 2 }")
julia> result.x  # dot-access supported
1

julia> nickel_eval_ffi("{ x = 1, y = 2 }", Dict{String, Int})
Dict{String, Int64}("x" => 1, "y" => 2)
```



<Badge type="info" class="source-link" text="source"><a href="https://github.com/LouLouLibs/NickelEval/blob/09604404a548ff8606640ed4e6086e9aa20c35d4/src/ffi.jl#L41-L62" target="_blank" rel="noreferrer">source</a></Badge>

</details>


## String Macro {#String-Macro}
<details class='jldocstring custom-block' open>
<summary><a id='NickelEval.@ncl_str' href='#NickelEval.@ncl_str'><span class="jlbinding">NickelEval.@ncl_str</span></a> <Badge type="info" class="jlObjectType jlMacro" text="Macro" /></summary>



```julia
@ncl_str -> Any
```


String macro for inline Nickel evaluation.

**Examples**

```julia
julia> ncl"1 + 2"
3

julia> ncl"{ name = "test", value = 42 }".name
"test"

julia> ncl"""
       let
         x = 1,
         y = 2
       in x + y
       """
3
```



<Badge type="info" class="source-link" text="source"><a href="https://github.com/LouLouLibs/NickelEval/blob/09604404a548ff8606640ed4e6086e9aa20c35d4/src/subprocess.jl#L217-L238" target="_blank" rel="noreferrer">source</a></Badge>

</details>

