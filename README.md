# jtd: JSON Validation for Elixir

An Implementation of [JSON Type Definition](https://jsontypedef.com/) in Elixir.

## Installation

The package can be installed by adding to your list of dependencies in mix.exs:

```elixir
  def deps do
    [{:jtd, "~> 0.1"}]
  end
```

## Basic Usage

```elixir
schema = JTD.Schema.from_map(
  %{
    "properties" => %{
      "name" => %{"type" => "string"},
      "age" => %{"type" => "uint32"},
      "phones" => %{
        "elements" => %{
          "type" => "string"
        }
      }
    }
  }
)

JTD.validate(schema, %{
  "name" => "John Doe",
  "age" => 43,
  "phones" => ["+44 1234567", "+44 2345678"],
})
# Output: []

JTD.validate(schema, %{
  "age" => "43",
  "phones" => ["+44 1234567", 442345678],
})
# Output:
# [
#   %JTD.ValidationError{
#     instance_path: ["age"],
#     schema_path: ["properties", "age", "type"]
#   },
#   %JTD.ValidationError{instance_path: [], schema_path: ["properties", "name"]},
#   %JTD.ValidationError{
#     instance_path: ["phones", "1"],
#     schema_path: ["properties", "phones", "elements", "type"]
#   }
# ]
```

## Links

- [Package on Hex](https://hex.pm/packages/jtd)
