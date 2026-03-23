defmodule SearchTantivy.Document do
  @moduledoc """
  Build documents for indexing. Pure functional — no processes needed.

  Documents are collections of field-value pairs that match a schema.
  They are created from maps with atom keys and converted to the
  internal tantivy representation via NIF.

  ## Type Coercion

  | Elixir Type | Target Field Type | Notes |
  |-------------|------------------|-------|
  | `String.t()` | `:text`, `:string` | Direct mapping |
  | `integer()` | `:u64`, `:i64` | Validated at NIF boundary |
  | `float()` | `:f64` | Direct mapping |
  | `boolean()` | `:bool` | Converted to string |
  | `DateTime.t()` | `:date` | Converted to ISO 8601 |
  | `binary()` | `:bytes` | Base64 encoded |

  ## Examples

      schema = SearchTantivy.Schema.build!([
        {:title, :text, stored: true},
        {:body, :text, stored: true}
      ])

      {:ok, doc} = SearchTantivy.Document.new(schema, %{
        title: "Hello World",
        body: "First post content"
      })

  """

  @type t :: reference()

  @doc """
  Creates a new document from a schema and a map of field values.

  Field keys must be atoms matching field names in the schema.
  Values are coerced to the appropriate type for the field.

  ## Examples

      {:ok, doc} = SearchTantivy.Document.new(schema, %{title: "Hello", body: "World"})

  """
  @spec new(SearchTantivy.Schema.t(), map()) :: {:ok, t()} | {:error, String.t()}
  def new(schema, fields) when is_reference(schema) and is_map(fields) do
    field_values =
      Enum.map(fields, fn {k, v} ->
        {Atom.to_string(k), SearchTantivy.Value.to_string_value(v)}
      end)

    SearchTantivy.Native.document_create(schema, field_values)
  end
end
