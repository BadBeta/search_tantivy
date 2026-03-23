defmodule SearchTantivy.Native do
  @moduledoc false

  use Rustler,
    otp_app: :search_tantivy,
    crate: "search_tantivy_nif"

  # --- Schema NIFs ---

  @spec schema_build([{String.t(), String.t(), [{String.t(), String.t()}]}]) ::
          {:ok, reference()} | {:error, String.t()}
  def schema_build(_field_defs), do: :erlang.nif_error(:nif_not_loaded)

  @spec schema_field_exists(reference(), String.t()) :: {:ok, boolean()} | {:error, String.t()}
  def schema_field_exists(_index, _field_name), do: :erlang.nif_error(:nif_not_loaded)

  @spec schema_get_field_names(reference()) :: {:ok, [String.t()]} | {:error, String.t()}
  def schema_get_field_names(_index), do: :erlang.nif_error(:nif_not_loaded)

  @spec schema_get_field_type(reference(), String.t()) ::
          {:ok, String.t()} | {:error, String.t()}
  def schema_get_field_type(_index, _field_name), do: :erlang.nif_error(:nif_not_loaded)

  # --- Index NIFs ---

  @spec index_create(reference(), String.t()) :: {:ok, reference()} | {:error, String.t()}
  def index_create(_schema, _path), do: :erlang.nif_error(:nif_not_loaded)

  @spec index_create_in_ram(reference()) :: {:ok, reference()} | {:error, String.t()}
  def index_create_in_ram(_schema), do: :erlang.nif_error(:nif_not_loaded)

  @spec index_open(String.t()) :: {:ok, reference()} | {:error, String.t()}
  def index_open(_path), do: :erlang.nif_error(:nif_not_loaded)

  @spec index_writer_new(reference(), non_neg_integer()) ::
          {:ok, reference()} | {:error, String.t()}
  def index_writer_new(_index, _memory_budget), do: :erlang.nif_error(:nif_not_loaded)

  @spec index_reader(reference()) :: {:ok, reference()} | {:error, String.t()}
  def index_reader(_index), do: :erlang.nif_error(:nif_not_loaded)

  # --- Document NIFs ---

  @spec document_create(reference(), [{String.t(), String.t()}]) ::
          {:ok, reference()} | {:error, String.t()}
  def document_create(_schema, _field_values), do: :erlang.nif_error(:nif_not_loaded)

  # --- Writer NIFs ---

  @spec writer_add_document(reference(), reference()) :: {:ok, {}} | {:error, String.t()}
  def writer_add_document(_writer, _document), do: :erlang.nif_error(:nif_not_loaded)

  @spec writer_delete_documents(reference(), String.t(), String.t()) ::
          {:ok, {}} | {:error, String.t()}
  def writer_delete_documents(_writer, _field, _value), do: :erlang.nif_error(:nif_not_loaded)

  @spec writer_commit(reference()) :: {:ok, non_neg_integer()} | {:error, String.t()}
  def writer_commit(_writer), do: :erlang.nif_error(:nif_not_loaded)

  # --- Query NIFs ---

  @spec query_parse(reference(), String.t(), [String.t()]) ::
          {:ok, reference()} | {:error, String.t()}
  def query_parse(_index, _query_string, _fields), do: :erlang.nif_error(:nif_not_loaded)

  @spec query_term(reference(), String.t(), String.t()) ::
          {:ok, reference()} | {:error, String.t()}
  def query_term(_index, _field, _value), do: :erlang.nif_error(:nif_not_loaded)

  @spec query_boolean([{String.t(), reference()}]) :: {:ok, reference()} | {:error, String.t()}
  def query_boolean(_clauses), do: :erlang.nif_error(:nif_not_loaded)

  @spec query_all() :: {:ok, reference()} | {:error, String.t()}
  def query_all, do: :erlang.nif_error(:nif_not_loaded)

  @spec query_boost(reference(), float()) :: {:ok, reference()} | {:error, String.t()}
  def query_boost(_query, _factor), do: :erlang.nif_error(:nif_not_loaded)

  @spec query_fuzzy_term(reference(), String.t(), String.t(), non_neg_integer(), boolean()) ::
          {:ok, reference()} | {:error, String.t()}
  def query_fuzzy_term(_index, _field, _value, _distance, _transpose_costs_one),
    do: :erlang.nif_error(:nif_not_loaded)

  @spec query_phrase(reference(), String.t(), [String.t()]) ::
          {:ok, reference()} | {:error, String.t()}
  def query_phrase(_index, _field, _words), do: :erlang.nif_error(:nif_not_loaded)

  @spec query_phrase_prefix(reference(), String.t(), [String.t()]) ::
          {:ok, reference()} | {:error, String.t()}
  def query_phrase_prefix(_index, _field, _words), do: :erlang.nif_error(:nif_not_loaded)

  @spec query_regex(reference(), String.t(), String.t()) ::
          {:ok, reference()} | {:error, String.t()}
  def query_regex(_index, _field, _pattern), do: :erlang.nif_error(:nif_not_loaded)

  @spec query_exists(reference(), String.t()) ::
          {:ok, reference()} | {:error, String.t()}
  def query_exists(_index, _field), do: :erlang.nif_error(:nif_not_loaded)

  # --- Search NIFs ---

  @spec search(reference(), reference(), non_neg_integer(), non_neg_integer()) ::
          {:ok, [{float(), [{String.t(), String.t()}]}]} | {:error, String.t()}
  def search(_reader, _query, _limit, _offset), do: :erlang.nif_error(:nif_not_loaded)

  # --- Search with Aggregations NIF ---

  @spec search_with_aggs(reference(), reference(), String.t()) ::
          {:ok, String.t()} | {:error, String.t()}
  def search_with_aggs(_reader, _query, _agg_json), do: :erlang.nif_error(:nif_not_loaded)

  # --- Search with Snippets NIF ---

  @spec search_with_snippets(reference(), reference(), non_neg_integer(), non_neg_integer(), [
          String.t()
        ]) ::
          {:ok, [{float(), [{String.t(), String.t()}], [{String.t(), String.t()}]}]}
          | {:error, String.t()}
  def search_with_snippets(_reader, _query, _limit, _offset, _snippet_fields),
    do: :erlang.nif_error(:nif_not_loaded)

  # --- Tokenizer NIFs ---

  @spec tokenizer_register(reference(), String.t()) :: {:ok, {}} | {:error, String.t()}
  def tokenizer_register(_index, _tokenizer_name), do: :erlang.nif_error(:nif_not_loaded)
end
