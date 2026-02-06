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

## Type Mapping

| Nickel | Julia (native) |
|--------|----------------|
| Integer numbers | `Int64` |
| Decimal numbers | `Float64` |
| Bool | `Bool` |
| String | `String` |
| null | `nothing` |
| Array | `Vector{Any}` |
| Record | `Dict{String, Any}` |

Note: Nickel has a single `Number` type. Whole numbers (like `42` or `42.0`) become `Int64`. Only true decimals (like `3.14`) become `Float64`.

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
