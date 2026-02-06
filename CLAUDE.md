# NickelEval.jl Development Guide

## Project Overview

NickelEval.jl provides Julia bindings for the [Nickel](https://nickel-lang.org/) configuration language. It supports both subprocess-based evaluation (using the Nickel CLI) and native FFI evaluation (using a Rust wrapper around nickel-lang-core).

## Architecture

```
NickelEval/
├── src/
│   ├── NickelEval.jl    # Main module
│   ├── subprocess.jl    # CLI-based evaluation
│   └── ffi.jl           # Native FFI bindings
├── rust/
│   └── nickel-jl/       # Rust FFI wrapper
│       ├── Cargo.toml
│       └── src/lib.rs
├── deps/
│   └── build.jl         # Build script for FFI
└── test/
    └── test_subprocess.jl
```

## Key Design Decisions

### 1. Use JSON.jl 1.0 (not JSON3.jl)

JSON.jl 1.0 provides:
- Native typed parsing with `JSON.parse(json, T)`
- `JSON.Object` return type with dot-access for records
- Better Julia integration

### 2. Types from Nickel FFI, Not JSON

The Rust FFI returns a binary protocol with native type information:
- Type tags: 0=Null, 1=Bool, 2=Int64, 3=Float64, 4=String, 5=Array, 6=Record
- Direct memory encoding without JSON serialization overhead
- Preserves integer vs float distinction

### 3. Avoid `unwrap()` in Rust

Use proper error handling:
```rust
// Bad
let f = value.to_f64().unwrap();

// Good
let f = f64::try_from(value).map_err(|e| format!("Error: {:?}", e))?;
```

For number conversion, use malachite's `RoundingFrom` trait to handle inexact conversions:
```rust
use malachite::rounding_modes::RoundingMode;
use malachite::num::conversion::traits::RoundingFrom;

let (f, _) = f64::rounding_from(&rational, RoundingMode::Nearest);
```

## Building

### Rust FFI Library

```bash
cd rust/nickel-jl
cargo build --release
cp target/release/libnickel_jl.dylib ../../deps/  # macOS
# or libnickel_jl.so on Linux, nickel_jl.dll on Windows
```

### Running Tests

```bash
# Rust tests
cd rust/nickel-jl
cargo test

# Julia tests (requires Nickel CLI installed)
julia --project=. -e 'using Pkg; Pkg.test()'
```

## Release Process

**Before tagging a new version, ALL CI workflows must pass:**

1. Run tests locally: `julia --project=. -e 'using Pkg; Pkg.test()'`
2. Push changes to main
3. Wait for CI to complete and verify all workflows pass (both CI and Documentation)
4. Only then tag and register the new version

```bash
# Check CI status before tagging
gh run list --repo LouLouLibs/NickelEval --limit 5

# All workflows should show "success" before proceeding with:
git tag -a vX.Y.Z -m "vX.Y.Z: Description"
git push origin vX.Y.Z
```

### Version Bumping Checklist

1. Update `version` in `Project.toml`
2. Update `## Current Version` in `TODO.md`
3. Commit these changes
4. Wait for CI to pass
5. Tag the release
6. Update loulouJL registry with correct tree SHA

### Documentation Requirements

Any new exported function must be added to `docs/src/lib/public.md` in the appropriate section to avoid documentation build failures.

### Registry (loulouJL)

Location: `/Users/loulou/Dropbox/projects_code/julia_packages/loulouJL/N/NickelEval/`

After tagging, update `Versions.toml` with:
```bash
git rev-parse vX.Y.Z^{tree}  # Get tree SHA
```

## Binary Protocol Specification

The FFI uses a binary protocol for native type encoding:

| Type Tag | Encoding |
|----------|----------|
| 0 (Null) | Just the tag byte |
| 1 (Bool) | Tag + 1 byte (0=false, 1=true) |
| 2 (Int64) | Tag + 8 bytes (little-endian i64) |
| 3 (Float64) | Tag + 8 bytes (little-endian f64) |
| 4 (String) | Tag + 4 bytes length + UTF-8 bytes |
| 5 (Array) | Tag + 4 bytes count + elements |
| 6 (Record) | Tag + 4 bytes field count + (key_len, key, value)* |

## API Functions

### Evaluation

- `nickel_eval(code)` - Evaluate to `JSON.Object`
- `nickel_eval(code, T)` - Evaluate and convert to type `T`
- `nickel_eval_file(path)` - Evaluate a `.ncl` file
- `nickel_eval_ffi(code)` - FFI-based evaluation (faster)

### Export

- `nickel_to_json(code)` - Export to JSON string
- `nickel_to_toml(code)` - Export to TOML string
- `nickel_to_yaml(code)` - Export to YAML string
- `nickel_export(code; format=:json)` - Export to any format

## Type Conversion

| Nickel Type | Julia Type |
|-------------|------------|
| Null | `nothing` |
| Bool | `Bool` |
| Number (integer) | `Int64` |
| Number (float) | `Float64` |
| String | `String` |
| Array | `Vector` or `JSON.Array` |
| Record | `JSON.Object`, `Dict`, `NamedTuple`, or struct |

## Nickel Language Reference

Common patterns used in tests:

```nickel
# Let bindings
let x = 1 in x + 2

# Functions
let double = fun x => x * 2 in double 21

# Records
{ name = "test", value = 42 }

# Record merge
{ a = 1 } & { b = 2 }

# Arrays
[1, 2, 3]

# Array operations
[1, 2, 3] |> std.array.map (fun x => x * 2)

# Nested structures
{ outer = { inner = 42 } }
```

## Dependencies

### Julia
- JSON.jl >= 1.0

### Rust
- nickel-lang-core = "0.9"
- malachite = "0.4"
- serde_json = "1.0"

## Future Improvements

1. Complete Julia-side binary protocol decoder
2. Support for Nickel contracts/types in Julia
3. Streaming evaluation for large configs
4. REPL integration
