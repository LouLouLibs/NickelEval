# NickelEval.jl - Next Session TODOs

## Goal

**Parse Nickel directly into Julia native types** via FFI binary protocol.

The Rust FFI encodes Nickel values with type tags:
- `TYPE_INT (2)` → `Int64`
- `TYPE_FLOAT (3)` → `Float64`
- `TYPE_STRING (4)` → `String`
- `TYPE_BOOL (1)` → `Bool`
- `TYPE_NULL (0)` → `nothing`
- `TYPE_ARRAY (5)` → `Vector`
- `TYPE_RECORD (6)` → `Dict{String, Any}` or `NamedTuple`

This preserves Nickel's type semantics directly—no JSON round-trip.

---

## Current State

**Done:**
- Rust FFI library (`rust/nickel-jl/src/lib.rs`) - encodes to binary protocol
- 33 Rust tests passing
- Julia FFI skeleton (`src/ffi.jl`) - calls Rust, but only JSON path implemented

**TODO:**
- Julia binary decoder (`decode_native`)
- Build Rust library
- Test end-to-end

---

## Next Session Tasks

### 1. Add Julia Binary Decoder

In `src/ffi.jl`, add:

```julia
const TYPE_NULL   = 0x00
const TYPE_BOOL   = 0x01
const TYPE_INT    = 0x02
const TYPE_FLOAT  = 0x03
const TYPE_STRING = 0x04
const TYPE_ARRAY  = 0x05
const TYPE_RECORD = 0x06

function decode_native(data::Vector{UInt8})
    io = IOBuffer(data)
    return _decode_value(io)
end

function _decode_value(io::IOBuffer)
    tag = read(io, UInt8)
    if tag == TYPE_NULL
        return nothing
    elseif tag == TYPE_BOOL
        return read(io, UInt8) != 0
    elseif tag == TYPE_INT
        return read(io, Int64)
    elseif tag == TYPE_FLOAT
        return read(io, Float64)
    elseif tag == TYPE_STRING
        len = read(io, UInt32)
        return String(read(io, len))
    elseif tag == TYPE_ARRAY
        len = read(io, UInt32)
        return [_decode_value(io) for _ in 1:len]
    elseif tag == TYPE_RECORD
        len = read(io, UInt32)
        dict = Dict{String, Any}()
        for _ in 1:len
            key_len = read(io, UInt32)
            key = String(read(io, key_len))
            dict[key] = _decode_value(io)
        end
        return dict
    else
        error("Unknown type tag: $tag")
    end
end
```

### 2. Add `nickel_eval_native_ffi`

```julia
function nickel_eval_native_ffi(code::String)
    if !FFI_AVAILABLE
        error("FFI not available. Build with: cd rust/nickel-jl && cargo build --release")
    end

    buffer = ccall((:nickel_eval_native, LIB_PATH),
                   NativeBuffer, (Cstring,), code)

    if buffer.data == C_NULL
        error_ptr = ccall((:nickel_get_error, LIB_PATH), Ptr{Cchar}, ())
        throw(NickelError(unsafe_string(error_ptr)))
    end

    data = unsafe_wrap(Array, buffer.data, buffer.len; own=false)
    result = decode_native(copy(data))

    ccall((:nickel_free_buffer, LIB_PATH), Cvoid, (NativeBuffer,), buffer)

    return result
end
```

### 3. Build & Test

```bash
cd rust/nickel-jl && cargo build --release
mkdir -p ../../deps
cp target/release/libnickel_jl.dylib ../../deps/  # macOS
```

```julia
using NickelEval
nickel_eval_native_ffi("42")           # => 42::Int64
nickel_eval_native_ffi("3.14")         # => 3.14::Float64
nickel_eval_native_ffi("{ x = 1 }")    # => Dict("x" => 1)
```

---

## Later (nice-to-have)

- Cross-platform distribution via BinaryBuilder.jl
- TOML/YAML export (already works via subprocess)
- File watching
