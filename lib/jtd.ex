defmodule JTD do
  @moduledoc """
  An Elixir implementation of JSON Type Definition validation
  """

  defdelegate validate(schema, instance, options), to: JTD.Validator
end
