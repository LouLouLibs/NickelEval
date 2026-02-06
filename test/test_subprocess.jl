@testset "Subprocess Evaluation" begin
    @testset "Basic expressions" begin
        @test nickel_eval("1 + 2") == 3
        @test nickel_eval("10 - 3") == 7
        @test nickel_eval("4 * 5") == 20
        @test nickel_eval("true") == true
        @test nickel_eval("false") == false
        @test nickel_eval("\"hello\"") == "hello"
    end

    @testset "Let expressions" begin
        @test nickel_eval("let x = 1 in x + 2") == 3
        @test nickel_eval("let x = 5 in x * 2") == 10
        @test nickel_eval("let x = 1 in let y = 2 in x + y") == 3
    end

    @testset "Records (Objects)" begin
        result = nickel_eval("{ a = 1, b = 2 }")
        @test result.a == 1
        @test result.b == 2

        result = nickel_eval("{ name = \"test\", value = 42 }")
        @test result.name == "test"
        @test result.value == 42
    end

    @testset "Arrays" begin
        @test nickel_eval("[1, 2, 3]") == [1, 2, 3]
        @test nickel_eval("[\"a\", \"b\"]") == ["a", "b"]
        @test nickel_eval("[]") == []
    end

    @testset "Nested structures" begin
        result = nickel_eval("{ outer = { inner = 42 } }")
        @test result.outer.inner == 42

        result = nickel_eval("{ items = [1, 2, 3] }")
        @test result.items == [1, 2, 3]
    end

    @testset "String macro" begin
        @test ncl"1 + 1" == 2
        @test ncl"{ x = 10 }".x == 10
    end

    @testset "File evaluation" begin
        fixture_path = joinpath(@__DIR__, "fixtures", "simple.ncl")
        result = nickel_eval_file(fixture_path)
        @test result.name == "test"
        @test result.value == 42
        @test result.computed == 84
    end

    @testset "Export formats" begin
        # JSON
        json_output = nickel_export("{ a = 1 }"; format=:json)
        @test occursin("\"a\"", json_output)
        @test occursin("1", json_output)

        # TOML
        toml_output = nickel_export("{ a = 1 }"; format=:toml)
        @test occursin("a", toml_output)
        @test occursin("1", toml_output)

        # YAML
        yaml_output = nickel_export("{ a = 1, b = \"hello\" }"; format=:yaml)
        @test occursin("a:", yaml_output) || occursin("a :", yaml_output)
    end

    @testset "Error handling" begin
        @test_throws NickelError nickel_eval("undefined_variable")
        @test_throws NickelError nickel_eval_file("/nonexistent/path.ncl")
        @test_throws NickelError nickel_export("1"; format=:invalid)
    end

    @testset "Typed evaluation - primitives" begin
        @test nickel_eval("42", Int) === 42
        @test nickel_eval("3.14", Float64) === 3.14
        @test nickel_eval("\"hello\"", String) == "hello"
        @test nickel_eval("true", Bool) === true
    end

    @testset "Typed evaluation - Dict{String, V}" begin
        result = nickel_eval("{ a = 1, b = 2 }", Dict{String, Int})
        @test result isa Dict{String, Int}
        @test result["a"] === 1
        @test result["b"] === 2
    end

    @testset "Typed evaluation - Dict{Symbol, V}" begin
        result = nickel_eval("{ x = 1.5, y = 2.5 }", Dict{Symbol, Float64})
        @test result isa Dict{Symbol, Float64}
        @test result[:x] === 1.5
        @test result[:y] === 2.5
    end

    @testset "Typed evaluation - Vector{T}" begin
        result = nickel_eval("[1, 2, 3]", Vector{Int})
        @test result isa Vector{Int}
        @test result == [1, 2, 3]

        result = nickel_eval("[\"a\", \"b\", \"c\"]", Vector{String})
        @test result isa Vector{String}
        @test result == ["a", "b", "c"]
    end

    @testset "Typed evaluation - NamedTuple" begin
        result = nickel_eval("{ host = \"localhost\", port = 8080 }",
                             @NamedTuple{host::String, port::Int})
        @test result isa NamedTuple{(:host, :port), Tuple{String, Int}}
        @test result.host == "localhost"
        @test result.port === 8080
    end

    @testset "Typed file evaluation" begin
        fixture_path = joinpath(@__DIR__, "fixtures", "simple.ncl")
        result = nickel_eval_file(fixture_path, @NamedTuple{name::String, value::Int, computed::Int})
        @test result.name == "test"
        @test result.value === 42
        @test result.computed === 84
    end

    @testset "nickel_read alias" begin
        result = nickel_read("{ a = 1 }", Dict{String, Int})
        @test result isa Dict{String, Int}
        @test result["a"] === 1
    end
end
