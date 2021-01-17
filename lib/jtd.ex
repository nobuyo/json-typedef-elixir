defmodule JTD do
  @moduledoc """
  An Elixir implementation of JSON Type Definition validation
  """

  def validate do
    JTD.Validator.validate
  end
end
