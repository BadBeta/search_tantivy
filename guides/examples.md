# Examples

Three complete, self-contained examples demonstrating common SearchTantivy use cases.
Each can be run in IEx after starting the supervision tree.

## Setup (all examples)

```elixir
# Start the SearchTantivy supervision tree
{:ok, _} = SearchTantivy.Application.start_link()
```

Or add `SearchTantivy.Application` to your application's supervision tree (see [Getting Started](getting_started.md#supervision)).

---

## Example 1: Blog Search with Highlighting

A blog search engine with full-text search, highlighted snippets, and pagination.

```elixir
# 1. Define the schema
schema = SearchTantivy.Schema.build!([
  {:title, :text, stored: true},
  {:body, :text, stored: true},
  {:author, :string, stored: true},
  {:tags, :string, stored: true},
  {:published_at, :date, stored: true, fast: true}
])

# 2. Create a persistent index
{:ok, index} = SearchTantivy.create_index(:blog, schema, path: "/tmp/blog_index")

# 3. Index some articles
:ok = SearchTantivy.Index.add_documents(index, [
  %{
    title: "Getting Started with Elixir",
    body: "Elixir is a dynamic, functional language designed for building scalable
           and maintainable applications. It leverages the Erlang VM, known for
           running low-latency, distributed, and fault-tolerant systems.",
    author: "jose",
    tags: "elixir",
    published_at: "2024-06-15T10:00:00Z"
  },
  %{
    title: "Phoenix LiveView in Production",
    body: "Phoenix LiveView enables rich, real-time user experiences with
           server-rendered HTML. No JavaScript framework required. LiveView
           processes run on the server and push DOM updates over WebSockets.",
    author: "chris",
    tags: "phoenix",
    published_at: "2024-08-20T14:30:00Z"
  },
  %{
    title: "Building NIFs with Rustler",
    body: "Rustler makes it easy to write safe, performant Native Implemented
           Functions (NIFs) for Elixir using Rust. This avoids the traditional
           dangers of C NIFs while providing near-native performance.",
    author: "jose",
    tags: "elixir",
    published_at: "2024-09-05T09:00:00Z"
  },
  %{
    title: "Elixir OTP Design Principles",
    body: "OTP provides a set of libraries and design principles for building
           concurrent, fault-tolerant applications. GenServer, Supervisor, and
           Application are the core building blocks every Elixir developer
           should master.",
    author: "jose",
    tags: "elixir",
    published_at: "2024-10-12T11:00:00Z"
  },
  %{
    title: "Full-Text Search with SearchTantivy",
    body: "SearchTantivy brings the power of tantivy full-text search to Elixir.
           It supports schema-based indexing, boolean queries, highlighting,
           and boosted multi-field search — all through an idiomatic Elixir API.",
    author: "community",
    tags: "elixir",
    published_at: "2024-11-01T08:00:00Z"
  }
])

:ok = SearchTantivy.Index.commit(index)

# 4. Simple search
{:ok, results} = SearchTantivy.search(index, "elixir", limit: 10)

IO.puts("=== Simple Search: 'elixir' ===")
for %{score: score, doc: doc} <- results do
  IO.puts("  [#{Float.round(score, 2)}] #{doc["title"]}")
end

# 5. Search with highlighting
{:ok, results} = SearchTantivy.search(index, "elixir OTP",
  limit: 5,
  highlight: [:title, :body]
)

IO.puts("\n=== Highlighted Search: 'elixir OTP' ===")
for %{doc: doc, highlights: highlights} <- results do
  # Use highlighted title if available, otherwise the raw title
  title = Map.get(highlights, :title, doc["title"])
  body_snippet = Map.get(highlights, :body, "")
  IO.puts("  Title: #{title}")
  if body_snippet != "", do: IO.puts("  Snippet: #{body_snippet}")
  IO.puts("")
end

# 6. Paginated search
page = 1
per_page = 2

{:ok, page_results} = SearchTantivy.search(index, "elixir",
  limit: per_page,
  offset: (page - 1) * per_page
)

IO.puts("=== Page #{page} (#{per_page} per page) ===")
for %{doc: doc} <- page_results do
  IO.puts("  #{doc["title"]}")
end

# 7. Field-specific search (title only)
{:ok, title_only} = SearchTantivy.search(index, "production",
  limit: 10,
  fields: [:title]
)

IO.puts("\n=== Title-only Search: 'production' ===")
for %{doc: doc} <- title_only do
  IO.puts("  #{doc["title"]}")
end

# Cleanup
SearchTantivy.Index.close(index)
File.rm_rf("/tmp/blog_index")
```

---

## Example 2: Product Catalog with Faceted Filtering

An e-commerce product catalog using boolean queries to filter by category, term queries for exact matching, and boosted title search for relevance. All queries go through the unified `SearchTantivy.search/3` API.

```elixir
# 1. Define a product schema
schema = SearchTantivy.Schema.build!([
  {:name, :text, stored: true},
  {:description, :text, stored: true},
  {:category, :string, stored: true},
  {:brand, :string, stored: true},
  {:price_cents, :u64, stored: true, fast: true},
  {:in_stock, :bool, stored: true}
])

# 2. Create index and add products
{:ok, index} = SearchTantivy.create_index(:products, schema)

:ok = SearchTantivy.Index.add_documents(index, [
  %{name: "Mechanical Keyboard", description: "Cherry MX Brown switches, RGB backlight, USB-C",
    category: "electronics", brand: "keychron", price_cents: 8_999, in_stock: true},
  %{name: "Ergonomic Keyboard", description: "Split design, tenting kit, quiet switches",
    category: "electronics", brand: "kinesis", price_cents: 14_999, in_stock: true},
  %{name: "Wireless Mouse", description: "Lightweight ergonomic wireless mouse, USB-C charging",
    category: "electronics", brand: "logitech", price_cents: 6_999, in_stock: false},
  %{name: "Standing Desk", description: "Electric sit-stand desk, memory presets, cable tray",
    category: "furniture", brand: "uplift", price_cents: 59_999, in_stock: true},
  %{name: "Monitor Arm", description: "Gas spring monitor arm, VESA mount, cable management",
    category: "furniture", brand: "ergotron", price_cents: 17_999, in_stock: true},
  %{name: "USB-C Hub", description: "7-in-1 USB-C hub with HDMI, ethernet, and SD card reader",
    category: "electronics", brand: "anker", price_cents: 3_499, in_stock: true}
])

:ok = SearchTantivy.Index.commit(index)

# Get index_ref for query construction
{:ok, index_ref} = SearchTantivy.Index.index_ref(index)

# 3. Filter by category using term query
{:ok, electronics_q} = SearchTantivy.Query.term_query(index_ref, :category, "electronics")
{:ok, electronics} = SearchTantivy.search(index, electronics_q, limit: 10)

IO.puts("=== Electronics Category ===")
for %{doc: doc} <- electronics do
  price = String.to_integer(doc["price_cents"]) / 100
  IO.puts("  #{doc["name"]} — $#{Float.round(price, 2)} (#{doc["brand"]})")
end

# 4. Search with boosted title relevance
#    Title matches are 3x more important than description matches
{:ok, title_q} = SearchTantivy.Query.parse(index_ref, "keyboard", [:name])
{:ok, desc_q} = SearchTantivy.Query.parse(index_ref, "keyboard", [:description])
{:ok, boosted_title} = SearchTantivy.Query.boost(title_q, 3.0)

{:ok, combined} = SearchTantivy.Query.boolean_query([
  {:should, boosted_title},
  {:should, desc_q}
])

{:ok, keyboard_results} = SearchTantivy.search(index, combined, limit: 10)

IO.puts("\n=== Boosted Title Search: 'keyboard' ===")
for %{score: score, doc: doc} <- keyboard_results do
  IO.puts("  [#{Float.round(score, 2)}] #{doc["name"]}")
end

# 5. Complex filter: electronics + "USB-C" in text, exclude out-of-stock
{:ok, cat_q} = SearchTantivy.Query.term_query(index_ref, :category, "electronics")
{:ok, usbc_q} = SearchTantivy.Query.parse(index_ref, "USB-C")
{:ok, out_of_stock_q} = SearchTantivy.Query.term_query(index_ref, :in_stock, "false")

{:ok, filtered} = SearchTantivy.Query.boolean_query([
  {:must, cat_q},
  {:must, usbc_q},
  {:must_not, out_of_stock_q}
])

{:ok, usbc_results} = SearchTantivy.search(index, filtered, limit: 10)

IO.puts("\n=== Electronics + USB-C + In Stock ===")
for %{doc: doc} <- usbc_results do
  IO.puts("  #{doc["name"]} (#{doc["brand"]})")
end

# 6. Match all documents (useful for browsing/sorting)
{:ok, all_q} = SearchTantivy.Query.all_query()
{:ok, all_products} = SearchTantivy.search(index, all_q, limit: 100)

IO.puts("\n=== All Products (#{length(all_products)} total) ===")
for %{doc: doc} <- all_products do
  IO.puts("  #{doc["name"]} — #{doc["category"]}")
end

SearchTantivy.Index.close(index)
```

---

## Example 3: Knowledge Base with Multi-Index Search

A help desk knowledge base that uses separate indexes for different content types, demonstrating index lifecycle, reopening persistent indexes, and combining results from multiple searches.

```elixir
# 1. Define schemas for different content types

article_schema = SearchTantivy.Schema.build!([
  {:title, :text, stored: true},
  {:content, :text, stored: true},
  {:category, :string, stored: true},
  {:article_id, :string, stored: true}
])

faq_schema = SearchTantivy.Schema.build!([
  {:question, :text, stored: true},
  {:answer, :text, stored: true},
  {:topic, :string, stored: true},
  {:faq_id, :string, stored: true}
])

# 2. Create persistent indexes (data survives restarts)
articles_path = Path.join(System.tmp_dir!(), "kb_articles")
faqs_path = Path.join(System.tmp_dir!(), "kb_faqs")

{:ok, articles_idx} = SearchTantivy.create_index(:kb_articles, article_schema, path: articles_path)
{:ok, faqs_idx} = SearchTantivy.create_index(:kb_faqs, faq_schema, path: faqs_path)

# 3. Populate articles
:ok = SearchTantivy.Index.add_documents(articles_idx, [
  %{title: "How to Reset Your Password", article_id: "art-001",
    content: "Navigate to Settings > Security > Change Password. Enter your current
              password, then your new password twice. Click Save. If you forgot your
              current password, use the 'Forgot Password' link on the login page.",
    category: "account"},
  %{title: "Setting Up Two-Factor Authentication", article_id: "art-002",
    content: "Go to Settings > Security > Two-Factor Authentication. Scan the QR code
              with your authenticator app (Google Authenticator or Authy). Enter the
              6-digit code to verify. Save your backup codes in a safe place.",
    category: "security"},
  %{title: "Billing and Subscription Management", article_id: "art-003",
    content: "View your current plan under Settings > Billing. To upgrade or downgrade,
              click Change Plan. Changes take effect at your next billing cycle. To
              cancel, click Cancel Subscription and follow the confirmation steps.",
    category: "billing"},
  %{title: "API Rate Limits and Quotas", article_id: "art-004",
    content: "Free tier: 100 requests per minute. Pro tier: 1000 requests per minute.
              Enterprise: custom limits. Rate limit headers are included in every
              response. When exceeded, you'll receive a 429 status code with a
              Retry-After header.",
    category: "api"}
])
:ok = SearchTantivy.Index.commit(articles_idx)

# 4. Populate FAQs
:ok = SearchTantivy.Index.add_documents(faqs_idx, [
  %{question: "How do I reset my password?", faq_id: "faq-001",
    answer: "Click 'Forgot Password' on the login page and follow the email instructions.",
    topic: "account"},
  %{question: "What payment methods do you accept?", faq_id: "faq-002",
    answer: "We accept Visa, Mastercard, American Express, and PayPal.",
    topic: "billing"},
  %{question: "Is there a free trial?", faq_id: "faq-003",
    answer: "Yes, all new accounts get a 14-day free trial with full Pro features.",
    topic: "billing"},
  %{question: "How do I contact support?", faq_id: "faq-004",
    answer: "Email support@example.com or use the chat widget in the bottom-right corner.",
    topic: "support"},
  %{question: "What are the API rate limits?", faq_id: "faq-005",
    answer: "Free: 100 req/min, Pro: 1000 req/min, Enterprise: custom. See docs for details.",
    topic: "api"}
])
:ok = SearchTantivy.Index.commit(faqs_idx)

# 5. Search across both indexes and merge results
defmodule KBSearch do
  @doc """
  Searches both articles and FAQs, returning unified results
  sorted by relevance score.
  """
  def search(articles_idx, faqs_idx, query, opts \\ []) do
    limit = Keyword.get(opts, :limit, 5)

    with {:ok, article_results} <- SearchTantivy.search(articles_idx, query,
           limit: limit, highlight: [:title, :content]),
         {:ok, faq_results} <- SearchTantivy.search(faqs_idx, query,
           limit: limit, highlight: [:question, :answer]) do

      articles = Enum.map(article_results, fn result ->
        %{
          type: :article,
          id: result.doc["article_id"],
          title: Map.get(result.highlights, :title, result.doc["title"]),
          snippet: Map.get(result.highlights, :content, ""),
          score: result.score
        }
      end)

      faqs = Enum.map(faq_results, fn result ->
        %{
          type: :faq,
          id: result.doc["faq_id"],
          title: Map.get(result.highlights, :question, result.doc["question"]),
          snippet: Map.get(result.highlights, :answer, result.doc["answer"]),
          score: result.score
        }
      end)

      merged =
        (articles ++ faqs)
        |> Enum.sort_by(& &1.score, :desc)
        |> Enum.take(limit)

      {:ok, merged}
    end
  end
end

# 6. Helper for display
defmodule Display do
  def type_label(:article), do: "ARTICLE"
  def type_label(:faq), do: "FAQ"
end

import Display

# 7. Run searches
IO.puts("=== Knowledge Base Search: 'password' ===")
{:ok, results} = KBSearch.search(articles_idx, faqs_idx, "password", limit: 5)

for result <- results do
  type_label = type_label(result.type)
  IO.puts("  [#{type_label}] #{result.title}")
  if result.snippet != "", do: IO.puts("    #{result.snippet}")
  IO.puts("")
end

IO.puts("=== Knowledge Base Search: 'billing' ===")
{:ok, billing_results} = KBSearch.search(articles_idx, faqs_idx, "billing", limit: 5)

for result <- billing_results do
  IO.puts("  [#{type_label(result.type)}] #{result.title}")
end

IO.puts("\n=== Knowledge Base Search: 'API rate limit' ===")
{:ok, api_results} = KBSearch.search(articles_idx, faqs_idx, "API rate limit", limit: 5)

for result <- api_results do
  label = type_label(result.type)
  IO.puts("  [#{label} #{result.id}] [#{Float.round(result.score, 2)}] #{result.title}")
end

# 8. Demonstrate reopening a persistent index
SearchTantivy.Index.close(articles_idx)

# Reopen the same index from disk — data persists
{:ok, reopened} = SearchTantivy.open_index(:kb_articles_reopened, articles_path)
{:ok, results} = SearchTantivy.search(reopened, "password", limit: 3)

IO.puts("\n=== Reopened Index Search: 'password' ===")
for %{doc: doc} <- results do
  IO.puts("  #{doc["title"]}")
end

# Cleanup
SearchTantivy.Index.close(reopened)
SearchTantivy.Index.close(faqs_idx)
File.rm_rf(articles_path)
File.rm_rf(faqs_path)
```
