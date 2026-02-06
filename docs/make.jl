#!/usr/bin/env julia

using NickelEval
using Documenter
using DocumenterVitepress

makedocs(
    format = MarkdownVitepress(
        repo = "https://github.com/LouLouLibs/NickelEval",
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
    target = "build",  # this is where Vitepress stores its output
    devbranch = "main",
    branch = "gh-pages",
    push_preview = true,
)
