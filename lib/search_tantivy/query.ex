defmodule SearchTantivy.Query do
  @moduledoc """
  Build search queries. Pure functional, composable via pipelines.

  Queries are immutable after construction and represented as opaque references.
  They can be combined using boolean logic (must/should/must_not) and boosted
  to adjust relevance scoring.

  ## Query Types

  | Function | Description | Example |
  |----------|-------------|---------|
  | `parse/3` | Parse a query string (full-text) | `"hello world"` |
  | `term_query/3` | Exact term match | field=value |
  | `boolean_query/1` | Combine queries with boolean logic | must + should |
  | `all_query/0` | Match all documents | |
  | `boost/2` | Adjust query weight | 2.0x title |
  | `phrase/3` | Exact phrase match | `["hello", "world"]` |
  | `phrase_prefix/3` | Autocomplete prefix match | `["quick", "bro"]` |
  | `regex/3` | Pattern matching | `"elixir-.*"` |
  | `exists/2` | Field has any value | field exists |
  | `fuzzy_term/4` | Typo-tolerant term match | distance=1 |
  | `range_query` | Use `parse/3` with range syntax | `"price:[10 TO 100]"` |

  ## Examples

      # Simple text search
      {:ok, query} = SearchTantivy.Query.parse(index_ref, "hello world")

      # Boolean query with boosted title
      {:ok, title_q} = SearchTantivy.Query.parse(index_ref, "hello", [:title])
      {:ok, boosted} = SearchTantivy.Query.boost(title_q, 2.0)
      {:ok, body_q} = SearchTantivy.Query.parse(index_ref, "hello", [:body])
      {:ok, combined} = SearchTantivy.Query.boolean_query([
        {:must, boosted},
        {:should, body_q}
      ])

  """

  @type t :: reference()
  @type occur :: :must | :should | :must_not

  @doc """
  Parses a query string against the given index.

  When `fields` is empty, searches all text fields.

  ## Examples

      {:ok, query} = SearchTantivy.Query.parse(index_ref, "hello world")
      {:ok, query} = SearchTantivy.Query.parse(index_ref, "hello", [:title, :body])

  """
  @spec parse(reference(), String.t(), [atom()]) :: {:ok, t()} | {:error, String.t()}
  def parse(index_ref, query_string, fields \\ []) when is_binary(query_string) do
    string_fields = Enum.map(fields, &Atom.to_string/1)
    SearchTantivy.Native.query_parse(index_ref, query_string, string_fields)
  end

  @doc """
  Creates an exact term query for the given field and value.

  Requires an index reference for field type resolution.

  ## Examples

      {:ok, query} = SearchTantivy.Query.term_query(index_ref, :status, "published")

  """
  @spec term_query(reference(), atom(), term()) :: {:ok, t()} | {:error, String.t()}
  def term_query(index_ref, field, value) when is_reference(index_ref) and is_atom(field) do
    SearchTantivy.Native.query_term(index_ref, Atom.to_string(field), to_string(value))
  end

  @doc """
  Creates a boolean query from a list of `{occur, query}` clauses.

  ## Occur Values

    * `:must` - document must match this clause
    * `:should` - document may match (boosts score)
    * `:must_not` - document must not match

  ## Examples

      {:ok, combined} = SearchTantivy.Query.boolean_query([
        {:must, title_query},
        {:should, body_query},
        {:must_not, spam_query}
      ])

  """
  @spec boolean_query([{occur(), t()}]) :: {:ok, t()} | {:error, String.t()}
  def boolean_query(clauses) when is_list(clauses) do
    normalized =
      Enum.map(clauses, fn {occur, query} ->
        {Atom.to_string(occur), query}
      end)

    SearchTantivy.Native.query_boolean(normalized)
  end

  @doc """
  Creates a query that matches all documents.

  ## Examples

      {:ok, query} = SearchTantivy.Query.all_query()

  """
  @spec all_query() :: {:ok, t()} | {:error, String.t()}
  def all_query do
    SearchTantivy.Native.query_all()
  end

  @doc """
  Boosts the score of a query by the given factor.

  ## Examples

      {:ok, boosted} = SearchTantivy.Query.boost(title_query, 2.0)

  """
  @spec boost(t(), float()) :: {:ok, t()} | {:error, String.t()}
  def boost(query, factor) when is_reference(query) and is_float(factor) do
    SearchTantivy.Native.query_boost(query, factor)
  end

  @doc """
  Creates a phrase query for exact phrase matching on a field.

  The words must appear in the exact order given.

  ## Examples

      {:ok, query} = SearchTantivy.Query.phrase(index_ref, :title, ["hello", "world"])

  """
  @spec phrase(reference(), atom(), [String.t()]) :: {:ok, t()} | {:error, String.t()}
  def phrase(index_ref, field, words)
      when is_reference(index_ref) and is_atom(field) and is_list(words) do
    SearchTantivy.Native.query_phrase(index_ref, Atom.to_string(field), words)
  end

  @doc """
  Creates a phrase prefix query for autocomplete-style matching.

  Matches documents where the field contains words starting with the
  given prefix sequence. Useful for search-as-you-type.

  ## Examples

      {:ok, query} = SearchTantivy.Query.phrase_prefix(index_ref, :title, ["quick", "bro"])

  """
  @spec phrase_prefix(reference(), atom(), [String.t()]) :: {:ok, t()} | {:error, String.t()}
  def phrase_prefix(index_ref, field, words)
      when is_reference(index_ref) and is_atom(field) and is_list(words) do
    SearchTantivy.Native.query_phrase_prefix(index_ref, Atom.to_string(field), words)
  end

  @doc """
  Creates a regex query for pattern matching on a field.

  Uses tantivy's regex syntax (Rust regex crate).

  ## Examples

      {:ok, query} = SearchTantivy.Query.regex(index_ref, :slug, "elixir-.*")

  """
  @spec regex(reference(), atom(), String.t()) :: {:ok, t()} | {:error, String.t()}
  def regex(index_ref, field, pattern)
      when is_reference(index_ref) and is_atom(field) and is_binary(pattern) do
    SearchTantivy.Native.query_regex(index_ref, Atom.to_string(field), pattern)
  end

  @doc """
  Creates an exists query — matches documents where the field has any value.

  ## Examples

      {:ok, query} = SearchTantivy.Query.exists(index_ref, :category)

  """
  @spec exists(reference(), atom()) :: {:ok, t()} | {:error, String.t()}
  def exists(index_ref, field) when is_reference(index_ref) and is_atom(field) do
    SearchTantivy.Native.query_exists(index_ref, Atom.to_string(field))
  end

  @doc """
  Creates a fuzzy term query with Levenshtein distance.

  Matches terms within `distance` edits of the given value, enabling
  typo-tolerant search (e.g., "hrose" matches "horse" with distance 1).

  ## Options

    * `distance` - maximum edit distance, 0-2 (default: 1)
    * `transpose_costs_one` - whether transpositions count as one edit (default: true)

  ## Examples

      {:ok, query} = SearchTantivy.Query.fuzzy_term(index_ref, :title, "hrose", 1)

  """
  @spec fuzzy_term(reference(), atom(), String.t(), keyword()) ::
          {:ok, t()} | {:error, String.t()}
  def fuzzy_term(index_ref, field, value, opts \\ [])
      when is_reference(index_ref) and is_atom(field) and is_binary(value) do
    distance = Keyword.get(opts, :distance, 1)
    transpose = Keyword.get(opts, :transpose_costs_one, true)

    SearchTantivy.Native.query_fuzzy_term(
      index_ref,
      Atom.to_string(field),
      value,
      distance,
      transpose
    )
  end
end
