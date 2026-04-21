defmodule SearchTantivy.Native.Index do
  @moduledoc """
  Behaviour for Tantivy index lifecycle operations.

  Covers creating, opening, and configuring indexes, plus tokenizer registration.
  """

  @callback index_create(reference(), String.t()) :: {:ok, reference()} | {:error, String.t()}
  @callback index_create_in_ram(reference()) :: {:ok, reference()} | {:error, String.t()}
  @callback index_open(String.t()) :: {:ok, reference()} | {:error, String.t()}
  @callback index_writer_new(reference(), non_neg_integer()) ::
              {:ok, reference()} | {:error, String.t()}
  @callback index_reader(reference()) :: {:ok, reference()} | {:error, String.t()}
  @callback tokenizer_register(reference(), String.t()) :: {:ok, {}} | {:error, String.t()}
end
