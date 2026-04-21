defmodule SearchTantivy.Native.Schema do
  @moduledoc """
  Behaviour for Tantivy schema operations.

  Covers building schemas and inspecting field metadata.
  """

  @callback schema_build([{String.t(), String.t(), [{String.t(), String.t()}]}]) ::
              {:ok, reference()} | {:error, String.t()}
  @callback schema_field_exists(reference(), String.t()) ::
              {:ok, boolean()} | {:error, String.t()}
  @callback schema_get_field_names(reference()) :: {:ok, [String.t()]} | {:error, String.t()}
  @callback schema_get_field_type(reference(), String.t()) ::
              {:ok, String.t()} | {:error, String.t()}
end
