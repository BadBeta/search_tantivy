# SearchTantivy — LLM Programming Guide

Full-text search library for Elixir powered by tantivy (Rust) via NIFs.
This guide is structured for LLM code generation — rules, decision frameworks, and complete examples.

## Rules for Using SearchTantivy (LLM)

1. **ALWAYS commit after adding documents.** Documents added via `add_documents/2` are buffered in the writer. They are NOT searchable until `commit/1` is called. Forgetting to commit is the most common mistake.

2. **ALWAYS match return types correctly.** Three conventions:
   - `{:ok, value}` — `create_index`, `open_index`, `search`, `Schema.build`, `Query.*`, `Index.reader`, `Index.index_ref`, `Index.schema_ref`
   - `:ok | {:error, reason}` — `Index.add_documents`, `Index.delete_documents`, `Index.commit`, `Tokenizer.register`
   - `:ok` (infallible) — `Index.close`

3. **ALWAYS use atom keys in document maps, but expect string keys in results.** Documents are passed in with atom keys (`%{title: "Hello"}`), but search results return string keys (`%{"title" => "Hello"}`). This is because field names cross the NIF boundary as strings.

4. **ALWAYS use `stored: true` on fields you want returned in search results.** Fields without `stored: true` are indexed (searchable) but their values are not retrievable. If you search and get empty docs, check your schema.

5. **ALWAYS use `SearchTantivy.search/3` for all searches.** It accepts query strings, pre-built query objects, and keyword list boolean shorthand. Build complex queries with `SearchTantivy.Query.*` and pass them to `search/3` — do not use `SearchTantivy.Native.search/4` directly.

6. **ALWAYS start `SearchTantivy.Application` before using supervised indexes.** Add it to your application's supervision tree, or call `SearchTantivy.Application.start(:normal, [])` in scripts/tests. Without it, `create_index/3` fails because the Registry and DynamicSupervisor don't exist.

7. **NEVER use `SearchTantivy.Index.create/3` without a running supervision tree.** For unsupervised usage (tests, scripts), use `SearchTantivy.Index.start_link/1` directly instead.

8. **ALWAYS use `:text` for full-text searchable content and `:string` for exact-match filters.** `:text` fields are tokenized (split into words, lowercased). `:string` fields are indexed as-is for exact matching. Using `:string` for prose means searches won't find individual words.

9. **PREFER in-memory indexes for tests.** Omit the `:path` option to create a RAM index — faster, no cleanup needed, automatically isolated per test.

10. **ALWAYS use unique names for indexes in concurrent tests.** Use `:"test_#{System.unique_integer([:positive])}"` to avoid Registry name conflicts with `async: true`.

11. **NEVER assume NIF errors will crash the BEAM.** All Rust NIFs are wrapped with `catch_unwind` — panics are converted to `{:error, "NIF panic: ..."}` tuples. Always handle errors with normal `{:ok, _}` / `{:error, _}` pattern matching. A crashed GenServer is automatically restarted by the supervision tree.

## Field Type Decision Guide

| Data | Type | Why |
|------|------|-----|
| Article body, product description | `:text` | Needs tokenization for word-level search |
| Category slug, user ID, URL | `:string` | Exact match, no word splitting |
| Price, count, quantity | `:u64` or `:i64` | Numeric range queries, sorting |
| Score, rating, weight | `:f64` | Floating-point range queries |
| Is active, is published | `:bool` | Boolean filtering |
| Created at, published date | `:date` | Date range queries (pass as ISO 8601 string) |
| Tags, breadcrumbs | `:facet` | Hierarchical filtering (`"/electronics/phones"`) |
| Arbitrary nested data | `:json` | Structured data you want searchable |
| IP address | `:ip_addr` | IP filtering and range queries |

## Query Type Decision Guide

| Need | Use | Example |
|------|-----|---------|
| User typed a search box query | `SearchTantivy.search/3` | `SearchTantivy.search(index, "elixir tutorial")` |
| Search specific fields only | `search/3` with `:fields` | `search(index, "elixir", fields: [:title])` |
| Highlight matches in results | `search/3` with `:highlight` | `search(index, "elixir", highlight: [:title, :body])` |
| Exact value filter (category, status) | `Query.term_query/3` | `Query.term_query(index_ref, :status, "published")` |
| Combine multiple conditions | `Query.boolean_query/1` | Must match title AND should match body |
| Boost one field over another | `Query.boost/2` | Title matches score 2x higher |
| Get all documents | `Query.all_query/0` | Browse/list all indexed content |
| Range query (price, date) | `Query.parse/3` with syntax | `Query.parse(ref, "price:[10 TO 100]")` |
| Paginate results | `search/3` with `:limit`/`:offset` | `search(index, "q", limit: 20, offset: 40)` |

## API Quick Reference

### Schema (Pure Functional)

```elixir
# Build with ok/error tuple
{:ok, schema} = SearchTantivy.Schema.build([
  {:title, :text, stored: true},
  {:body, :text, stored: true},
  {:category, :string, stored: true, indexed: true},
  {:price, :u64, stored: true, fast: true}
])

# Build with bang (raises on error)
schema = SearchTantivy.Schema.build!([
  {:title, :text, stored: true},
  {:body, :text, stored: true}
])
```

### Index Lifecycle (GenServer)

```elixir
# Create supervised index (requires SearchTantivy.Application running)
{:ok, index} = SearchTantivy.create_index(:my_index, schema)
{:ok, index} = SearchTantivy.create_index(:my_index, schema, path: "/tmp/my_index")

# Create unsupervised index (scripts, tests)
{:ok, index} = SearchTantivy.Index.start_link(name: :test, schema: schema)

# Open existing index from disk
{:ok, index} = SearchTantivy.open_index(:my_index, "/tmp/my_index")

# Add documents (buffered, not yet searchable)
:ok = SearchTantivy.Index.add_documents(index, [
  %{title: "First Post", body: "Hello world", category: "blog", price: 0},
  %{title: "Second Post", body: "More content", category: "blog", price: 10}
])

# Commit (makes documents searchable)
:ok = SearchTantivy.Index.commit(index)

# Delete documents by field value
:ok = SearchTantivy.Index.delete_documents(index, :category, "spam")
:ok = SearchTantivy.Index.commit(index)  # Must commit after delete too

# Close gracefully (commits pending changes)
:ok = SearchTantivy.Index.close(index)
```

### Search

```elixir
# Simple text search
{:ok, results} = SearchTantivy.search(index, "hello world", limit: 10)

# Search by index name (atom)
{:ok, results} = SearchTantivy.search(:my_index, "hello", limit: 10)

# Search specific fields
{:ok, results} = SearchTantivy.search(index, "hello", fields: [:title])

# Search with highlighting (atom keys in highlights)
{:ok, results} = SearchTantivy.search(index, "hello",
  highlight: [:title, :body],
  limit: 20,
  offset: 0
)

# Boolean shorthand — keyword list
{:ok, results} = SearchTantivy.search(index, [must: "elixir", must_not: "spam"], limit: 10)

# Pre-built query objects
{:ok, results} = SearchTantivy.search(index, combined_query_ref, limit: 10)

# Add and commit in one step
:ok = SearchTantivy.Index.add_and_commit(index, [%{title: "New Post"}])

# Results: [%{score: 1.5, doc: %{"title" => "Hello"}, highlights: %{title: "<b>Hello</b>"}}]
```

### Query Building (Pure Functional)

```elixir
# Get index_ref for query construction
{:ok, index_ref} = SearchTantivy.Index.index_ref(index)

# Parse a query string
{:ok, query} = SearchTantivy.Query.parse(index_ref, "hello world")
{:ok, query} = SearchTantivy.Query.parse(index_ref, "hello", [:title])

# Exact term query
{:ok, query} = SearchTantivy.Query.term_query(index_ref, :category, "blog")

# Boolean query — combine conditions
{:ok, title_q} = SearchTantivy.Query.parse(index_ref, "elixir", [:title])
{:ok, body_q} = SearchTantivy.Query.parse(index_ref, "tutorial", [:body])
{:ok, spam_q} = SearchTantivy.Query.term_query(index_ref, :category, "spam")

{:ok, combined} = SearchTantivy.Query.boolean_query([
  {:must, title_q},
  {:should, body_q},
  {:must_not, spam_q}
])

# Boost query relevance
{:ok, boosted} = SearchTantivy.Query.boost(title_q, 2.0)

# All documents
{:ok, all} = SearchTantivy.Query.all_query()

# Execute any query via search/3
{:ok, results} = SearchTantivy.search(index, combined, limit: 10)

# Or use keyword list boolean shorthand (no query building needed)
{:ok, results} = SearchTantivy.search(index, [must: "elixir", must_not: "spam"], limit: 10)
```

### Tokenizer Registration

```elixir
{:ok, index_ref} = SearchTantivy.Index.index_ref(index)

# Register built-in tokenizers
:ok = SearchTantivy.Tokenizer.register(index_ref, :en_stem)    # English stemming
:ok = SearchTantivy.Tokenizer.register(index_ref, :whitespace) # Split on whitespace
:ok = SearchTantivy.Tokenizer.register(index_ref, :raw)        # No tokenization
:ok = SearchTantivy.Tokenizer.register(index_ref, :default)    # Unicode-aware, lowercase
```

## Common Mistakes (BAD/GOOD)

### Forgetting to commit

```elixir
# BAD: documents never become searchable
:ok = SearchTantivy.Index.add_documents(index, [%{title: "Hello"}])
{:ok, results} = SearchTantivy.search(index, "hello")
# results == [] — documents are still buffered!

# GOOD: commit makes documents searchable
:ok = SearchTantivy.Index.add_documents(index, [%{title: "Hello"}])
:ok = SearchTantivy.Index.commit(index)
{:ok, results} = SearchTantivy.search(index, "hello")
# results == [%{score: _, doc: %{"title" => "Hello"}, highlights: %{}}]
```

### Wrong return type matching

```elixir
# BAD: add_documents returns :ok, not {:ok, _}
{:ok, _} = SearchTantivy.Index.add_documents(index, docs)  # MatchError!

# GOOD: side-effect operations return bare :ok
:ok = SearchTantivy.Index.add_documents(index, docs)
:ok = SearchTantivy.Index.commit(index)

# BAD: search returns {:ok, results}, not bare results
results = SearchTantivy.search(index, "hello")  # results is {:ok, [...]}

# GOOD: pattern match the ok tuple
{:ok, results} = SearchTantivy.search(index, "hello")
```

### Using string keys in document maps

```elixir
# BAD: string keys in documents
:ok = SearchTantivy.Index.add_documents(index, [
  %{"title" => "Hello"}  # Will fail or produce unexpected results
])

# GOOD: atom keys in documents
:ok = SearchTantivy.Index.add_documents(index, [
  %{title: "Hello"}
])
```

### Expecting atom keys in search results

```elixir
# BAD: results use string keys, not atoms
{:ok, [result | _]} = SearchTantivy.search(index, "hello")
title = result.doc.title  # KeyError — doc is a map with string keys

# GOOD: access with string keys
{:ok, [result | _]} = SearchTantivy.search(index, "hello")
title = result.doc["title"]
```

### Missing stored: true

```elixir
# BAD: field is searchable but value not returned in results
schema = SearchTantivy.Schema.build!([
  {:title, :text}  # stored defaults to false
])
# After indexing and searching: doc == %{} — empty!

# GOOD: stored: true makes values retrievable
schema = SearchTantivy.Schema.build!([
  {:title, :text, stored: true}
])
# After indexing and searching: doc == %{"title" => "Hello World"}
```

### Using :string for full-text content

```elixir
# BAD: :string is not tokenized — only exact match works
schema = SearchTantivy.Schema.build!([
  {:body, :string, stored: true}  # Will only match exact full string
])
# Searching for "hello" won't find "hello world"

# GOOD: :text is tokenized for full-text search
schema = SearchTantivy.Schema.build!([
  {:body, :text, stored: true}
])
# Searching for "hello" finds "hello world", "say hello", etc.
```

### Searching with composed queries

```elixir
# GOOD: pass pre-built query objects directly to search/3
{:ok, index_ref} = SearchTantivy.Index.index_ref(index)

{:ok, q1} = SearchTantivy.Query.parse(index_ref, "elixir", [:title])
{:ok, boosted} = SearchTantivy.Query.boost(q1, 2.0)
{:ok, q2} = SearchTantivy.Query.parse(index_ref, "tutorial", [:body])
{:ok, combined} = SearchTantivy.Query.boolean_query([{:must, boosted}, {:should, q2}])

{:ok, results} = SearchTantivy.search(index, combined, limit: 10)

# GOOD: keyword list boolean shorthand for simple cases
{:ok, results} = SearchTantivy.search(index, [must: "elixir", must_not: "spam"], limit: 10)
```

### Creating indexes without supervision tree

```elixir
# BAD: create_index requires SearchTantivy.Application running
{:ok, index} = SearchTantivy.create_index(:blog, schema)
# Crashes if Application not started

# GOOD (production): add to your supervision tree
# In your Application module:
children = [
  SearchTantivy.Application,  # or add its children directly
  # ... your other children
]

# GOOD (tests/scripts): use start_link directly
{:ok, index} = SearchTantivy.Index.start_link(name: :test, schema: schema)
```

## Complete Working Examples

### Example 1: Blog Search with Highlighting

```elixir
# Start supervision (in test/script context)
SearchTantivy.Application.start(:normal, [])

# Define schema
schema = SearchTantivy.Schema.build!([
  {:title, :text, stored: true},
  {:body, :text, stored: true},
  {:author, :string, stored: true, indexed: true},
  {:published, :bool, stored: true}
])

# Create index
{:ok, index} = SearchTantivy.create_index(:blog, schema)

# Index some posts
posts = [
  %{title: "Getting Started with Elixir", body: "Elixir is a dynamic, functional language for building scalable applications.", author: "jose", published: true},
  %{title: "Phoenix LiveView Tutorial", body: "LiveView enables rich, real-time user experiences with server-rendered HTML.", author: "chris", published: true},
  %{title: "Draft: OTP Patterns", body: "Supervision trees and GenServers are the backbone of fault-tolerant systems.", author: "jose", published: false}
]

:ok = SearchTantivy.Index.add_documents(index, posts)
:ok = SearchTantivy.Index.commit(index)

# Search with highlighting
{:ok, results} = SearchTantivy.search(index, "elixir",
  highlight: [:title, :body],
  limit: 10
)

for result <- results do
  IO.puts("Score: #{result.score}")
  IO.puts("Title: #{result.doc["title"]}")
  IO.puts("Highlight: #{result.highlights[:title]}")
  IO.puts("---")
end
```

### Example 2: Product Catalog with Faceted Filtering

```elixir
schema = SearchTantivy.Schema.build!([
  {:name, :text, stored: true},
  {:description, :text, stored: true},
  {:category, :string, stored: true, indexed: true},
  {:price, :u64, stored: true, fast: true},
  {:in_stock, :bool, stored: true}
])

{:ok, index} = SearchTantivy.create_index(:products, schema)

products = [
  %{name: "Mechanical Keyboard", description: "Cherry MX Blue switches, RGB backlit", category: "electronics", price: 89, in_stock: true},
  %{name: "Ergonomic Mouse", description: "Vertical design reduces wrist strain", category: "electronics", price: 45, in_stock: true},
  %{name: "Standing Desk", description: "Electric height adjustable desk", category: "furniture", price: 599, in_stock: false}
]

:ok = SearchTantivy.Index.add_documents(index, products)
:ok = SearchTantivy.Index.commit(index)

# Simple text search
{:ok, results} = SearchTantivy.search(index, "keyboard", limit: 10)

# Filter by category AND search text
{:ok, index_ref} = SearchTantivy.Index.index_ref(index)

{:ok, text_q} = SearchTantivy.Query.parse(index_ref, "ergonomic")
{:ok, cat_q} = SearchTantivy.Query.term_query(index_ref, :category, "electronics")

{:ok, filtered} = SearchTantivy.Query.boolean_query([
  {:must, text_q},
  {:must, cat_q}
])

{:ok, results} = SearchTantivy.search(index, filtered, limit: 10)
```

### Example 3: Phoenix Context Integration

```elixir
defmodule MyApp.Search do
  @moduledoc "Search context — wraps SearchTantivy for application use."

  @doc "Initializes the search index. Call from Application.start/2."
  def start_index do
    schema = SearchTantivy.Schema.build!([
      {:title, :text, stored: true},
      {:body, :text, stored: true},
      {:slug, :string, stored: true, indexed: true}
    ])

    SearchTantivy.create_index(:articles, schema, path: articles_path())
  end

  @doc "Indexes a single article."
  def index_article(%{title: title, body: body, slug: slug}) do
    with :ok <- SearchTantivy.Index.add_documents(:articles, [
           %{title: title, body: body, slug: slug}
         ]),
         :ok <- SearchTantivy.Index.commit(:articles) do
      :ok
    end
  end

  @doc "Searches articles, returns formatted results."
  def search_articles(query, opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)
    page = Keyword.get(opts, :page, 1)
    offset = (page - 1) * limit

    case SearchTantivy.search(:articles, query,
           limit: limit,
           offset: offset,
           highlight: [:title, :body]
         ) do
      {:ok, results} ->
        {:ok, Enum.map(results, &format_result/1)}

      {:error, _} = error ->
        error
    end
  end

  defp format_result(result) do
    %{
      title: result.doc["title"],
      slug: result.doc["slug"],
      snippet: result.highlights[:body] || String.slice(result.doc["body"] || "", 0, 200),
      score: result.score
    }
  end

  defp articles_path do
    Path.join(Application.app_dir(:my_app, "priv"), "search/articles")
  end
end
```

### Example 4: Test Setup Pattern

```elixir
defmodule MyApp.SearchTest do
  use ExUnit.Case, async: true

  setup do
    # Use unique name for async test isolation
    name = :"search_test_#{System.unique_integer([:positive])}"

    schema = SearchTantivy.Schema.build!([
      {:title, :text, stored: true},
      {:body, :text, stored: true},
      {:category, :string, stored: true, indexed: true}
    ])

    # RAM index — no path, no cleanup needed
    {:ok, index} = SearchTantivy.Index.start_link(name: name, schema: schema)

    # Index test data
    :ok = SearchTantivy.Index.add_documents(index, [
      %{title: "Elixir Guide", body: "Learn functional programming", category: "tech"},
      %{title: "Cooking Tips", body: "Master the art of cooking", category: "food"}
    ])
    :ok = SearchTantivy.Index.commit(index)

    %{index: index}
  end

  test "finds documents by text", %{index: index} do
    {:ok, results} = SearchTantivy.search(index, "elixir")
    assert length(results) == 1
    assert hd(results).doc["title"] == "Elixir Guide"
  end

  test "filters by category", %{index: index} do
    {:ok, index_ref} = SearchTantivy.Index.index_ref(index)

    {:ok, query} = SearchTantivy.Query.term_query(index_ref, :category, "food")
    {:ok, results} = SearchTantivy.search(index, query, limit: 10)

    assert length(results) == 1
    assert hd(results).doc["title"] == "Cooking Tips"
  end

  test "returns empty results for no match", %{index: index} do
    {:ok, results} = SearchTantivy.search(index, "nonexistent_xyz")
    assert results == []
  end

  test "highlighting returns snippets", %{index: index} do
    {:ok, results} = SearchTantivy.search(index, "functional", highlight: [:body])
    assert length(results) == 1
    assert results |> hd() |> Map.get(:highlights) |> Map.get(:body) |> is_binary()
  end
end
```

## Architecture Overview

### Module Responsibilities

| Module | Type | Purpose |
|--------|------|---------|
| `SearchTantivy` | Facade | Top-level API: `create_index`, `open_index`, `search` |
| `SearchTantivy.Schema` | Pure | Build field schemas from tuple lists |
| `SearchTantivy.Query` | Pure | Compose queries: parse, term, boolean, boost, all |
| `SearchTantivy.Searcher` | Pure | Execute searches (stateless, no process) |
| `SearchTantivy.Index` | GenServer | Index lifecycle: add, commit, delete, reader |
| `SearchTantivy.Tokenizer` | Pure | Register built-in tokenizers |
| `SearchTantivy.Native` | NIF | Rust FFI boundary (internal, not for direct use) |
| `SearchTantivy.Application` | Supervisor | Registry + DynamicSupervisor (:one_for_all) |

### Unified Search API

`SearchTantivy.search/3` handles all search needs. It accepts three query forms:

1. **Query string** — `SearchTantivy.search(index, "hello world", limit: 10)`
2. **Pre-built query object** — `SearchTantivy.search(index, query_ref, limit: 10)` (built via `SearchTantivy.Query.*`)
3. **Keyword list boolean shorthand** — `SearchTantivy.search(index, [must: "elixir", must_not: "spam"], limit: 10)`

All forms return `[%{score: float, doc: map, highlights: map}]`. Highlights use atom keys (`:title`), doc uses string keys (`"title"`). Search by index name (atom) or pid.

### Supervision Tree

```
SearchTantivy.Supervisor (:one_for_all)
├── SearchTantivy.IndexRegistry (Registry :unique)
└── SearchTantivy.IndexSupervisor (DynamicSupervisor :one_for_one)
    ├── SearchTantivy.Index :blog_index
    ├── SearchTantivy.Index :product_index
    └── ...
```

Registry starts before DynamicSupervisor (`:one_for_all` ensures both restart if either fails). Library pattern — no `mod:` in `application/0`. Users add `SearchTantivy.Application` to their own supervision tree.

### Crash Resilience — Two-Layer Protection

SearchTantivy prevents BEAM VM crashes through two complementary mechanisms:

**Layer 1 — NIF Panic Catching:** Every Rust NIF entry point is wrapped with `std::panic::catch_unwind`. If tantivy panics (assertion failure, index corruption, unexpected state), the panic is caught and converted to `{:error, "NIF panic: ..."}` instead of crashing the BEAM VM. This is transparent — you handle these like any other error.

**Layer 2 — OTP Supervision:** The `SearchTantivy.Index` GenServer is managed by a DynamicSupervisor. If a GenServer crashes (unexpected message, linked process death), it is automatically restarted. The `:one_for_all` top-level strategy ensures the Registry and DynamicSupervisor stay in sync.

**Error handling pattern:**

```elixir
# NIF panics and normal errors are handled the same way
case SearchTantivy.search(index, query, limit: 10) do
  {:ok, results} -> results
  {:error, "NIF panic: " <> reason} -> Logger.error("Engine error: #{reason}"); []
  {:error, reason} -> Logger.error("Search failed: #{reason}"); []
end
```

**What can go wrong and what happens:**

| Failure | What Happens | Your Code Sees |
|---------|-------------|----------------|
| Rust panic (assertion, OOB) | `catch_unwind` catches it | `{:error, "NIF panic: ..."}` |
| Invalid query syntax | tantivy returns error | `{:error, "query parse error: ..."}` |
| GenServer crash | Supervisor restarts it | Next call works (or `{:error, :noproc}` briefly) |
| Index corruption | tantivy returns error | `{:error, "..."}` on open/search |

### Data Flow

1. Build schema (pure) → returns `reference()`
2. Create index (GenServer) → stores schema, index, writer refs in state
3. Add documents (GenServer call) → converts atom-key maps to string pairs, creates NIF documents, writes to buffer
4. Commit (GenServer call) → flushes buffer to index segments
5. Search (stateless) → gets reader + index refs from GenServer, parses query, executes via NIF, formats results

### Return Type Patterns

```elixir
# Operations that return data — always {:ok, value} | {:error, reason}
{:ok, schema}    = SearchTantivy.Schema.build(fields)
{:ok, index}     = SearchTantivy.create_index(name, schema)
{:ok, results}   = SearchTantivy.search(index, query)
{:ok, query_ref} = SearchTantivy.Query.parse(index_ref, "hello")
{:ok, reader}    = SearchTantivy.Index.reader(index)

# Side-effect operations — bare :ok or {:error, reason}
:ok = SearchTantivy.Index.add_documents(index, docs)
:ok = SearchTantivy.Index.commit(index)
:ok = SearchTantivy.Index.delete_documents(index, :field, "value")
:ok = SearchTantivy.Tokenizer.register(index_ref, :en_stem)

# Infallible operations — always :ok
:ok = SearchTantivy.Index.close(index)
```
