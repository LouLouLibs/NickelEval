# NickelEval.jl - Status & TODOs

## Current Version: v0.3.0

## Completed Features

### Core Evaluation
- **Subprocess evaluation** - `nickel_eval`, `nickel_eval_file`, `nickel_read` via Nickel CLI
- **FFI native evaluation** - `nickel_eval_native` via Rust binary protocol
- **FFI file evaluation** - `nickel_eval_file_native` with import support
- **FFI JSON evaluation** - `nickel_eval_ffi` with typed parsing support

### Type System
- **Primitives**: `Int64`, `Float64`, `Bool`, `String`, `Nothing`
- **Compounds**: `Vector{Any}`, `Dict{String, Any}`
- **Enums**: `NickelEnum` with `tag::Symbol` and `arg::Any`
  - Simple enums: `'Foo` → `NickelEnum(:Foo, nothing)`
  - With arguments: `'Some 42` → `NickelEnum(:Some, 42)`
  - Nested enums, arrays of enums, enums in records
  - Pattern matching support
  - Pretty printing: `'Some 42`

### Export Functions
- `nickel_to_json`, `nickel_to_toml`, `nickel_to_yaml` via subprocess

### Infrastructure
- Documentation site: https://louloulibs.github.io/NickelEval/dev/
- 180 tests passing (53 subprocess + 127 FFI)
- CI: tests + documentation deployment
- Registry: loulouJL

---

## Next Steps

### 1. Cross-Platform FFI Distribution
Currently FFI requires local Rust build. Options:
- **BinaryBuilder.jl** - Create `NickelEval_jll` for automatic binary distribution
- Support Linux (x86_64, aarch64), macOS (x86_64, aarch64), Windows

### 2. CI FFI Testing
Update CI workflow to build Rust library and run FFI tests.
Currently CI only tests subprocess mode.

### 3. Performance Benchmarks
```julia
using BenchmarkTools
@benchmark nickel_eval("{ x = 1 }")        # subprocess
@benchmark nickel_eval_native("{ x = 1 }") # FFI
```

---

## Nice-to-Have

- **File watching** - auto-reload config on file change
- **NamedTuple output** - optional record → NamedTuple conversion
- **Nickel contracts** - expose type validation

---

## Quick Reference

**Build FFI locally:**
```bash
cd rust/nickel-jl && cargo build --release
cp target/release/libnickel_jl.dylib ../deps/  # macOS
cp target/release/libnickel_jl.so ../deps/     # Linux
```

**Test FFI:**
```julia
using NickelEval
check_ffi_available()           # true if library found
nickel_eval_native("42")        # => 42::Int64
nickel_eval_native("'Some 42")  # => NickelEnum(:Some, 42)
```

**Registry:** loulouJL (https://github.com/LouLouLibs/loulouJL)
**Docs:** https://louloulibs.github.io/NickelEval/dev/
**Repo:** https://github.com/LouLouLibs/NickelEval
