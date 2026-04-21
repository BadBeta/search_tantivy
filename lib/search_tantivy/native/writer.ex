defmodule SearchTantivy.Native.Writer do
  @moduledoc """
  Behaviour for Tantivy document and writer operations.

  Covers document creation, adding/deleting documents, and committing writes.
  """

  @callback document_create(reference(), [{String.t(), String.t()}]) ::
              {:ok, reference()} | {:error, String.t()}
  @callback writer_add_document(reference(), reference()) :: {:ok, {}} | {:error, String.t()}
  @callback writer_delete_documents(reference(), String.t(), String.t()) ::
              {:ok, {}} | {:error, String.t()}
  @callback writer_commit(reference()) :: {:ok, non_neg_integer()} | {:error, String.t()}
end
