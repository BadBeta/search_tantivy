defmodule SearchTantivy do
  @moduledoc """
  Full-text search powered by [tantivy](https://github.com/quickwit-oss/tantivy).

  SearchTantivy provides an idiomatic Elixir interface to the tantivy search engine
  via Rust NIFs. It supports schema-based indexing, rich query construction,
  snippets with highlighting, and supervised index lifecycle management.

  ## Quick Start

      schema = SearchTantivy.Schema.build!([
        {:title, :text, stored: true},
        {:body, :text, stored: true},
        {:url, :string, stored: true, indexed: true}
      ])

      {:ok, index} = SearchTantivy.create_index(:blog, schema, path: "/tmp/blog_index")

      :ok = SearchTantivy.Index.add_documents(index, [
        %{title: "Hello World", body: "First post", url: "/hello"},
        %{title: "Elixir Search", body: "tantivy is fast", url: "/search"}
      ])

      :ok = SearchTantivy.Index.commit(index)

      {:ok, results} = SearchTantivy.search(index, "hello", limit: 10)

  ## Architecture

  ```mermaid
  graph TB
      subgraph "User API (Pure Functional)"
          Schema["SearchTantivy.Schema"]
          Doc["SearchTantivy.Document"]
          Query["SearchTantivy.Query"]
          Facade["SearchTantivy"]
      end

      subgraph "OTP Layer"
          Index["SearchTantivy.Index<br/>GenServer"]
          DynSup["SearchTantivy.IndexSupervisor"]
          Reg["SearchTantivy.IndexRegistry"]
      end

      subgraph "NIF Boundary"
          Native["SearchTantivy.Native"]
      end

      Facade --> Index
      Facade --> Query
      Schema --> Native
      Doc --> Native
      Query --> Native
      Index --> Native
      Index -.->|registered via| Reg
      DynSup -->|supervises| Index
  ```
  """

  @doc """
  Creates a new index with the given name, schema, and options.

  ## Options

    * `:path` - directory path for persistent storage. If omitted, creates
      an in-memory (RAM) index.
    * `:memory_budget` - writer memory budget in bytes. Defaults to 50MB.

  ## Examples

      schema = SearchTantivy.Schema.build!([{:title, :text, stored: true}])
      {:ok, index} = SearchTantivy.create_index(:my_index, schema)

  """
  @spec create_index(atom(), SearchTantivy.Schema.t(), keyword()) ::
          {:ok, GenServer.server()} | {:error, term()}
  defdelegate create_index(name, schema, opts \\ []), to: SearchTantivy.Index, as: :create

  @doc """
  Opens an existing index from the given path.

  ## Examples

      {:ok, index} = SearchTantivy.open_index(:my_index, "/tmp/my_index")

  """
  @spec open_index(atom(), String.t()) :: {:ok, GenServer.server()} | {:error, term()}
  defdelegate open_index(name, path), to: SearchTantivy.Index, as: :open

  @doc """
  Searches an index with a query string or pre-built query.

  The first argument can be an index name (atom), pid, or via tuple.
  The second argument can be a query string or a query reference
  built with `SearchTantivy.Query.*` functions.

  Delegates to `SearchTantivy.Searcher.search/3`. See that module for full
  documentation of available options.

  ## Examples

      # By name with query string
      {:ok, results} = SearchTantivy.search(:my_index, "hello world", limit: 10)

      # By pid with query string
      {:ok, results} = SearchTantivy.search(index, "hello world", limit: 10)

      # With a pre-built query object
      {:ok, query} = SearchTantivy.Query.boolean_query([
        {:must, title_q},
        {:should, body_q}
      ])
      {:ok, results} = SearchTantivy.search(:my_index, query, limit: 10)

      # Boolean shorthand — keyword list of {occur, query_string}
      {:ok, results} = SearchTantivy.search(:my_index,
        [must: "elixir", must: "phoenix"],
        limit: 10
      )

  """
  @spec search(atom() | GenServer.server(), String.t() | reference() | keyword(), keyword()) ::
          {:ok, [SearchTantivy.Searcher.search_result()]} | {:error, term()}
  defdelegate search(index, query_or_string, opts \\ []), to: SearchTantivy.Searcher

  @doc """
  Runs aggregations on a named index.

  Delegates to `SearchTantivy.Aggregation.aggregate/3`. See that module
  for builder functions and full documentation.

  ## Examples

      alias SearchTantivy.Aggregation

      {:ok, result} = SearchTantivy.aggregate(:products, %{
        "by_category" => Aggregation.terms(:category),
        "avg_price" => Aggregation.avg(:price)
      })

      # With query filter
      {:ok, result} = SearchTantivy.aggregate(:products, %{
        "price_stats" => Aggregation.stats(:price)
      }, query: "laptop")

  """
  @spec aggregate(atom(), map(), keyword()) :: {:ok, map()} | {:error, term()}
  defdelegate aggregate(index_name, aggregations, opts \\ []), to: SearchTantivy.Aggregation
end
