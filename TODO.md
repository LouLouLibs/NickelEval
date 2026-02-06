# NickelEval.jl - Status & TODOs

## Completed

### Core Features
- **Subprocess evaluation** - `nickel_eval`, `nickel_eval_file` via CLI
- **FFI native evaluation** - `nickel_eval_native` via Rust binary protocol
- **Type preservation** - Int64 vs Float64 from Nickel types directly
- **Typed evaluation** - `nickel_eval(code, T)` for Dict, NamedTuple, etc.
- **Export functions** - JSON, TOML, YAML via subprocess
- **Documentation** - VitePress site at https://louloulibs.github.io/NickelEval/

### Test Coverage
- 94 tests passing (53 subprocess + 41 FFI)

---

## Next Steps

### 1. Cross-Platform FFI Distribution
Currently FFI requires local Rust build. Options:
- **BinaryBuilder.jl** - Create `NickelEval_jll` for automatic binary distribution
- Support Linux (x86_64, aarch64), macOS (x86_64, aarch64), Windows

### 2. CI FFI Testing
Update CI workflow to build Rust library and run FFI tests.

### 3. Performance Benchmarks
Compare subprocess vs FFI:
```julia
using BenchmarkTools
@benchmark nickel_eval("{ x = 1 }")        # subprocess
@benchmark nickel_eval_native("{ x = 1 }") # FFI
```

---

## Nice-to-Have

- File watching for config reload
- Multi-file evaluation with imports
- NamedTuple output option for records
- Nickel contracts integration

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
check_ffi_available()  # true if library found
nickel_eval_native("42")  # => 42::Int64
```
