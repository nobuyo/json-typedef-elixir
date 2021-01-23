defmodule JTD.TypeError do
  @type t :: %__MODULE__{message: String.t()}

  defexception message: nil

  def message(%{message: message}) do
    message
  end
end

defmodule JTD.Schema do
  @moduledoc """
    Module to convert Map to JSON Type Definition schema struct.
  """

  alias JTD.TypeError

  @keywords [
    :metadata,
    :nullable,
    :definitions,
    :ref,
    :type,
    :enum,
    :elements,
    :properties,
    :optionalProperties,
    :additionalProperties,
    :values,
    :discriminator,
    :mapping
  ]

  @types [
    "boolean",
    "int8",
    "uint8",
    "int16",
    "uint16",
    "int32",
    "uint32",
    "float32",
    "float64",
    "string",
    "timestamp"
  ]

  @forms [
    :ref,
    :type,
    :enum,
    :elements,
    :properties,
    :optional_properties,
    :additional_properties,
    :values,
    :discriminator,
    :mapping
  ]

  @valid_forms [
    # Empty form
    [],
    # Ref form
    [:ref],
    # Type form
    [:type],
    # Enum form
    [:enum],
    # Elements form
    [:elements],
    # Properties form -- properties or optional properties or both, and
    # never additional properties on its own
    [:properties],
    [:optional_properties],
    [:properties, :optional_properties],
    [:properties, :additional_properties],
    [:optional_properties, :additional_properties],
    [:properties, :optional_properties, :additional_properties],
    # Values form
    [:values],
    # Discriminator form
    [:discriminator, :mapping]
  ]

  defstruct [
    :metadata,
    :nullable,
    :definitions,
    :ref,
    :type,
    :enum,
    :elements,
    :properties,
    :optional_properties,
    :additional_properties,
    :values,
    :discriminator,
    :mapping
  ]

  @type t :: %__MODULE__{
    metadata: any,
    nullable: any,
    definitions: any,
    ref: any,
    type: any,
    enum: any,
    elements: any,
    properties: any,
    optional_properties: any,
    additional_properties: any,
    values: any,
    discriminator: any,
    mapping: any
  }

  @doc """
  Convert given map to JTD.Schema.
  """

  @spec from_map(map) :: JTD.Schema.t()
  def from_map(map) when is_map(map) do
    map
    |> check_keywords!

    {map, %{}}
    |> atomize_keys
    |> parse_metadata
    |> parse_nullable
    |> parse_definitions
    |> parse_ref
    |> parse_type
    |> parse_enum
    |> parse_elements
    |> parse_properties
    |> parse_optional_properties
    |> parse_additional_properties
    |> parse_values
    |> parse_discriminator
    |> parse_mapping
    |> to_schema
  end

  def from_map(others) do
    raise TypeError, message: "expected map, got: #{inspect(others)}"
  end

  @doc """
  Verify converted schema.
  """

  @spec verify(JTD.Schema.t()) :: JTD.Schema.t()
  def verify(schema), do: verify(schema, schema)

  @doc false
  def verify(schema, root) do
    [
      {:metadata, [:map]},
      {:nullable, [:boolean]},
      {:definitions, [:map]},
      {:ref, [:atom, :binary]},
      {:type, [:atom, :binary]},
      {:enum, [:list]},
      {:elements, [:schema]},
      {:properties, [:map]},
      {:optional_properties, [:map]},
      {:additional_properties, [:boolean]},
      {:values, [:schema]},
      {:discriminator, [:atom, :binary]},
      {:mapping, [:map]}
    ]
    |> Enum.each(fn opt -> check_type!(schema, opt) end)

    schema
    |> form_signature
    |> check_schema_form!(schema)

    schema
    |> Map.get(:definitions)
    |> check_definitions_is_only_in_root!(schema, root)
    |> check_ref_form!

    schema |> check_type_form!
    schema |> check_enum_form!
    schema |> check_properties_intersection!
    schema |> check_mapping_form!
    schema |> check_definitions_values(root)
    schema |> check_elements_value(root)
    schema |> check_properties_values(root)
    schema |> check_optional_properties_values(root)
    schema |> check_values_value(root)
    schema |> check_mapping_values(root)

    schema
  end

  @doc false
  def form(%{ref: ref}) when not is_nil(ref), do: :ref
  def form(%{type: type}) when not is_nil(type), do: :type
  def form(%{enum: enum}) when not is_nil(enum), do: :enum
  def form(%{elements: elements}) when not is_nil(elements), do: :elements
  def form(%{properties: properties, optional_properties: optional_properties}) when (not is_nil(properties)) or (not is_nil(optional_properties)), do: :properties
  def form(%{values: values}) when not is_nil(values), do: :values
  def form(%{discriminator: discriminator}) when not is_nil(discriminator), do: :discriminator
  def form(_), do: :empty

  defp convert_key(s) do
    s |> String.to_atom()
  rescue
    ArgumentError -> s
  end

  defp check_keywords!(schema) do
    illegal_keywords = Map.keys(schema) |> Enum.map(&convert_key/1) |> Kernel.--(@keywords)
    unless Enum.empty?(illegal_keywords) do
      raise TypeError, message: "illegal schema keywords: #{inspect(illegal_keywords)}"
    end

    schema
  end

  defp atomize_keys({schema, accum}) do
    schema = for {key, val} <- schema, into: %{}, do: {convert_key(key), val}

    {schema, accum}
  end

  defp parse_metadata({schema, accum}) do
    schema |> Map.get(:metadata) |> if do
      {schema, schema |> Map.take([:metadata]) |> Map.merge(accum)}
    else
      {schema, accum}
    end
  end

  defp parse_nullable({schema, accum}) do
    schema |> Map.get(:nullable) |> is_nil |> if do
      {schema, accum}
    else
      {schema, schema |> Map.take([:nullable]) |> Map.merge(accum)}
    end
  end

  defp underscore(key) when is_atom(key) do
    key |> Atom.to_string |> Macro.underscore |> String.to_atom
  end
  defp underscore(key) do
    key |> Macro.underscore
  end

  defp recursively_parse_enumerable_schema(schema, keyname) do
    %{underscore(keyname) => schema |> Map.get(keyname) |> Enum.map(fn {k, v} -> {k, from_map(v)} end) |> Map.new}
  end

  defp recursively_parse_schema(schema, keyname) do
    %{underscore(keyname) => schema |> Map.get(keyname) |> from_map}
  end

  defp parse_definitions({schema, accum}) do
    schema |> Map.get(:definitions) |> if do
      {schema, schema |> recursively_parse_enumerable_schema(:definitions) |> Map.merge(accum)}
    else
      {schema, accum}
    end
  end

  defp parse_ref({schema, accum}) do
    {schema, schema |> Map.take([:ref]) |> Map.merge(accum)}
  end

  defp parse_type({schema, accum}) do
    {schema, schema |> Map.take([:type]) |> Map.merge(accum)}
  end

  defp parse_enum({schema, accum}) do
    {schema, schema |> Map.take([:enum]) |> Map.merge(accum)}
  end

  defp parse_elements({schema, accum}) do
    schema |> Map.get(:elements) |> if do
      {schema, schema |> recursively_parse_schema(:elements) |> Map.merge(accum)}
    else
      {schema, accum}
    end
  end

  defp parse_properties({schema, accum}) do
    schema |> Map.get(:properties) |> if do
      {schema, schema |> recursively_parse_enumerable_schema(:properties) |> Map.merge(accum)}
    else
      {schema, accum}
    end
  end

  defp parse_optional_properties({schema, accum}) do
    schema |> Map.get(:optionalProperties) |> if do
      {schema, schema |> recursively_parse_enumerable_schema(:optionalProperties) |> Map.merge(accum)}
    else
      {schema, accum}
    end
  end

  defp parse_additional_properties({schema, accum}) do
    schema |> Map.get(:additionalProperties) |> is_nil |> if do
      {schema, accum}
    else
      additional_properties = %{additional_properties: Map.get(schema, :additionalProperties)}
      {schema, Map.merge(accum, additional_properties)}
    end
  end

  defp parse_values({schema, accum}) do
    schema |> Map.get(:values) |> if do
      {schema, schema |> recursively_parse_schema(:values) |> Map.merge(accum)}
    else
      {schema, accum}
    end
  end

  defp parse_discriminator({schema, accum}) do
    {schema, schema |> Map.take([:discriminator]) |> Map.merge(accum)}
  end

  defp parse_mapping({schema, accum}) do
    schema |> Map.get(:mapping) |> if do
      {schema, schema |> recursively_parse_enumerable_schema(:mapping) |> Map.merge(accum)}
    else
      {schema, accum}
    end
  end

  defp to_schema({_, accum}) do
    struct(JTD.Schema, accum)
  end

  @doc false
  def is_schema(term) do
    is_struct(term, JTD.Schema)
  end

  defp check_type!(schema, {keyname, types}) do
    form = schema |> Map.get(keyname)
    if form do
      types
      |> Enum.map(fn t -> String.to_atom("is_#{Atom.to_string(t)}") end)
      |> Enum.all?(fn test_fn -> !apply_test_fn(test_fn, form) end)
      |> if do
        raise TypeError, message: "#{Atom.to_string(keyname)} must be one of #{inspect(types)}, got: #{inspect(form)}"
      end
    end
  end

  defp apply_test_fn(:is_schema, form), do: apply(JTD.Schema, :is_schema, [form])
  defp apply_test_fn(test_fn, form), do: apply(Kernel, test_fn, [form])

  defp form_signature(schema) do
    schema
    |> Map.take(@forms)
    |> Enum.filter(fn {_, v} -> v != nil end)
    |> Map.new
    |> Map.keys
    |> MapSet.new
  end

  defp check_schema_form!(form, schema) do
    @valid_forms
    |> Enum.map(&MapSet.new/1)
    |> Enum.any?(fn valid_form -> MapSet.equal?(valid_form, form) end)
    |> unless do
      raise ArgumentError, message: "invalid schema form: #{inspect(schema)}"
    end
  end

  defp check_definitions_is_only_in_root!(nil, schema, root) when schema != root, do: {schema, root}
  defp check_definitions_is_only_in_root!(definitions, schema, root) when schema != root do
    raise ArgumentError, message: "non-root definitions: #{inspect(definitions)}"
  end
  defp check_definitions_is_only_in_root!(_, schema, root), do: {schema, root}

  defp check_ref_form!({%{ref: nil}, _}), do: true
  defp check_ref_form!({%{ref: ref}, %{definitions: nil} }) do
    raise ArgumentError, message: "ref to non-existent definition: #{ref}"
  end
  defp check_ref_form!({%{ref: ref}, %{definitions: definitions} }) do
    unless is_map_key(definitions, ref) do
      raise ArgumentError, message: "ref to non-existent definition: #{ref}"
    end
  end

  defp check_type_form!(%{type: nil}), do: true
  defp check_type_form!(%{type: type}) do
    @types
    |> Enum.member?(type)
    |> unless do
      raise ArgumentError, message: "invalid type: #{type}"
    end
  end

  defp check_enum_form!(%{enum: nil}), do: true
  defp check_enum_form!(schema) when schema.enum == [] do
    raise ArgumentError, message: "enum must not be empty: #{inspect(schema)}"
  end
  defp check_enum_form!(%{enum: enum}) do
    enum |> Enum.all?(&is_binary/1) |> unless do
      raise ArgumentError, message: "enum must contain only strings: #{inspect(enum)}"
    end

    original_length = enum |> length
    unique_length = enum |> Enum.uniq |> length
    if original_length != unique_length do
      raise ArgumentError, message: "enum must not contain duplicates: #{inspect(enum)}"
    end
  end

  defp check_properties_intersection!(%{properties: nil}), do: true
  defp check_properties_intersection!(%{optional_properties: nil}), do: true
  defp check_properties_intersection!(%{properties: properties, optional_properties: optional_properties}) do
    properties_keys = properties |> Map.keys |> MapSet.new
    optional_properties_keys = optional_properties |> Map.keys |> MapSet.new
    intersection = MapSet.intersection(properties_keys, optional_properties_keys)

    intersection
    |> MapSet.to_list
    |> Enum.empty?
    |> unless do
      raise ArgumentError, message: "properties and optionalProperties share keys: #{inspect(intersection)}"
    end
  end

  defp mapping_value_must_be_propeties_form(s) do
    if form(s) != :properties do
      raise ArgumentError, message: "mapping values must be of properties form: #{inspect(s)}"
    end
  end

  defp mapping_value_must_not_be_nullable(s) do
    s |> Map.get(:nullable) |> if do
      raise ArgumentError, message: "mapping values must not be nullable: #{inspect(s)}"
    end
  end

  defp mapping_value_must_not_contain_discriminator(s, keyname, discriminator) do
    case s |> Map.get(keyname) do
      nil ->
        true
      s -> s
        |> Map.keys
        |> Enum.member?(discriminator)
        |> if do
          raise ArgumentError, message: "mapping values must not contain discriminator (#{discriminator}): #{inspect(s)}"
        end
    end
  end

  defp check_mapping_form!(%{mapping: nil}), do: true
  defp check_mapping_form!(%{discriminator: discriminator, mapping: mapping}) do
    values = mapping |> Map.values
    values |> Enum.each(&mapping_value_must_be_propeties_form/1)
    values |> Enum.each(&mapping_value_must_not_be_nullable/1)
    values |> Enum.each(&mapping_value_must_not_contain_discriminator(&1, :properties, discriminator))
    values |> Enum.each(&mapping_value_must_not_contain_discriminator(&1, :optional_properties, discriminator))
  end

  defp check_definitions_values(%{definitions: nil}, _), do: true
  defp check_definitions_values(%{definitions: definitions}, root) do
    definitions |> Map.values |> Enum.each(&verify(&1, root))
  end

  defp check_elements_value(%{elements: nil}, _), do: true
  defp check_elements_value(%{elements: elements}, root) do
    elements |> verify(root)
  end

  defp check_properties_values(%{properties: nil}, _), do: true
  defp check_properties_values(%{properties: properties}, root) do
    properties |> Map.values |> Enum.each(&verify(&1, root))
  end

  defp check_optional_properties_values(%{optional_properties: nil}, _), do: true
  defp check_optional_properties_values(%{optional_properties: optional_properties}, root) do
    optional_properties |> Map.values |> Enum.each(&verify(&1, root))
  end

  defp check_values_value(%{values: nil}, _), do: true
  defp check_values_value(%{values: values}, root) do
    values |> verify(root)
  end

  defp check_mapping_values(%{mapping: nil}, _), do: true
  defp check_mapping_values(%{mapping: mapping}, root) do
    mapping |> Map.values |> Enum.each(&verify(&1, root))
  end
end
