@testset "FFI Native Evaluation" begin
    @testset "Primitive types" begin
        # Integers
        @test nickel_eval_native("42") === Int64(42)
        @test nickel_eval_native("-42") === Int64(-42)
        @test nickel_eval_native("0") === Int64(0)
        @test nickel_eval_native("1000000000000") === Int64(1000000000000)

        # Floats (only true decimals)
        @test nickel_eval_native("3.14") ≈ 3.14
        @test nickel_eval_native("-2.718") ≈ -2.718
        @test nickel_eval_native("0.5") ≈ 0.5
        @test typeof(nickel_eval_native("3.14")) == Float64

        # Booleans
        @test nickel_eval_native("true") === true
        @test nickel_eval_native("false") === false

        # Null
        @test nickel_eval_native("null") === nothing

        # Strings
        @test nickel_eval_native("\"hello\"") == "hello"
        @test nickel_eval_native("\"\"") == ""
        @test nickel_eval_native("\"hello 世界\"") == "hello 世界"
    end

    @testset "Arrays" begin
        @test nickel_eval_native("[]") == Any[]
        @test nickel_eval_native("[1, 2, 3]") == Any[1, 2, 3]
        @test nickel_eval_native("[true, false]") == Any[true, false]
        @test nickel_eval_native("[\"a\", \"b\"]") == Any["a", "b"]

        # Nested arrays
        result = nickel_eval_native("[[1, 2], [3, 4]]")
        @test result == Any[Any[1, 2], Any[3, 4]]

        # Mixed types
        result = nickel_eval_native("[1, \"two\", true, null]")
        @test result == Any[1, "two", true, nothing]
    end

    @testset "Records" begin
        result = nickel_eval_native("{ x = 1 }")
        @test result isa Dict{String, Any}
        @test result["x"] === Int64(1)

        result = nickel_eval_native("{ name = \"test\", count = 42 }")
        @test result["name"] == "test"
        @test result["count"] === Int64(42)

        # Empty record
        @test nickel_eval_native("{}") == Dict{String, Any}()

        # Nested records
        result = nickel_eval_native("{ outer = { inner = 42 } }")
        @test result["outer"]["inner"] === Int64(42)
    end

    @testset "Type preservation" begin
        # The key feature: integers stay Int64, floats stay Float64
        @test typeof(nickel_eval_native("42")) == Int64
        @test typeof(nickel_eval_native("42.5")) == Float64
        @test typeof(nickel_eval_native("42.0")) == Int64  # whole numbers → Int64
    end

    @testset "Computed values" begin
        @test nickel_eval_native("1 + 2") === Int64(3)
        @test nickel_eval_native("10 - 3") === Int64(7)
        @test nickel_eval_native("let x = 10 in x * 2") === Int64(20)
        @test nickel_eval_native("let add = fun x y => x + y in add 3 4") === Int64(7)
    end

    @testset "Record operations" begin
        # Merge
        result = nickel_eval_native("{ a = 1 } & { b = 2 }")
        @test result["a"] === Int64(1)
        @test result["b"] === Int64(2)
    end

    @testset "Array operations" begin
        result = nickel_eval_native("[1, 2, 3] |> std.array.map (fun x => x * 2)")
        @test result == Any[2, 4, 6]
    end

    @testset "Enums" begin
        # Simple enum (no argument)
        result = nickel_eval_native("let x = 'Foo in x")
        @test result isa Dict{String, Any}
        @test result["_tag"] == "Foo"
        @test !haskey(result, "_value")

        # Enum with integer argument
        result = nickel_eval_native("let x = 'Some 42 in x")
        @test result["_tag"] == "Some"
        @test result["_value"] === Int64(42)

        # Enum with record argument
        result = nickel_eval_native("let x = 'Ok { value = 123 } in x")
        @test result["_tag"] == "Ok"
        @test result["_value"]["value"] === Int64(123)

        # Match expression
        result = nickel_eval_native("let x = 'Success 42 in x |> match { 'Success v => v, 'Failure _ => 0 }")
        @test result === Int64(42)
    end

    @testset "Deeply nested structures" begin
        # Deep nesting
        result = nickel_eval_native("{ a = { b = { c = { d = 42 } } } }")
        @test result["a"]["b"]["c"]["d"] === Int64(42)

        # Array of records
        result = nickel_eval_native("[{ x = 1 }, { x = 2 }, { x = 3 }]")
        @test length(result) == 3
        @test result[1]["x"] === Int64(1)
        @test result[3]["x"] === Int64(3)

        # Records containing arrays
        result = nickel_eval_native("{ items = [1, 2, 3], name = \"test\" }")
        @test result["items"] == Any[1, 2, 3]
        @test result["name"] == "test"

        # Mixed deep nesting
        result = nickel_eval_native("{ data = [{ a = 1 }, { b = [true, false] }] }")
        @test result["data"][1]["a"] === Int64(1)
        @test result["data"][2]["b"] == Any[true, false]
    end
end

@testset "FFI JSON Evaluation" begin
    # Test the JSON path still works
    @test nickel_eval_ffi("42") == 42
    @test nickel_eval_ffi("\"hello\"") == "hello"
    @test nickel_eval_ffi("{ x = 1 }").x == 1

    # Typed evaluation
    result = nickel_eval_ffi("{ x = 1, y = 2 }", Dict{String, Int})
    @test result isa Dict{String, Int}
    @test result["x"] == 1
end
