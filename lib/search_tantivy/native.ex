defmodule SearchTantivy.Native do
  @moduledoc """
  NIF bindings for the Tantivy search engine.

  This module defines both the NIF stubs and the behaviour callbacks,
  enabling test mocking via Mox:

      Mox.defmock(SearchTantivy.MockNative, for: SearchTantivy.Native)

  ## Sub-behaviours

  Callbacks are also available as focused sub-behaviours for granular mocking:

    * `SearchTantivy.Native.Schema` — schema building and field inspection (4 callbacks)
    * `SearchTantivy.Native.Index` — index lifecycle and tokenizer registration (6 callbacks)
    * `SearchTantivy.Native.Writer` — document creation and write operations (4 callbacks)
    * `SearchTantivy.Native.Query` — query construction (10 callbacks)
    * `SearchTantivy.Native.Search` — search execution (3 callbacks)

  """

  # --- Behaviour callbacks (enables Mox-based testing) ---

  @callback schema_build([{String.t(), String.t(), [{String.t(), String.t()}]}]) ::
              {:ok, reference()} | {:error, String.t()}
  @callback schema_field_exists(reference(), String.t()) ::
              {:ok, boolean()} | {:error, String.t()}
  @callback schema_get_field_names(reference()) :: {:ok, [String.t()]} | {:error, String.t()}
  @callback schema_get_field_type(reference(), String.t()) ::
              {:ok, String.t()} | {:error, String.t()}
  @callback index_create(reference(), String.t()) :: {:ok, reference()} | {:error, String.t()}
  @callback index_create_in_ram(reference()) :: {:ok, reference()} | {:error, String.t()}
  @callback index_open(String.t()) :: {:ok, reference()} | {:error, String.t()}
  @callback index_writer_new(reference(), non_neg_integer()) ::
              {:ok, reference()} | {:error, String.t()}
  @callback index_reader(reference()) :: {:ok, reference()} | {:error, String.t()}
  @callback document_create(reference(), [{String.t(), String.t()}]) ::
              {:ok, reference()} | {:error, String.t()}
  @callback writer_add_document(reference(), reference()) :: {:ok, {}} | {:error, String.t()}
  @callback writer_delete_documents(reference(), String.t(), String.t()) ::
              {:ok, {}} | {:error, String.t()}
  @callback writer_commit(reference()) :: {:ok, non_neg_integer()} | {:error, String.t()}
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
  @callback tokenizer_register(reference(), String.t()) :: {:ok, {}} | {:error, String.t()}

  @typedoc """
  Standard NIF return shape: `{:ok, T}` on success, `{:error, message}`
  on failure. NIF errors arrive as strings — see
  `native/search_tantivy_nif/src/error.rs` for the underlying
  `TantivyNifError` enum.
  """
  @type nif_result(t) :: {:ok, t} | {:error, String.t()}

  @typedoc """
  A single search hit returned by the `search/4` NIF: `{score, [{field_name, field_value}]}`.
  """
  @type search_hit :: {float(), [{String.t(), String.t()}]}

  @typedoc """
  A search hit with snippets: `{score, [{field, value}], [{field, snippet_html}]}`.
  """
  @type snippet_hit :: {float(), [{String.t(), String.t()}], [{String.t(), String.t()}]}

  @behaviour SearchTantivy.Native.Schema
  @behaviour SearchTantivy.Native.Index
  @behaviour SearchTantivy.Native.Writer
  @behaviour SearchTantivy.Native.Query
  @behaviour SearchTantivy.Native.Search

  use Rustler,
    otp_app: :search_tantivy,
    crate: "search_tantivy_nif"

  # --- Schema NIFs ---

  @spec schema_build([{String.t(), String.t(), [{String.t(), String.t()}]}]) ::
          nif_result(reference())
  @impl SearchTantivy.Native.Schema
  def schema_build(_field_defs), do: :erlang.nif_error(:nif_not_loaded)

  @spec schema_field_exists(reference(), String.t()) :: nif_result(boolean())
  @impl SearchTantivy.Native.Schema
  def schema_field_exists(_index, _field_name), do: :erlang.nif_error(:nif_not_loaded)

  @spec schema_get_field_names(reference()) :: nif_result([String.t()])
  @impl SearchTantivy.Native.Schema
  def schema_get_field_names(_index), do: :erlang.nif_error(:nif_not_loaded)

  @spec schema_get_field_type(reference(), String.t()) :: nif_result(String.t())
  @impl SearchTantivy.Native.Schema
  def schema_get_field_type(_index, _field_name), do: :erlang.nif_error(:nif_not_loaded)

  # --- Index NIFs ---

  @spec index_create(reference(), String.t()) :: nif_result(reference())
  @impl SearchTantivy.Native.Index
  def index_create(_schema, _path), do: :erlang.nif_error(:nif_not_loaded)

  @spec index_create_in_ram(reference()) :: nif_result(reference())
  @impl SearchTantivy.Native.Index
  def index_create_in_ram(_schema), do: :erlang.nif_error(:nif_not_loaded)

  @spec index_open(String.t()) :: nif_result(reference())
  @impl SearchTantivy.Native.Index
  def index_open(_path), do: :erlang.nif_error(:nif_not_loaded)

  @spec index_writer_new(reference(), non_neg_integer()) :: nif_result(reference())
  @impl SearchTantivy.Native.Index
  def index_writer_new(_index, _memory_budget), do: :erlang.nif_error(:nif_not_loaded)

  @spec index_reader(reference()) :: nif_result(reference())
  @impl SearchTantivy.Native.Index
  def index_reader(_index), do: :erlang.nif_error(:nif_not_loaded)

  # --- Writer NIFs ---

  @spec document_create(reference(), [{String.t(), String.t()}]) :: nif_result(reference())
  @impl SearchTantivy.Native.Writer
  def document_create(_schema, _field_values), do: :erlang.nif_error(:nif_not_loaded)

  @spec writer_add_document(reference(), reference()) :: nif_result({})
  @impl SearchTantivy.Native.Writer
  def writer_add_document(_writer, _document), do: :erlang.nif_error(:nif_not_loaded)

  @spec writer_delete_documents(reference(), String.t(), String.t()) :: nif_result({})
  @impl SearchTantivy.Native.Writer
  def writer_delete_documents(_writer, _field, _value), do: :erlang.nif_error(:nif_not_loaded)

  @spec writer_commit(reference()) :: nif_result(non_neg_integer())
  @impl SearchTantivy.Native.Writer
  def writer_commit(_writer), do: :erlang.nif_error(:nif_not_loaded)

  # --- Query NIFs ---

  @spec query_parse(reference(), String.t(), [String.t()]) :: nif_result(reference())
  @impl SearchTantivy.Native.Query
  def query_parse(_index, _query_string, _fields), do: :erlang.nif_error(:nif_not_loaded)

  @spec query_term(reference(), String.t(), String.t()) :: nif_result(reference())
  @impl SearchTantivy.Native.Query
  def query_term(_index, _field, _value), do: :erlang.nif_error(:nif_not_loaded)

  @spec query_boolean([{String.t(), reference()}]) :: nif_result(reference())
  @impl SearchTantivy.Native.Query
  def query_boolean(_clauses), do: :erlang.nif_error(:nif_not_loaded)

  @spec query_all() :: nif_result(reference())
  @impl SearchTantivy.Native.Query
  def query_all, do: :erlang.nif_error(:nif_not_loaded)

  @spec query_boost(reference(), float()) :: nif_result(reference())
  @impl SearchTantivy.Native.Query
  def query_boost(_query, _factor), do: :erlang.nif_error(:nif_not_loaded)

  @spec query_fuzzy_term(reference(), String.t(), String.t(), non_neg_integer(), boolean()) ::
          nif_result(reference())
  @impl SearchTantivy.Native.Query
  def query_fuzzy_term(_index, _field, _value, _distance, _transpose_costs_one),
    do: :erlang.nif_error(:nif_not_loaded)

  @spec query_phrase(reference(), String.t(), [String.t()]) :: nif_result(reference())
  @impl SearchTantivy.Native.Query
  def query_phrase(_index, _field, _words), do: :erlang.nif_error(:nif_not_loaded)

  @spec query_phrase_prefix(reference(), String.t(), [String.t()]) :: nif_result(reference())
  @impl SearchTantivy.Native.Query
  def query_phrase_prefix(_index, _field, _words), do: :erlang.nif_error(:nif_not_loaded)

  @spec query_regex(reference(), String.t(), String.t()) :: nif_result(reference())
  @impl SearchTantivy.Native.Query
  def query_regex(_index, _field, _pattern), do: :erlang.nif_error(:nif_not_loaded)

  @spec query_exists(reference(), String.t()) :: nif_result(reference())
  @impl SearchTantivy.Native.Query
  def query_exists(_index, _field), do: :erlang.nif_error(:nif_not_loaded)

  # --- Search NIFs ---

  @spec search(reference(), reference(), non_neg_integer(), non_neg_integer()) ::
          nif_result([search_hit()])
  @impl SearchTantivy.Native.Search
  def search(_reader, _query, _limit, _offset), do: :erlang.nif_error(:nif_not_loaded)

  @spec search_with_aggs(reference(), reference(), String.t()) :: nif_result(String.t())
  @impl SearchTantivy.Native.Search
  def search_with_aggs(_reader, _query, _agg_json), do: :erlang.nif_error(:nif_not_loaded)

  @spec search_with_snippets(
          reference(),
          reference(),
          non_neg_integer(),
          non_neg_integer(),
          [String.t()]
        ) :: nif_result([snippet_hit()])
  @impl SearchTantivy.Native.Search
  def search_with_snippets(_reader, _query, _limit, _offset, _snippet_fields),
    do: :erlang.nif_error(:nif_not_loaded)

  # --- Tokenizer NIFs ---

  @spec tokenizer_register(reference(), String.t()) :: nif_result({})
  @impl SearchTantivy.Native.Index
  def tokenizer_register(_index, _tokenizer_name), do: :erlang.nif_error(:nif_not_loaded)
end
