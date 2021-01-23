defmodule JTD.ValidationError do
  @moduledoc """
  ValidationError object which has instance path and schema path.
  """

  @type t :: %__MODULE__{instance_path: [...], schema_path: [...]}

  defstruct instance_path: [], schema_path: []

  @doc """
  Returns JTD.ValidationError struct generated from given map. This is for testing purposes only.
  """
  def from_map(%{ "instancePath" => instance_path, "schemaPath" => schema_path }) do
    %__MODULE__{instance_path: instance_path, schema_path: schema_path}
  end
  def from_map(%{ instancePath: instance_path, schemaPath: schema_path }) do
    %__MODULE__{instance_path: instance_path, schema_path: schema_path}
  end
end

defmodule JTD.MaxErrorsReachedError do
  @moduledoc """
  Exception that occurs when the option is given and the maximum number of errors has been reached.
  """

  @type t :: %__MODULE__{message: String.t(), state: any}

  defexception message: nil, state: nil
end

defmodule JTD.MaxDepthExceededError do
  @moduledoc """
  Exception that occurs when the option is given and map reaches the maximum depth.
  """
  @type t :: %__MODULE__{message: String.t()}

  defexception message: nil
end

defmodule JTD.ValidationState do
  @moduledoc false

  alias JTD.{ValidationError, MaxErrorsReachedError}

  defstruct [:options, :root_schema, :instance_tokens, :schema_tokens, :errors]

  def push_schema_token_stack(state, token) do
    Map.update(state, :schema_tokens, [[]], fn current -> [token] ++ current end)
  end

  def pop_schema_token_stack(state) do
    Map.update(state, :schema_tokens, [[]], fn current -> current |> List.pop_at(0) |> elem(1) end)
  end

  def push_schema_token(state, token) do
    pushed = [token | List.first(state.schema_tokens)]
    Map.update(state, :schema_tokens, [[]], fn current -> current |> List.replace_at(0, pushed) end)
  end

  def pop_schema_token(state) do
    popped = state |> Map.get(:schema_tokens) |> List.first |> List.pop_at(0) |> elem(1)
    Map.update(state, :schema_tokens, [[]], fn current -> current |> List.replace_at(0, popped) end)
  end

  def push_instance_token(state, token) do
    pushed = [token | state.instance_tokens]
    Map.update(state, :instance_tokens, [], fn _ -> pushed end)
  end

  def pop_instance_token(state) do
    popped = state |> Map.get(:instance_tokens) |> List.pop_at(0) |> elem(1)
    Map.update(state, :instance_tokens, [], fn _ -> popped end)
  end

  def push_error(state) do
    error = %ValidationError{instance_path: state.instance_tokens |> Enum.reverse, schema_path: state.schema_tokens |> List.first |> Enum.reverse}
    state = Map.update(state, :errors, [], fn current -> [error] ++ (current |> Enum.reverse) |> Enum.reverse end)

    if length(state.errors) == state.options.max_errors do
      raise MaxErrorsReachedError, message: nil, state: state
    end

    state
  end
end

defmodule JTD.ValidationOptions do
  @moduledoc """
  Options for validation.
  """

  @type t :: %__MODULE__{max_depth: integer, max_errors: integer}

  defstruct max_depth: 0, max_errors: 0
end

defmodule JTD.Validator do
  @moduledoc """
  JSON Typedef validator.
  """

  alias JTD.{MaxDepthExceededError, MaxErrorsReachedError}

  @doc """
  Perform validation to given instance.
  """

  @spec validate(JTD.Schema.t(), Map.t(), JTD.ValidationOptions.t()) :: [JTD.ValidationError.t()]
  def validate(schema, instance, options) do
    state = %JTD.ValidationState{
      options: options,
      root_schema: schema,
      instance_tokens: [],
      schema_tokens: [[]],
      errors: [],
    }

    try do
      validate_with_state(state, schema, instance) |> Map.get(:errors)
    rescue
      # This is just a dummy error to immediately stop validation. We swallow
      # the error here, and return the abridged set of errors.
      e in MaxErrorsReachedError -> e.state |> Map.get(:errors)
    end
  end

  defp validate_with_state(state, schema, instance, parent_tag \\ nil)
  defp validate_with_state(state, schema, instance, _) when schema.nullable and is_nil(instance), do: state
  defp validate_with_state(state, schema, instance, parent_tag) do
    JTD.Schema.form(schema)
    |> validate_form(state, schema, instance, parent_tag)
  end

  defp validate_form(:empty, state, _, _, _), do: state

  defp validate_form(:ref, state, _, _, _) when length(state.schema_tokens) == state.options.max_depth do
    raise MaxDepthExceededError, message: "max depth exceeded during JTD.validate/3"
  end
  defp validate_form(:ref, state, schema, instance, _) do
    state
    |> JTD.ValidationState.push_schema_token_stack([schema.ref, "definitions"])
    |> validate_with_state(state.root_schema.definitions[schema.ref], instance)
    |> JTD.ValidationState.pop_schema_token_stack
  end

  defp validate_form(:type, state, schema, instance, _) do
    state = JTD.ValidationState.push_schema_token(state, "type")

    schema
    |> Map.get(:type)
    |> String.to_atom
    |> do_validate_type(state, instance, schema.nullable)
    |> JTD.ValidationState.pop_schema_token
  end

  defp do_validate_type(_, state, nil, true), do: state
  defp do_validate_type(:boolean, state, instance, _) when is_boolean(instance), do: state
  defp do_validate_type(:float32, state, instance, _) when is_number(instance), do: state
  defp do_validate_type(:float64, state, instance, _) when is_number(instance), do: state
  defp do_validate_type(:int8, state, instance, _) when is_integer(instance) and (instance >= -128) and (instance <= 127), do: state
  defp do_validate_type(:uint8, state, instance, _) when is_integer(instance) and (instance >= 0) and (instance <= 255), do: state
  defp do_validate_type(:int16, state, instance, _) when is_integer(instance) and (instance >= -32_768) and (instance <= 32_767), do: state
  defp do_validate_type(:uint16, state, instance, _) when is_integer(instance) and (instance >= 0) and (instance <= 65_535), do: state
  defp do_validate_type(:int32, state, instance, _) when is_integer(instance) and (instance >= -2_147_483_648) and (instance <= 2_147_483_647), do: state
  defp do_validate_type(:uint32, state, instance, _) when is_integer(instance) and (instance >= 0) and (instance <= 4_294_967_295), do: state
  defp do_validate_type(:string, state, instance, _) when is_binary(instance), do: state
  defp do_validate_type(:timestamp, state, instance, _) when is_binary(instance) do
    case DateTime.from_iso8601(instance) do
      {:ok, _, _} -> state
      {:error, _} -> JTD.ValidationState.push_error(state)
    end
  end
  defp do_validate_type(_, state, _, _), do: JTD.ValidationState.push_error(state)

  defp validate_form(:enum, state, schema, instance, _) do
    state = JTD.ValidationState.push_schema_token(state, "enum")

    state = schema.enum
    |> Enum.member?(instance)
    |> unless do
      JTD.ValidationState.push_error(state)
    else
      state
    end

    JTD.ValidationState.pop_schema_token(state)
  end

  defp validate_form(:elements, state, schema, instance, _) when is_list(instance) do
    state = JTD.ValidationState.push_schema_token(state, "elements")

    instance
    |> Enum.with_index
    |> Enum.reduce(state, fn {element, index}, s -> do_validate_element(s, schema, element, index) end)
    |> JTD.ValidationState.pop_schema_token
  end
  defp validate_form(:elements, state, _, _, _) do
    state
    |> JTD.ValidationState.push_schema_token("elements")
    |> JTD.ValidationState.push_error
    |> JTD.ValidationState.pop_schema_token
  end

  defp do_validate_element(state, schema, sub_instance, index) do
    state
    |> JTD.ValidationState.push_instance_token(Integer.to_string(index))
    |> validate_with_state(schema.elements, sub_instance)
    |> JTD.ValidationState.pop_instance_token
  end

  defp validate_form(:properties, state, %{properties: properties}, instance, _) when not is_map(instance) do
    case properties do
      nil -> JTD.ValidationState.push_schema_token(state, "optionalProperties")
      _properties -> JTD.ValidationState.push_schema_token(state, "properties")
    end
    |> JTD.ValidationState.push_error
    |> JTD.ValidationState.pop_schema_token
  end
  defp validate_form(:properties, state, schema, instance, parent_tag) do
    state
    |> do_validate_properties(schema.properties, instance)
    |> do_validate_optional_properties(schema.optional_properties, instance)
    |> do_validate_additional_properties(schema, instance, parent_tag)
  end

  defp do_validate_properties(state, nil, _), do: state
  defp do_validate_properties(state, properties, instance) do
    state = JTD.ValidationState.push_schema_token(state, "properties")

    properties
    |> Enum.reduce(state, fn {property, sub_schema}, s ->
      state = JTD.ValidationState.push_schema_token(s, property)

      if is_map_key(instance, property) do
        state
        |> JTD.ValidationState.push_instance_token(property)
        |> validate_with_state(sub_schema, instance[property])
        |> JTD.ValidationState.pop_instance_token
      else
        state
        |> JTD.ValidationState.push_error
      end
      |> JTD.ValidationState.pop_schema_token
    end)
    |> JTD.ValidationState.pop_schema_token
  end

  defp do_validate_optional_properties(state, nil, _), do: state
  defp do_validate_optional_properties(state, optional_properties, instance) do
    state = JTD.ValidationState.push_schema_token(state, "optionalProperties")

    optional_properties
    |> Enum.reduce(state, fn {property, sub_schema}, s ->
      state = JTD.ValidationState.push_schema_token(s, property)

      if is_map_key(instance, property) do
        state
        |> JTD.ValidationState.push_instance_token(property)
        |> validate_with_state(sub_schema, instance[property])
        |> JTD.ValidationState.pop_instance_token
      else
        state
      end
      |> JTD.ValidationState.pop_schema_token
    end)
    |> JTD.ValidationState.pop_schema_token
  end

  defp do_validate_additional_properties(state, %{additional_properties: true}, _, _), do: state
  defp do_validate_additional_properties(state, schema, instance, parent_tag) do
    properties = (schema.properties || %{}) |> Map.keys
    optional_properties = (schema.optional_properties || %{}) |> Map.keys
    instance_keys = instance |> Map.keys
    parent_tags = [parent_tag]

    instance_keys
    |> Kernel.--(properties)
    |> Kernel.--(optional_properties)
    |> Kernel.--(parent_tags)
    |> Enum.reduce(state, fn property, s ->
      s
      |> JTD.ValidationState.push_instance_token(property)
      |> JTD.ValidationState.push_error
      |> JTD.ValidationState.pop_instance_token
    end)
  end

  defp validate_form(:values, state, schema, instance, _) when is_map(instance) do
    state = JTD.ValidationState.push_schema_token(state, "values")

    instance
    |> Enum.reduce(state, fn {property, sub_instance}, s ->
      s
      |> JTD.ValidationState.push_instance_token(property)
      |> validate_with_state(schema.values, sub_instance)
      |> JTD.ValidationState.pop_instance_token
    end)
    |> JTD.ValidationState.pop_schema_token
  end
  defp validate_form(:values, state, _, _, _) do
    state
    |> JTD.ValidationState.push_schema_token("values")
    |> JTD.ValidationState.push_error
    |> JTD.ValidationState.pop_schema_token
  end

  defp validate_form(:discriminator, state, schema, instance, _) when is_map(instance) do
    do_validate_form(state, schema, instance, instance[schema.discriminator])
  end
  defp validate_form(:discriminator, state, _, _, _) do
    state
    |> JTD.ValidationState.push_schema_token("discriminator")
    |> JTD.ValidationState.push_error
    |> JTD.ValidationState.pop_schema_token
  end

  defp do_validate_form(state, schema, instance, _) when (not is_map(instance)) or (not is_map_key(instance, schema.discriminator)) do
    state
    |> JTD.ValidationState.push_schema_token("discriminator")
    |> JTD.ValidationState.push_error
    |> JTD.ValidationState.pop_schema_token
  end
  defp do_validate_form(state, schema, _, instance_discriminator) when not is_binary(instance_discriminator) do
    state
    |> JTD.ValidationState.push_schema_token("discriminator")
    |> JTD.ValidationState.push_instance_token(schema.discriminator)
    |> JTD.ValidationState.push_error
    |> JTD.ValidationState.pop_instance_token
    |> JTD.ValidationState.pop_schema_token
  end
  defp do_validate_form(state, schema, _, instance_discriminator) when not is_map_key(schema.mapping, instance_discriminator) do
    state
    |> JTD.ValidationState.push_schema_token("mapping")
    |> JTD.ValidationState.push_instance_token(schema.discriminator)
    |> JTD.ValidationState.push_error
    |> JTD.ValidationState.pop_instance_token
    |> JTD.ValidationState.pop_schema_token
  end
  defp do_validate_form(state, schema, instance, instance_discriminator) do
    sub_schema = schema.mapping[instance_discriminator]

    state
    |> JTD.ValidationState.push_schema_token("mapping")
    |> JTD.ValidationState.push_schema_token(instance_discriminator)
    |> validate_with_state(sub_schema, instance, schema.discriminator)
    |> JTD.ValidationState.pop_schema_token
    |> JTD.ValidationState.pop_schema_token
  end
end
