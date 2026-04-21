defmodule SearchTantivy.Native.Query do
  @moduledoc """
  Behaviour for Tantivy query construction operations.

  Covers parsing queries and building term, boolean, boost, fuzzy, phrase, regex, and exists queries.
  """

  @callback query_parse(reference(), String.t(), [String.t()]) ::
              {:ok, reference()} | {:error, String.t()}
  @callback query_term(reference(), String.t(), String.t()) ::
              {:ok, reference()} | {:error, String.t()}
  @callback query_boolean([{String.t(), reference()}]) ::
              {:ok, reference()} | {:error, String.t()}
  @callback query_all() :: {:ok, reference()} | {:error, String.t()}
  @callback query_boost(reference(), float()) :: {:ok, reference()} | {:error, String.t()}
  @callback query_fuzzy_term(reference(), String.t(), String.t(), non_neg_integer(), boolean()) ::
              {:ok, reference()} | {:error, String.t()}
  @callback query_phrase(reference(), String.t(), [String.t()]) ::
              {:ok, reference()} | {:error, String.t()}
  @callback query_phrase_prefix(reference(), String.t(), [String.t()]) ::
              {:ok, reference()} | {:error, String.t()}
  @callback query_regex(reference(), String.t(), String.t()) ::
              {:ok, reference()} | {:error, String.t()}
  @callback query_exists(reference(), String.t()) ::
              {:ok, reference()} | {:error, String.t()}
end
