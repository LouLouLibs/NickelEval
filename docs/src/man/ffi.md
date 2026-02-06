# FFI Mode (High Performance)

For repeated evaluations, NickelEval provides native FFI bindings to a Rust library that wraps `nickel-lang-core`. This eliminates subprocess overhead.

## Checking FFI Availability

```julia
using NickelEval

check_ffi_available()  # => true or false
```

FFI is available when the compiled Rust library exists in the `deps/` folder.

## Using FFI Evaluation

```julia
# Basic evaluation
nickel_eval_ffi("1 + 2")  # => 3

# With dot-access
config = nickel_eval_ffi("{ host = \"localhost\", port = 8080 }")
config.host  # => "localhost"

# Typed evaluation
nickel_eval_ffi("{ a = 1, b = 2 }", Dict{String, Int})
# => Dict{String, Int64}("a" => 1, "b" => 2)
```

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

## Binary Protocol

The FFI uses a binary protocol that preserves type information:

| Type Tag | Nickel Type |
|----------|-------------|
| 0 | Null |
| 1 | Bool |
| 2 | Int64 |
| 3 | Float64 |
| 4 | String |
| 5 | Array |
| 6 | Record |

This allows direct conversion to Julia types without JSON parsing overhead.

## Fallback Behavior

If FFI is not available, you can still use the subprocess-based functions:

```julia
# Always works (uses CLI)
nickel_eval("1 + 2")

# Requires FFI library
nickel_eval_ffi("1 + 2")  # Error if not built
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
