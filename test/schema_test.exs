defmodule SchemaTest do
  use ExUnit.Case

  ExUnit.Case.register_attribute(__MODULE__, :fixtures, accumulate: true)

  describe "JTD.Schema" do
    {:ok, test_cases} = File.read("json-typedef-spec/tests/invalid_schemas.json")
    {:ok, test_cases} = Jason.decode(test_cases)

    test_cases
    |> Enum.each(fn {name, test_case} ->
      @fixtures test_case
      test name, context do
        schema = context.registered.fixtures |> List.first

        has_error = try do
          JTD.Schema.from_map(schema) |> JTD.Schema.verify
          false
        rescue
          ArgumentError -> true
          JTD.TypeError -> true
          Protocol.UndefinedError -> true
          BadMapError -> true
        end

        assert(has_error == true)
      end
    end)
  end
end
