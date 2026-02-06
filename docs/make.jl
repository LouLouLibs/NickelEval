#!/usr/bin/env julia

using NickelEval
using Documenter

makedocs(
    format = Documenter.HTML(
        prettyurls = get(ENV, "CI", nothing) == "true",
        canonical = "https://louloulibs.github.io/NickelEval",
    ),
    repo = Remotes.GitHub("LouLouLibs", "NickelEval"),
    sitename = "NickelEval.jl",
    modules  = [NickelEval],
    authors = "LouLouLibs Contributors",
    pages = [
        "Home" => "index.md",
        "Manual" => [
            "man/quickstart.md",
            "man/typed.md",
            "man/export.md",
            "man/ffi.md",
        ],
        "Library" => [
            "lib/public.md",
        ]
    ]
)

deploydocs(;
    repo = "github.com/LouLouLibs/NickelEval",
    devbranch = "main",
    push_preview = true,
)
