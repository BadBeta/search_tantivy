defmodule SearchTantivy.Tokenizer do
  @moduledoc """
  Built-in tokenizer registration.

  Tantivy provides several built-in tokenizers that can be registered
  by atom name on an index.

  ## Built-in Tokenizers

  | Name | Description |
  |------|-------------|
  | `:default` | Unicode-aware, lowercase, max 40 chars |
  | `:raw` | No tokenization, entire value as single token |
  | `:whitespace` | Split on whitespace only |
  | `:en_stem` | English stemming |
  | `:fr_stem` | French stemming |
  | `:de_stem` | German stemming |
  | `:es_stem` | Spanish stemming |
  | `:pt_stem` | Portuguese stemming |
  | `:it_stem` | Italian stemming |
  | `:nl_stem` | Dutch stemming |
  | `:sv_stem` | Swedish stemming |
  | `:no_stem` | Norwegian stemming |
  | `:da_stem` | Danish stemming |
  | `:fi_stem` | Finnish stemming |
  | `:hu_stem` | Hungarian stemming |
  | `:ro_stem` | Romanian stemming |
  | `:ru_stem` | Russian stemming |
  | `:tr_stem` | Turkish stemming |
  | `:ar_stem` | Arabic stemming |
  | `:ta_stem` | Tamil stemming |
  | `:el_stem` | Greek stemming |

  ## Examples

      # Register a built-in tokenizer on an index
      {:ok, index_ref} = SearchTantivy.Index.index_ref(index)
      :ok = SearchTantivy.Tokenizer.register(index_ref, :en_stem)

  """

  @doc """
  Registers a built-in tokenizer on the given index.

  ## Examples

      :ok = SearchTantivy.Tokenizer.register(index_ref, :en_stem)

  """
  @spec register(reference(), atom()) :: :ok | {:error, String.t()}
  def register(index_ref, tokenizer_name) when is_atom(tokenizer_name) do
    case SearchTantivy.Native.tokenizer_register(index_ref, Atom.to_string(tokenizer_name)) do
      {:ok, {}} -> :ok
      {:error, _} = error -> error
    end
  end
end
