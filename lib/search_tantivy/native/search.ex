defmodule SearchTantivy.Native.Search do
  @moduledoc """
  Behaviour for Tantivy search execution operations.

  Covers basic search, aggregated search, and search with snippet extraction.
  """

  @callback search(reference(), reference(), non_neg_integer(), non_neg_integer()) ::
              {:ok, [{float(), [{String.t(), String.t()}]}]} | {:error, String.t()}
  @callback search_with_aggs(reference(), reference(), String.t()) ::
              {:ok, String.t()} | {:error, String.t()}
  @callback search_with_snippets(
              reference(),
              reference(),
              non_neg_integer(),
              non_neg_integer(),
              [String.t()]
            ) ::
              {:ok, [{float(), [{String.t(), String.t()}], [{String.t(), String.t()}]}]}
              | {:error, String.t()}
end
