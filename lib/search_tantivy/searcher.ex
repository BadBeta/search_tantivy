defmodule SearchTantivy.Searcher do
  @moduledoc """
  Execute searches. Stateless — no process needed.

  The searcher obtains a reader from the index, parses the query,
  and collects results. It never manages state — each search is
  an independent operation.

  ## Options

    * `:limit` - maximum results to return (default: 10)
    * `:offset` - number of results to skip (default: 0)
    * `:fields` - list of fields to search (default: all text fields)
    * `:highlight` - list of fields to generate snippets for (default: [])

  ## Examples

      # Simple text search (by pid or via tuple)
      {:ok, results} = SearchTantivy.search(index, "hello world", limit: 10)

      # Name-based search (no pid needed)
      {:ok, results} = SearchTantivy.search(:my_index, "hello world", limit: 10)

      # Search with a pre-built query object
      {:ok, query} = SearchTantivy.Query.boolean_query([
        {:must, title_q},
        {:should, body_q}
      ])
      {:ok, results} = SearchTantivy.search(:my_index, query, limit: 10)

      # With highlighting
      {:ok, results} = SearchTantivy.search(:my_index, "hello",
        limit: 10, highlight: [:title, :body]
      )

  """

  @type search_result :: %{
          score: float(),
          doc: map(),
          highlights: map()
        }

  @valid_opts [limit: 10, offset: 0, fields: [], highlight: []]

  @doc """
  Searches a named index with a query string or pre-built query.

  The first argument can be an index name (atom) or a pid/via tuple.
  The second argument can be a query string or a query reference
  built with `SearchTantivy.Query.*` functions.

  See module documentation for available options.
  """
  @spec search(atom() | SearchTantivy.Index.t(), String.t() | reference(), keyword()) ::
          {:ok, [search_result()]} | {:error, term()}
  def search(index_or_name, query_or_string, opts \\ [])

  def search(index_name, query_or_string, opts) when is_atom(index_name) do
    via = SearchTantivy.IndexRegistry.via(index_name)
    search(via, query_or_string, opts)
  end

  def search(index, query_string, opts) when is_binary(query_string) do
    opts = Keyword.validate!(opts, @valid_opts)

    with {:ok, reader_ref} <- SearchTantivy.Index.reader(index),
         {:ok, index_ref} <- SearchTantivy.Index.index_ref(index),
         {:ok, query_ref} <- SearchTantivy.Query.parse(index_ref, query_string, opts[:fields]) do
      execute_search(reader_ref, query_ref, opts)
    end
  end

  def search(index, query_ref, opts) when is_reference(query_ref) do
    opts = Keyword.validate!(opts, @valid_opts)

    with {:ok, reader_ref} <- SearchTantivy.Index.reader(index) do
      execute_search(reader_ref, query_ref, opts)
    end
  end

  def search(index, clauses, opts) when is_list(clauses) and clauses != [] do
    opts = Keyword.validate!(opts, @valid_opts)
    resolved = resolve(index)

    with {:ok, index_ref} <- SearchTantivy.Index.index_ref(resolved),
         {:ok, reader_ref} <- SearchTantivy.Index.reader(resolved),
         {:ok, query_ref} <- build_boolean_from_clauses(index_ref, clauses, opts[:fields]) do
      execute_search(reader_ref, query_ref, opts)
    end
  end

  defp execute_search(reader_ref, query_ref, opts) do
    case opts[:highlight] do
      [] ->
        search_without_snippets(reader_ref, query_ref, opts[:limit], opts[:offset])

      highlight_fields ->
        snippet_field_strings = Enum.map(highlight_fields, &Atom.to_string/1)

        search_with_snippets(
          reader_ref,
          query_ref,
          opts[:limit],
          opts[:offset],
          snippet_field_strings
        )
    end
  end

  defp search_without_snippets(reader_ref, query_ref, limit, offset) do
    with {:ok, raw_results} <- SearchTantivy.Native.search(reader_ref, query_ref, limit, offset) do
      results =
        Enum.map(raw_results, fn {score, field_pairs} ->
          %{score: score, doc: Map.new(field_pairs), highlights: %{}}
        end)

      {:ok, results}
    end
  end

  defp search_with_snippets(reader_ref, query_ref, limit, offset, snippet_fields) do
    with {:ok, raw_results} <-
           SearchTantivy.Native.search_with_snippets(
             reader_ref,
             query_ref,
             limit,
             offset,
             snippet_fields
           ) do
      results =
        Enum.map(raw_results, fn {score, field_pairs, snippet_pairs} ->
          %{
            score: score,
            doc: Map.new(field_pairs),
            highlights: atomize_keys(snippet_pairs)
          }
        end)

      {:ok, results}
    end
  end

  defp atomize_keys(pairs) do
    Map.new(pairs, fn {k, v} -> {String.to_existing_atom(k), v} end)
  end

  defp resolve(index_name) when is_atom(index_name),
    do: SearchTantivy.IndexRegistry.via(index_name)

  defp resolve(index), do: index

  defp build_boolean_from_clauses(index_ref, clauses, fields) do
    clauses
    |> Enum.reduce_while([], fn {occur, query_string}, acc ->
      case parse_clause_value(index_ref, query_string, fields) do
        {:ok, query_ref} -> {:cont, [{occur, query_ref} | acc]}
        {:error, _} = error -> {:halt, error}
      end
    end)
    |> case do
      {:error, _} = error -> error
      parsed when is_list(parsed) -> SearchTantivy.Query.boolean_query(Enum.reverse(parsed))
    end
  end

  defp parse_clause_value(index_ref, query_string, fields) when is_binary(query_string) do
    SearchTantivy.Query.parse(index_ref, query_string, fields)
  end

  defp parse_clause_value(_index_ref, query_ref, _fields) when is_reference(query_ref) do
    {:ok, query_ref}
  end
end
