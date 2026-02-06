# FFI Mode (High Performance)

For repeated evaluations, NickelEval provides native FFI bindings to a Rust library that wraps `nickel-lang-core`. This eliminates subprocess overhead and preserves Nickel's type semantics.

## FFI Functions

### `nickel_eval_native` - Native Types (Recommended)

Parses Nickel directly into Julia native types using a binary protocol:

```julia
nickel_eval_native("42")           # => 42::Int64
nickel_eval_native("3.14")         # => 3.14::Float64
nickel_eval_native("true")         # => true::Bool
nickel_eval_native("\"hello\"")    # => "hello"::String
nickel_eval_native("null")         # => nothing

nickel_eval_native("[1, 2, 3]")    # => Any[1, 2, 3]
nickel_eval_native("{ x = 1 }")    # => Dict("x" => 1)
```

**Key benefit:** Type preservation. Integers stay `Int64`, decimals become `Float64`.

### `nickel_eval_file_native` - File Evaluation with Imports

Evaluates Nickel files from the filesystem, supporting `import` statements:

```julia
# config.ncl:
# let shared = import "shared.ncl" in
# { name = shared.project_name, version = "1.0" }

nickel_eval_file_native("config.ncl")
# => Dict{String, Any}("name" => "MyProject", "version" => "1.0")
```

**Import resolution:**
- `import "other.ncl"` - resolved relative to the file's directory
- `import "lib/module.ncl"` - subdirectory paths supported
- `import "/absolute/path.ncl"` - absolute paths work too

**Example with nested imports:**

```julia
# Create a project structure:
# project/
# ├── main.ncl          (imports shared.ncl and lib/utils.ncl)
# ├── shared.ncl
# └── lib/
#     └── utils.ncl

# shared.ncl
# {
#   project_name = "MyApp"
# }

# lib/utils.ncl
# {
#   double = fun x => x * 2
# }

# main.ncl
# let shared = import "shared.ncl" in
# let utils = import "lib/utils.ncl" in
# {
#   name = shared.project_name,
#   result = utils.double 21
# }

result = nickel_eval_file_native("project/main.ncl")
result["name"]    # => "MyApp"
result["result"]  # => 42
```

### `nickel_eval_ffi` - JSON-based

Uses JSON serialization internally, supports typed parsing:

```julia
nickel_eval_ffi("{ a = 1, b = 2 }")             # JSON.Object with dot-access
nickel_eval_ffi("{ a = 1 }", Dict{String, Int}) # Typed Dict
```

## Supported Types

### Primitive Types

| Nickel | Julia | Example |
|--------|-------|---------|
| Integer numbers | `Int64` | `42` → `42::Int64` |
| Decimal numbers | `Float64` | `3.14` → `3.14::Float64` |
| Booleans | `Bool` | `true` → `true::Bool` |
| Strings | `String` | `"hello"` → `"hello"::String` |
| Null | `Nothing` | `null` → `nothing` |

**Note:** Nickel has a single `Number` type. Whole numbers (like `42` or `42.0`) become `Int64`. Only true decimals (like `3.14`) become `Float64`.

### Compound Types

| Nickel | Julia | Example |
|--------|-------|---------|
| Arrays | `Vector{Any}` | `[1, 2, 3]` → `Any[1, 2, 3]` |
| Records | `Dict{String, Any}` | `{ x = 1 }` → `Dict("x" => 1)` |
| Enums | `NickelEnum` | `'Some 42` → `NickelEnum(:Some, 42)` |

### Enums

Nickel enums (also called "enum tags" or "variants") are converted to the `NickelEnum` type, preserving enum semantics distinct from regular records.

#### The NickelEnum Type

```julia
struct NickelEnum
    tag::Symbol   # The variant name as a Julia Symbol
    arg::Any      # The argument (nothing for simple enums)
end
```

#### Simple Enums (No Argument)

Simple enums are tags without associated data, commonly used for status flags or options:

```julia
# Boolean-like enums
result = nickel_eval_native("let x = 'True in x")
result.tag   # => :True
result.arg   # => nothing

# Status enums
result = nickel_eval_native("let status = 'Pending in status")
result == :Pending  # => true (convenience comparison)

# Multiple variants
code = \"\"\"
let color = 'Red in color
\"\"\"
result = nickel_eval_native(code)
result.tag  # => :Red
```

#### Enums with Primitive Arguments

Enums can carry a single value of any type:

```julia
# Integer argument
result = nickel_eval_native("let x = 'Count 42 in x")
result.tag   # => :Count
result.arg   # => 42 (Int64)

# String argument
result = nickel_eval_native("let x = 'Message \"hello\" in x")
result.tag   # => :Message
result.arg   # => "hello"

# Float argument
result = nickel_eval_native("let x = 'Temperature 98.6 in x")
result.arg   # => 98.6 (Float64)

# Boolean argument
result = nickel_eval_native("let x = 'Flag true in x")
result.arg   # => true
```

#### Enums with Record Arguments

Enums can carry complex record data:

```julia
# Record argument
code = \"\"\"
let result = 'Ok { value = 123, message = "success" } in result
\"\"\"
result = nickel_eval_native(code)
result.tag              # => :Ok
result.arg              # => Dict{String, Any}
result.arg["value"]     # => 123
result.arg["message"]   # => "success"

# Error with details
code = \"\"\"
let err = 'Error { code = 404, reason = "not found" } in err
\"\"\"
result = nickel_eval_native(code)
result.tag              # => :Error
result.arg["code"]      # => 404
result.arg["reason"]    # => "not found"
```

#### Enums with Array Arguments

```julia
# Array argument
code = \"\"\"
let batch = 'Batch [1, 2, 3, 4, 5] in batch
\"\"\"
result = nickel_eval_native(code)
result.tag   # => :Batch
result.arg   # => Any[1, 2, 3, 4, 5]
```

#### Nested Enums

Enums can contain other enums:

```julia
# Nested enum in record
code = \"\"\"
let outer = 'Container { inner = 'Value 42 } in outer
\"\"\"
result = nickel_eval_native(code)
result.tag                 # => :Container
result.arg["inner"].tag    # => :Value
result.arg["inner"].arg    # => 42

# Enum in array
code = \"\"\"
let items = 'List ['Some 1, 'None, 'Some 3] in items
\"\"\"
result = nickel_eval_native(code)
result.tag         # => :List
result.arg[1].tag  # => :Some
result.arg[1].arg  # => 1
result.arg[2].tag  # => :None
result.arg[2].arg  # => nothing
```

#### Pattern Matching with Nickel

When Nickel's `match` expression resolves an enum, you get the matched value:

```julia
# Match resolves to the extracted value
code = \"\"\"
let x = 'Some 42 in
x |> match {
  'Some v => v,
  'None => 0
}
\"\"\"
result = nickel_eval_native(code)
# => 42 (the matched value, not an enum)

# Match with record destructuring
code = \"\"\"
let result = 'Ok { value = 100 } in
result |> match {
  'Ok r => r.value,
  'Error _ => -1
}
\"\"\"
result = nickel_eval_native(code)
# => 100
```

#### Working with NickelEnum in Julia

```julia
# Type checking
result = nickel_eval_native("let x = 'Some 42 in x")
result isa NickelEnum  # => true

# Symbol comparison (both directions work)
result == :Some  # => true
:Some == result  # => true

# Accessing fields
result.tag  # => :Some
result.arg  # => 42

# Pretty printing
repr(result)  # => "'Some 42"

# Simple enum printing
repr(nickel_eval_native("let x = 'None in x"))  # => "'None"
```

#### Real-World Example: Result Type

```julia
# Simulating Rust-like Result type
code = \"\"\"
let divide = fun a b =>
  if b == 0 then
    'Err "division by zero"
  else
    'Ok (a / b)
in
divide 10 2
\"\"\"
result = nickel_eval_native(code)
if result == :Ok
    println("Result: ", result.arg)  # => 5
else
    println("Error: ", result.arg)
end
```

This representation mirrors Nickel's `std.enum.to_tag_and_arg` semantics while providing a proper Julia type that preserves enum identity.

### Nested Structures

Arbitrary nesting is fully supported:

```julia
# Deeply nested records
result = nickel_eval_native("{ a = { b = { c = 42 } } }")
result["a"]["b"]["c"]  # => 42

# Arrays of records
result = nickel_eval_native("[{ id = 1 }, { id = 2 }]")
result[1]["id"]  # => 1

# Records with arrays
result = nickel_eval_native("{ items = [1, 2, 3], name = \"test\" }")
result["items"]  # => Any[1, 2, 3]

# Mixed nesting
result = nickel_eval_native("{ data = [{ a = 1 }, { b = [true, false] }] }")
result["data"][2]["b"]  # => Any[true, false]
```

### Computed Values

Functions and expressions are evaluated before conversion:

```julia
nickel_eval_native("1 + 2")  # => 3
nickel_eval_native("let x = 10 in x * 2")  # => 20
nickel_eval_native("[1, 2, 3] |> std.array.map (fun x => x * 2)")  # => Any[2, 4, 6]
nickel_eval_native("{ a = 1 } & { b = 2 }")  # => Dict("a" => 1, "b" => 2)
```

## Checking FFI Availability

```julia
using NickelEval

check_ffi_available()  # => true or false
```

FFI is available when the compiled Rust library exists in the `deps/` folder.

## Building the FFI Library

### Requirements

- Rust toolchain (install from [rustup.rs](https://rustup.rs))
- Cargo

### Build Steps

```bash
cd rust/nickel-jl
cargo build --release
```

Then copy the library to `deps/`:

```bash
# macOS
cp target/release/libnickel_jl.dylib ../../deps/

# Linux
cp target/release/libnickel_jl.so ../../deps/

# Windows
cp target/release/nickel_jl.dll ../../deps/
```

## Performance Comparison

FFI mode is faster for repeated evaluations because it:

1. **No process spawn**: Direct library calls instead of subprocess
2. **Shared memory**: Values transfer directly without serialization
3. **Persistent state**: Library remains loaded

For single evaluations, the difference is minimal. For batch processing or interactive use, FFI mode is significantly faster.

## Fallback Behavior

If FFI is not available, you can still use the subprocess-based functions:

```julia
# Always works (uses CLI)
nickel_eval("1 + 2")

# Requires FFI library
nickel_eval_native("1 + 2")  # Error if not built
```

## Troubleshooting

### "FFI not available" Error

Build the Rust library:

```bash
cd rust/nickel-jl
cargo build --release
cp target/release/libnickel_jl.* ../../deps/
```

### Library Not Found

Ensure the library has the correct name for your platform:
- macOS: `libnickel_jl.dylib`
- Linux: `libnickel_jl.so`
- Windows: `nickel_jl.dll`
