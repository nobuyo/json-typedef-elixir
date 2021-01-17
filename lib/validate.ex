defmodule JTD.ValidationError do
  @moduledoc false

  defstruct instance_path: [], schema_path: []
end

defmodule JTD.ValidationState do
  @moduledoc false

  defstruct [:options, :root_schema, :instance_tokens, :schema_tokens, :errors]
end

defmodule JTD.Validator do
  def validate do
    # todo
    IO.puts "not implemented"
  end
end
