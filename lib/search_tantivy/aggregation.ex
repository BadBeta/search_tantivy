defmodule SearchTantivy.Aggregation do
  @moduledoc """
  Build and execute aggregations on search results.

  Aggregations compute statistics, histograms, and groupings over matched
  documents. Uses Elasticsearch-compatible JSON format under the hood.

  **Important:** Aggregation fields must be configured as fast fields
  (`:fast` option) in the schema.

  ## Aggregation Types

  ### Bucket Aggregations (grouping)

  | Function | Description |
  |----------|-------------|
  | `terms/2` | Group by unique field values |
  | `histogram/3` | Group numeric values into fixed-width buckets |
  | `range/2` | Group by custom value ranges |
  | `date_histogram/3` | Group dates into time intervals |

  ### Metric Aggregations (statistics)

  | Function | Description |
  |----------|-------------|
  | `avg/1` | Average value |
  | `min/1` | Minimum value |
  | `max/1` | Maximum value |
  | `sum/1` | Sum of values |
  | `stats/1` | Count, min, max, avg, sum |
  | `percentiles/2` | Value distribution percentiles |
  | `count/1` | Document count |

  ## Examples

      # Simple — aggregate all documents in an index
      alias SearchTantivy.Aggregation

      {:ok, result} = Aggregation.aggregate(:my_index, %{
        "by_category" => Aggregation.terms(:category, size: 10),
        "avg_price" => Aggregation.avg(:price)
      })

      # With a query filter — only aggregate matching documents
      {:ok, result} = Aggregation.aggregate(:my_index, %{
        "price_stats" => Aggregation.stats(:price)
      }, query: "laptop")

      # Histogram with nested metric
      {:ok, result} = Aggregation.aggregate(:my_index, %{
        "price_hist" => Aggregation.histogram(:price, 50.0,
          aggs: %{"avg_rating" => Aggregation.avg(:rating)}
        )
      })

      # Range aggregation
      {:ok, result} = Aggregation.aggregate(:my_index, %{
        "price_ranges" => Aggregation.range(:price, [
          %{to: 100.0},
          %{from: 100.0, to: 500.0},
          %{from: 500.0}
        ])
      })

  """

  @doc """
  Run aggregations on a named index.

  This is the primary entry point. Pass the index name (atom) and a map
  of aggregation definitions. By default aggregates over all documents;
  use `:query` to filter, `:fields` to specify which fields to search.

  ## Options

    * `:query` - query string to filter documents (default: match all)
    * `:fields` - list of field atoms to search (default: all text fields)

  ## Examples

      alias SearchTantivy.Aggregation

      # All documents
      {:ok, result} = Aggregation.aggregate(:products, %{
        "by_category" => Aggregation.terms(:category)
      })

      # Filtered by query
      {:ok, result} = Aggregation.aggregate(:products, %{
        "avg_price" => Aggregation.avg(:price)
      }, query: "laptop")

  """
  @spec aggregate(atom(), map(), keyword()) :: {:ok, map()} | {:error, term()}
  def aggregate(index_name, aggregations, opts \\ []) when is_atom(index_name) and is_map(aggregations) do
    via = SearchTantivy.IndexRegistry.via(index_name)

    with {:ok, reader} <- SearchTantivy.Index.reader(via),
         {:ok, query} <- build_query(via, opts) do
      search(reader, query, aggregations)
    end
  end

  defp build_query(via, opts) do
    case Keyword.get(opts, :query) do
      nil ->
        SearchTantivy.Query.all_query()

      query_string when is_binary(query_string) ->
        with {:ok, index_ref} <- SearchTantivy.Index.index_ref(via) do
          fields = Keyword.get(opts, :fields, [])
          SearchTantivy.Query.parse(index_ref, query_string, fields)
        end
    end
  end

  @doc """
  Execute aggregations against a reader and query reference (low-level).

  For most use cases, prefer `aggregate/3` which handles reader/query
  setup automatically.

  ## Examples

      {:ok, result} = SearchTantivy.Aggregation.search(reader, query, %{
        "by_category" => SearchTantivy.Aggregation.terms(:category, size: 10)
      })

  """
  @spec search(reference(), reference(), map()) :: {:ok, map()} | {:error, String.t()}
  def search(reader, query, aggregations) when is_map(aggregations) do
    json = Jason.encode!(aggregations)

    case SearchTantivy.Native.search_with_aggs(reader, query, json) do
      {:ok, result_json} -> {:ok, Jason.decode!(result_json)}
      {:error, _} = error -> error
    end
  end

  # --- Bucket Aggregations ---

  @doc """
  Creates a terms aggregation to group by unique field values.

  ## Options

    * `:size` - maximum number of buckets (default: 10)
    * `:order` - sort order, `%{"_count" => "desc"}` (default)
    * `:aggs` - nested sub-aggregations

  ## Examples

      SearchTantivy.Aggregation.terms(:category, size: 20)

  """
  @spec terms(atom(), keyword()) :: map()
  def terms(field, opts \\ []) do
    size = Keyword.get(opts, :size, 10)
    sub_aggs = Keyword.get(opts, :aggs)

    agg = %{"terms" => %{"field" => to_string(field), "size" => size}}

    agg
    |> maybe_add_order(Keyword.get(opts, :order))
    |> maybe_add_sub_aggs(sub_aggs)
  end

  @doc """
  Creates a histogram aggregation with fixed-width buckets.

  ## Options

    * `:aggs` - nested sub-aggregations
    * `:min_doc_count` - minimum documents per bucket (default: 0)

  ## Examples

      SearchTantivy.Aggregation.histogram(:price, 50.0)

  """
  @spec histogram(atom(), number(), keyword()) :: map()
  def histogram(field, interval, opts \\ []) do
    hist = %{"field" => to_string(field), "interval" => interval}

    hist =
      case Keyword.get(opts, :min_doc_count) do
        nil -> hist
        count -> Map.put(hist, "min_doc_count", count)
      end

    %{"histogram" => hist}
    |> maybe_add_sub_aggs(Keyword.get(opts, :aggs))
  end

  @doc """
  Creates a range aggregation with custom value ranges.

  Each range is a map with optional `:from` and `:to` keys.

  ## Options

    * `:aggs` - nested sub-aggregations

  ## Examples

      SearchTantivy.Aggregation.range(:price, [
        %{to: 100.0},
        %{from: 100.0, to: 500.0},
        %{from: 500.0}
      ])

  """
  @spec range(atom(), [map()], keyword()) :: map()
  def range(field, ranges, opts \\ []) when is_list(ranges) do
    range_maps =
      Enum.map(ranges, fn range ->
        Map.new(range, fn {k, v} -> {to_string(k), v} end)
      end)

    %{"range" => %{"field" => to_string(field), "ranges" => range_maps}}
    |> maybe_add_sub_aggs(Keyword.get(opts, :aggs))
  end

  @doc """
  Creates a date histogram aggregation.

  ## Intervals

  Supported fixed intervals: `"1s"`, `"1m"`, `"1h"`, `"1d"`, etc.

  ## Examples

      SearchTantivy.Aggregation.date_histogram(:timestamp, "1d")

  """
  @spec date_histogram(atom(), String.t(), keyword()) :: map()
  def date_histogram(field, interval, opts \\ []) do
    %{
      "date_histogram" => %{
        "field" => to_string(field),
        "fixed_interval" => interval
      }
    }
    |> maybe_add_sub_aggs(Keyword.get(opts, :aggs))
  end

  # --- Metric Aggregations ---

  @doc "Average value of a numeric field."
  @spec avg(atom()) :: map()
  def avg(field), do: %{"avg" => %{"field" => to_string(field)}}

  @doc "Minimum value of a numeric field."
  @spec min(atom()) :: map()
  def min(field), do: %{"min" => %{"field" => to_string(field)}}

  @doc "Maximum value of a numeric field."
  @spec max(atom()) :: map()
  def max(field), do: %{"max" => %{"field" => to_string(field)}}

  @doc "Sum of a numeric field."
  @spec sum(atom()) :: map()
  def sum(field), do: %{"sum" => %{"field" => to_string(field)}}

  @doc "Count of documents (uses value_count)."
  @spec count(atom()) :: map()
  def count(field), do: %{"value_count" => %{"field" => to_string(field)}}

  @doc """
  Statistical summary: count, min, max, avg, sum.
  """
  @spec stats(atom()) :: map()
  def stats(field), do: %{"stats" => %{"field" => to_string(field)}}

  @doc """
  Percentile values of a numeric field.

  ## Examples

      SearchTantivy.Aggregation.percentiles(:response_time, [25.0, 50.0, 75.0, 95.0, 99.0])

  """
  @spec percentiles(atom(), [float()]) :: map()
  def percentiles(field, percents \\ [1.0, 5.0, 25.0, 50.0, 75.0, 95.0, 99.0]) do
    %{"percentiles" => %{"field" => to_string(field), "percents" => percents}}
  end

  # --- Private Helpers ---

  defp maybe_add_order(agg, nil), do: agg

  defp maybe_add_order(agg, order) do
    put_in(agg, [Access.key("terms"), "order"], order)
  end

  defp maybe_add_sub_aggs(agg, nil), do: agg
  defp maybe_add_sub_aggs(agg, sub_aggs) when is_map(sub_aggs), do: Map.put(agg, "aggs", sub_aggs)
end
