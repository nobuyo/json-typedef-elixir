defmodule JTD do
  @moduledoc """
  Elixir implementation of JSON Type Definition validation
  """

  defdelegate validate(schema, instance, options \\ %JTD.ValidationOptions{}), to: JTD.Validator
end
