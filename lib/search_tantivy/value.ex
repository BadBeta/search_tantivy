defmodule SearchTantivy.Value do
  @moduledoc false

  @doc false
  @spec to_string_value(
          binary()
          | number()
          | boolean()
          | atom()
          | nil
          | DateTime.t()
          | NaiveDateTime.t()
        ) :: String.t()
  def to_string_value(value) when is_binary(value), do: value
  def to_string_value(value) when is_integer(value), do: Integer.to_string(value)
  def to_string_value(value) when is_float(value), do: Float.to_string(value)
  def to_string_value(true), do: "true"
  def to_string_value(false), do: "false"
  def to_string_value(%DateTime{} = dt), do: DateTime.to_iso8601(dt)
  def to_string_value(nil), do: ""
  def to_string_value(%NaiveDateTime{} = dt), do: NaiveDateTime.to_iso8601(dt)
  def to_string_value(value) when is_atom(value), do: Atom.to_string(value)

  def to_string_value(value) do
    raise ArgumentError,
          "cannot convert #{inspect(value)} to a tantivy value. " <>
            "Supported types: binary, number, boolean, atom, nil, DateTime, NaiveDateTime"
  end
end
