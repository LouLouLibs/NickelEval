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
        @test result["a"] == 1
        @test result["b"] == 2

        result = nickel_eval("{ name = \"test\", value = 42 }")
        @test result["name"] == "test"
        @test result["value"] == 42
    end

    @testset "Arrays" begin
        @test nickel_eval("[1, 2, 3]") == [1, 2, 3]
        @test nickel_eval("[\"a\", \"b\"]") == ["a", "b"]
        @test nickel_eval("[]") == []
    end

    @testset "Nested structures" begin
        result = nickel_eval("{ outer = { inner = 42 } }")
        @test result["outer"]["inner"] == 42

        result = nickel_eval("{ items = [1, 2, 3] }")
        @test result["items"] == [1, 2, 3]
    end

    @testset "String macro" begin
        @test ncl"1 + 1" == 2
        @test ncl"{ x = 10 }"["x"] == 10
    end

    @testset "File evaluation" begin
        fixture_path = joinpath(@__DIR__, "fixtures", "simple.ncl")
        result = nickel_eval_file(fixture_path)
        @test result["name"] == "test"
        @test result["value"] == 42
        @test result["computed"] == 84
    end

    @testset "Export formats" begin
        json_output = nickel_export("{ a = 1 }"; format=:json)
        @test occursin("\"a\"", json_output)
        @test occursin("1", json_output)
    end

    @testset "Error handling" begin
        @test_throws NickelError nickel_eval("undefined_variable")
        @test_throws NickelError nickel_eval_file("/nonexistent/path.ncl")
        @test_throws NickelError nickel_export("1"; format=:invalid)
    end
end
