defmodule ValidateTest do
  use ExUnit.Case

  ExUnit.Case.register_attribute(__MODULE__, :fixtures, accumulate: true)

  @skipped_tests [
    # DateTime.from_iso8601 does not supports this format
    "timestamp type schema - 1990-12-31T23:59:60Z",
    "timestamp type schema - 1990-12-31T15:59:60-08:00",
    # Elixir's Map is supporting no any ordering of keys
    "values schema - all values bad"
  ]

  describe "validate" do
    test "max depth" do
      schema = JTD.Schema.from_map(%{
        definitions: %{"loop" => %{ref: "loop"}},
        ref: "loop",
      })
      |> JTD.Schema.verify

      assert_raise JTD.MaxDepthExceededError, fn -> JTD.validate(schema, nil, %JTD.ValidationOptions{max_depth: 32}) end
    end

    test "supports max errors" do
      schema = JTD.Schema.from_map(%{
        elements: %{ type: "string" }
      })
      |> JTD.Schema.verify

      options = %JTD.ValidationOptions{max_errors: 3}
      errors_size = schema|> JTD.validate([nil, nil, nil, nil], options) |> length

      assert(errors_size == 3)
    end
  end

  describe "validate: spec tests" do
    {:ok, test_cases} = File.read("json-typedef-spec/tests/validation.json")
    {:ok, test_cases} = Jason.decode(test_cases)

    test_cases
    |> Enum.each(fn {name, test_case} ->
      @fixtures test_case
      unless name in @skipped_tests do
        test name, context do
          %{ "schema" => case_schema, "instance" => case_instance, "errors" => case_errors } = context.registered.fixtures |> List.first
          schema = JTD.Schema.from_map(case_schema) |> JTD.Schema.verify
          instance = case_instance
          expected_errors = (case_errors || []) |> Enum.map(fn e -> JTD.ValidationError.from_map(e) end)

          actual_errors = JTD.validate(schema, instance)
          assert(actual_errors == expected_errors)
        end
      end
    end)
  end
end
