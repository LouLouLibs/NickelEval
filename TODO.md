# NickelEval.jl - Next Session TODOs

## Current State (v0.2.0)

**Working:**
- Subprocess-based Nickel evaluation (`nickel_eval`, `nickel_eval_file`)
- Typed evaluation to Julia native types (Dict, NamedTuple, Vector, structs)
- Export functions (JSON, TOML, YAML)
- String macro (`ncl"..."`)
- Documentation site with VitePress at https://louloulibs.github.io/NickelEval/dev/
- CI passing with 53 tests

**Infrastructure Ready but Not Integrated:**
- Rust FFI library (`rust/nickel-jl/`) - complete with 33 tests
- Binary protocol for native type encoding (preserves Int64 vs Float64)
- Julia FFI bindings skeleton (`src/ffi.jl`)

---

## Priority 1: Complete FFI Integration

### 1.1 Build and Test Rust Library Locally
```bash
cd rust/nickel-jl
cargo build --release
cp target/release/libnickel_jl.dylib ../../deps/  # macOS
# or libnickel_jl.so for Linux
```

### 1.2 Add Native Binary Decoder in Julia
The Rust side encodes to binary protocol, but Julia only has JSON decoding.
Need to add in `src/ffi.jl`:
```julia
function decode_native(buffer::Vector{UInt8}) -> Any
    # Decode binary protocol: TYPE_NULL=0, TYPE_BOOL=1, TYPE_INT=2, etc.
end
```

### 1.3 Add `nickel_eval_native_ffi` Function
Use `nickel_eval_native` from Rust + Julia decoder for true type preservation.

---

## Priority 2: Cross-Platform Distribution

### 2.1 BinaryBuilder.jl Integration
Create `build_tarballs.jl` to build for all platforms:
- Linux x86_64, aarch64
- macOS x86_64, aarch64
- Windows x86_64

### 2.2 Create JLL Package
`NickelEval_jll` package for automatic binary distribution.

---

## Priority 3: Performance & Benchmarks

### 3.1 Add Benchmarks
Compare subprocess vs FFI:
```julia
using BenchmarkTools
@benchmark nickel_eval("{ x = 1 }")      # subprocess
@benchmark nickel_eval_ffi("{ x = 1 }")  # FFI
```

### 3.2 Caching Layer (Optional)
Consider caching evaluated configs for repeated access.

---

## Priority 4: Additional Features

### 4.1 File Watching
```julia
watch_nickel_file("config.ncl") do config
    # Called when file changes
end
```

### 4.2 Nickel Contracts Integration
Expose Nickel's type system for runtime validation.

### 4.3 Multi-file Evaluation
Support `import` statements and multiple file evaluation.

---

## Quick Reference

**Build FFI locally:**
```bash
cd rust/nickel-jl && cargo build --release
mkdir -p deps
cp target/release/libnickel_jl.dylib deps/  # macOS
```

**Test FFI available:**
```julia
using NickelEval
check_ffi_available()  # should return true after build
nickel_eval_ffi("1 + 2")  # test it works
```

**Registry:** loulouJL (https://github.com/LouLouLibs/loulouJL)
**Docs:** https://louloulibs.github.io/NickelEval/dev/
