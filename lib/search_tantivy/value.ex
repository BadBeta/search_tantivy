defmodule SearchTantivy.Value do
  @moduledoc false

  @typedoc "Values convertible to a tantivy field string."
  @type convertible ::
          binary()
          | number()
          | boolean()
          | atom()
          | nil
          | DateTime.t()
          | NaiveDateTime.t()

  @doc false
  @spec to_string_value(term()) :: {:ok, String.t()} | {:error, :unsupported_type}
  def to_string_value(value) when is_binary(value), do: {:ok, value}
  def to_string_value(value) when is_integer(value), do: {:ok, Integer.to_string(value)}
  def to_string_value(value) when is_float(value), do: {:ok, Float.to_string(value)}
  def to_string_value(true), do: {:ok, "true"}
  def to_string_value(false), do: {:ok, "false"}
  def to_string_value(%DateTime{} = dt), do: {:ok, DateTime.to_iso8601(dt)}
  def to_string_value(nil), do: {:ok, ""}
  def to_string_value(%NaiveDateTime{} = dt), do: {:ok, NaiveDateTime.to_iso8601(dt)}
  def to_string_value(value) when is_atom(value), do: {:ok, Atom.to_string(value)}
  def to_string_value(_value), do: {:error, :unsupported_type}

  @doc false
  @spec to_string_value!(convertible()) :: String.t()
  def to_string_value!(value) do
    case to_string_value(value) do
      {:ok, str} ->
        str

      {:error, :unsupported_type} ->
        raise ArgumentError,
              "cannot convert #{inspect(value)} to a tantivy value. " <>
                "Supported types: binary, number, boolean, atom, nil, DateTime, NaiveDateTime"
    end
  end
end
