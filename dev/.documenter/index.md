
# NickelEval.jl {#NickelEval.jl}

Julia bindings for the [Nickel](https://nickel-lang.org/) configuration language.

## Features {#Features}
- **Evaluate Nickel code** directly from Julia
  
- **Native type conversion** to Julia types (`Dict`, `NamedTuple`, custom structs)
  
- **Export to multiple formats** (JSON, TOML, YAML)
  
- **High-performance FFI** mode using Rust bindings
  
- **Dot-access** for configuration records via `JSON.Object`
  

## Installation {#Installation}

### From LouLouLibs Registry (Recommended) {#From-LouLouLibs-Registry-Recommended}

```julia
using Pkg
Pkg.Registry.add(url="https://github.com/LouLouLibs/loulouJL")
Pkg.add("NickelEval")
```


### From GitHub URL {#From-GitHub-URL}

```julia
using Pkg
Pkg.add(url="https://github.com/LouLouLibs/NickelEval")
```


**Prerequisite:** Install the Nickel CLI from [nickel-lang.org](https://nickel-lang.org/)

## Quick Example {#Quick-Example}

```julia
using NickelEval

# Simple evaluation
nickel_eval("1 + 2")  # => 3

# Records with dot-access
config = nickel_eval("{ host = \"localhost\", port = 8080 }")
config.host  # => "localhost"
config.port  # => 8080

# Typed evaluation
nickel_eval("{ x = 1, y = 2 }", Dict{String, Int})
# => Dict{String, Int64}("x" => 1, "y" => 2)

# Export to TOML
nickel_to_toml("{ name = \"myapp\", version = \"1.0\" }")
# => "name = \"myapp\"\nversion = \"1.0\"\n"
```


## Why Nickel? {#Why-Nickel?}

[Nickel](https://nickel-lang.org/) is a configuration language designed to be:
- **Programmable**: Functions, let bindings, and standard library
  
- **Typed**: Optional contracts for validation
  
- **Mergeable**: Combine configurations with `&`
  
- **Safe**: No side effects, pure functional
  

NickelEval.jl lets you leverage Nickel&#39;s power directly in your Julia workflows.

## Contents {#Contents}
- [Quick Start](man/quickstart#Quick-Start)
    - [Installation](man/quickstart#installation)
    - [Basic Usage](man/quickstart#Basic-Usage)
    - [Working with Records](man/quickstart#Working-with-Records)
    - [Let Bindings and Functions](man/quickstart#Let-Bindings-and-Functions)
    - [Arrays](man/quickstart#arrays)
    - [Record Merge](man/quickstart#Record-Merge)
    - [String Macro](man/quickstart#String-Macro)
    - [File Evaluation](man/quickstart#File-Evaluation)
    - [Error Handling](man/quickstart#Error-Handling)
- [Typed Evaluation](man/typed#Typed-Evaluation)
    - [Basic Types](man/typed#Basic-Types)
    - [Typed Dictionaries](man/typed#Typed-Dictionaries)
    - [Typed Arrays](man/typed#Typed-Arrays)
    - [NamedTuples](man/typed#namedtuples)
    - [Custom Structs](man/typed#Custom-Structs)
    - [File Evaluation with Types](man/typed#File-Evaluation-with-Types)
    - [The nickel_read Alias](man/typed#The-nickel_read-Alias)
- [Export to Config Formats](man/export#Export-to-Config-Formats)
    - [JSON Export](man/export#JSON-Export)
    - [TOML Export](man/export#TOML-Export)
    - [YAML Export](man/export#YAML-Export)
    - [Generic Export Function](man/export#Generic-Export-Function)
    - [Generating Config Files](man/export#Generating-Config-Files)
    - [Nested Structures](man/export#Nested-Structures)
- [FFI Mode (High Performance)](man/ffi#FFI-Mode-(High-Performance))
    - [Checking FFI Availability](man/ffi#Checking-FFI-Availability)
    - [Using FFI Evaluation](man/ffi#Using-FFI-Evaluation)
    - [Building the FFI Library](man/ffi#Building-the-FFI-Library)
    - [Performance Comparison](man/ffi#Performance-Comparison)
    - [Binary Protocol](man/ffi#Binary-Protocol)
    - [Fallback Behavior](man/ffi#Fallback-Behavior)
    - [Troubleshooting](man/ffi#troubleshooting)
- [Public API](lib/public#Public-API)
    - [Evaluation Functions](lib/public#Evaluation-Functions)
    - [Export Functions](lib/public#Export-Functions)
    - [FFI Functions](lib/public#FFI-Functions)
    - [String Macro](lib/public#String-Macro)

