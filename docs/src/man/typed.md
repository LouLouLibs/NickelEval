# Typed Evaluation

NickelEval supports converting Nickel values directly to typed Julia values using `JSON.jl 1.0`'s native typed parsing.

## Basic Types

```julia
nickel_eval("42", Int)        # => 42
nickel_eval("3.14", Float64)  # => 3.14
nickel_eval("\"hi\"", String) # => "hi"
nickel_eval("true", Bool)     # => true
```

## Typed Dictionaries

### String Keys

```julia
result = nickel_eval("{ a = 1, b = 2 }", Dict{String, Int})
# => Dict{String, Int64}("a" => 1, "b" => 2)

result["a"]  # => 1
```

### Symbol Keys

```julia
result = nickel_eval("{ x = 1.5, y = 2.5 }", Dict{Symbol, Float64})
# => Dict{Symbol, Float64}(:x => 1.5, :y => 2.5)

result[:x]  # => 1.5
```

## Typed Arrays

```julia
nickel_eval("[1, 2, 3]", Vector{Int})
# => [1, 2, 3]

nickel_eval("[\"a\", \"b\", \"c\"]", Vector{String})
# => ["a", "b", "c"]
```

## NamedTuples

For structured configuration access:

```julia
config = nickel_eval("""
{
  host = "localhost",
  port = 8080,
  debug = true
}
""", @NamedTuple{host::String, port::Int, debug::Bool})

# => (host = "localhost", port = 8080, debug = true)

config.host   # => "localhost"
config.port   # => 8080
config.debug  # => true
```

## Custom Structs

Define your own types:

```julia
struct ServerConfig
    host::String
    port::Int
    workers::Int
end

config = nickel_eval("""
{
  host = "0.0.0.0",
  port = 3000,
  workers = 4
}
""", ServerConfig)

# => ServerConfig("0.0.0.0", 3000, 4)
```

## File Evaluation with Types

```julia
# config.ncl:
# { environment = "production", max_connections = 100 }

Config = @NamedTuple{environment::String, max_connections::Int}
config = nickel_eval_file("config.ncl", Config)

config.environment      # => "production"
config.max_connections  # => 100
```

## The `nickel_read` Alias

`nickel_read` is an alias for typed `nickel_eval`:

```julia
nickel_read("{ a = 1 }", Dict{String, Int})
# equivalent to
nickel_eval("{ a = 1 }", Dict{String, Int})
```
