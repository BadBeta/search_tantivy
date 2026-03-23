defmodule SearchTantivy.Schema do
  @moduledoc """
  Build search schemas. Pure functional — no processes needed.

  A schema defines the fields in an index, their types, and storage options.
  Schemas are immutable after construction and represented as opaque references.

  ## Field Types

  | Type | Description | Example Values |
  |------|-------------|---------------|
  | `:text` | Tokenized full-text, searchable | `"Hello world"` |
  | `:string` | Exact-match, not tokenized | `"user-123"` |
  | `:u64` | Unsigned 64-bit integer | `42` |
  | `:i64` | Signed 64-bit integer | `-10` |
  | `:f64` | 64-bit float | `3.14` |
  | `:bool` | Boolean | `true` |
  | `:date` | Date/datetime | `"2024-01-15T00:00:00Z"` |
  | `:bytes` | Raw bytes | `<<1, 2, 3>>` |
  | `:json` | JSON object | `%{"nested" => "data"}` |
  | `:ip_addr` | IP address | `"192.168.1.1"` |
  | `:facet` | Hierarchical facet | `"/category/subcategory"` |

  ## Field Options

  | Option | Default | Description |
  |--------|---------|-------------|
  | `:stored` | `false` | Store original value for retrieval |
  | `:indexed` | `true` | Include in search index |
  | `:fast` | `false` | Enable fast-field (columnar) access |
  | `:tokenizer` | `:default` | Tokenizer to use (text fields only) |

  ## Examples

      {:ok, schema} = SearchTantivy.Schema.build([
        {:title, :text, stored: true},
        {:body, :text, stored: true},
        {:url, :string, stored: true, indexed: true},
        {:view_count, :u64, stored: true, fast: true}
      ])

      # Or using the bang variant:
      schema = SearchTantivy.Schema.build!([
        {:title, :text, stored: true},
        {:body, :text}
      ])

  """

  @type field_type ::
          :text
          | :string
          | :u64
          | :i64
          | :f64
          | :bool
          | :date
          | :bytes
          | :json
          | :ip_addr
          | :facet

  @type field_option ::
          {:stored, boolean()}
          | {:indexed, boolean()}
          | {:fast, boolean()}
          | {:tokenizer, atom()}

  @type field_def ::
          {atom(), field_type()} | {atom(), field_type(), [field_option()]}

  @type t :: reference()

  @valid_types ~w(text string u64 i64 f64 bool date bytes json ip_addr facet)a

  @doc """
  Builds a schema from a list of field definitions.

  Each field definition is a tuple of `{name, type}` or `{name, type, options}`.

  ## Examples

      iex> {:ok, schema} = SearchTantivy.Schema.build([{:title, :text, stored: true}])
      iex> is_reference(schema)
      true

      iex> SearchTantivy.Schema.build([{:bad, :nonexistent}])
      {:error, _}

  """
  @spec build([field_def()]) :: {:ok, t()} | {:error, String.t()}
  def build(fields) when is_list(fields) do
    with {:ok, normalized} <- normalize_fields(fields) do
      SearchTantivy.Native.schema_build(normalized)
    end
  end

  @doc """
  Builds a schema from a list of field definitions, raising on error.

  Same as `build/1` but raises `ArgumentError` on failure.

  ## Examples

      schema = SearchTantivy.Schema.build!([{:title, :text, stored: true}])

  """
  @spec build!([field_def()]) :: t()
  def build!(fields) do
    case build(fields) do
      {:ok, schema} -> schema
      {:error, reason} -> raise ArgumentError, "failed to build schema: #{reason}"
    end
  end

  @doc """
  Checks if a field exists in the index schema.

  Requires an index reference (not a schema reference).

  ## Examples

      SearchTantivy.Schema.field_exists?(index_ref, :title)
      # => true

  """
  @spec field_exists?(reference(), atom()) :: boolean()
  def field_exists?(index_ref, field) when is_reference(index_ref) and is_atom(field) do
    case SearchTantivy.Native.schema_field_exists(index_ref, Atom.to_string(field)) do
      {:ok, result} -> result
      {:error, _} -> false
    end
  end

  @doc """
  Returns the names of all fields in the index schema as atoms.

  ## Examples

      SearchTantivy.Schema.field_names(index_ref)
      # => [:title, :body, :slug]

  """
  @spec field_names(reference()) :: [atom()]
  def field_names(index_ref) when is_reference(index_ref) do
    case SearchTantivy.Native.schema_get_field_names(index_ref) do
      {:ok, names} -> Enum.map(names, &String.to_atom/1)
      {:error, _} -> []
    end
  end

  @doc """
  Returns the type of a field in the index schema.

  ## Examples

      SearchTantivy.Schema.field_type(index_ref, :title)
      # => {:ok, :text}

  """
  @spec field_type(reference(), atom()) :: {:ok, field_type()} | {:error, String.t()}
  def field_type(index_ref, field) when is_reference(index_ref) and is_atom(field) do
    case SearchTantivy.Native.schema_get_field_type(index_ref, Atom.to_string(field)) do
      {:ok, type_string} -> {:ok, String.to_atom(type_string)}
      {:error, _} = error -> error
    end
  end

  # --- Private ---

  defp normalize_fields(fields) do
    fields
    |> Enum.reduce_while([], fn field, acc ->
      case normalize_field(field) do
        {:ok, normalized} -> {:cont, [normalized | acc]}
        {:error, _} = error -> {:halt, error}
      end
    end)
    |> case do
      {:error, _} = error -> error
      normalized when is_list(normalized) -> {:ok, Enum.reverse(normalized)}
    end
  end

  defp normalize_field({name, type}) when is_atom(name) and type in @valid_types do
    {:ok, {Atom.to_string(name), Atom.to_string(type), []}}
  end

  defp normalize_field({name, type, opts})
       when is_atom(name) and type in @valid_types and is_list(opts) do
    normalized_opts =
      Enum.map(opts, fn
        {k, v} when is_atom(k) and is_boolean(v) -> {Atom.to_string(k), to_string(v)}
        {k, v} when is_atom(k) and is_atom(v) -> {Atom.to_string(k), Atom.to_string(v)}
      end)

    {:ok, {Atom.to_string(name), Atom.to_string(type), normalized_opts}}
  end

  defp normalize_field({_name, type}) do
    {:error, "invalid field type: #{inspect(type)}. Valid types: #{inspect(@valid_types)}"}
  end

  defp normalize_field({_name, type, _opts}) do
    {:error, "invalid field type: #{inspect(type)}. Valid types: #{inspect(@valid_types)}"}
  end

  defp normalize_field(invalid) do
    {:error,
     "invalid field definition: #{inspect(invalid)}. Expected {name, type} or {name, type, opts}"}
  end
end
