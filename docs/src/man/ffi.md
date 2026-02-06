# FFI Mode (High Performance)

For repeated evaluations, NickelEval provides native FFI bindings to a Rust library that wraps `nickel-lang-core`. This eliminates subprocess overhead and preserves Nickel's type semantics.

## Two FFI Functions

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

### Enums

Nickel enums are converted to `Dict{String, Any}` with special fields:

**Simple enum** (no argument):
```julia
nickel_eval_native("let x = 'Foo in x")
# => Dict("_tag" => "Foo")
```

**Enum with argument**:
```julia
nickel_eval_native("let x = 'Some 42 in x")
# => Dict("_tag" => "Some", "_value" => 42)

nickel_eval_native("let x = 'Ok { value = 123 } in x")
# => Dict("_tag" => "Ok", "_value" => Dict("value" => 123))
```

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
