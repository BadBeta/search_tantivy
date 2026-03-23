defmodule SearchTantivy.Snippet do
  @moduledoc """
  Result highlighting via tantivy's SnippetGenerator.

  Generates HTML snippets with highlighted matching terms from search results.
  Use the `:highlight` option in `SearchTantivy.Searcher.search/3` to enable.

  ## Examples

      {:ok, results} = SearchTantivy.search(index, "hello",
        highlight: [:title, :body]
      )

      # Each result includes highlights:
      # %{score: 1.5, doc: %{...}, highlights: %{"title" => "...<b>hello</b>..."}}

  Highlighted terms are wrapped in `<b>` tags by default (tantivy convention).
  """
end
