defmodule SearchTantivy.QueryTypesTest do
  use ExUnit.Case, async: true

  @search_fields [
    {:title, :text, stored: true},
    {:body, :text, stored: true},
    {:slug, :string, stored: true, indexed: true},
    {:category, :string, stored: true, indexed: true}
  ]

  setup do
    index_name = :"test_query_#{System.unique_integer([:positive])}"
    schema = SearchTantivy.Ecto.build_schema!(@search_fields)
    {:ok, _pid} = SearchTantivy.create_index(index_name, schema)

    articles = [
      %{title: "Quick Brown Fox", body: "The quick brown fox jumps", slug: "quick-fox", category: "animals"},
      %{title: "Elixir Programming", body: "Learn elixir programming today", slug: "elixir-prog", category: "tech"},
      %{title: "Elixir Phoenix Guide", body: "Build web apps with phoenix", slug: "elixir-phoenix", category: "tech"},
      %{title: "Rust Systems", body: "Systems programming with rust", slug: "rust-systems", category: "tech"}
    ]

    :ok = SearchTantivy.Ecto.index_all(index_name, articles, @search_fields)

    via = SearchTantivy.IndexRegistry.via(index_name)
    {:ok, index_ref} = SearchTantivy.Index.index_ref(via)
    {:ok, reader} = SearchTantivy.Index.reader(via)

    %{index_ref: index_ref, reader: reader}
  end

  describe "phrase/3" do
    test "matches exact phrase", %{index_ref: index_ref, reader: reader} do
      {:ok, query} = SearchTantivy.Query.phrase(index_ref, :body, ["quick", "brown"])
      {:ok, results} = SearchTantivy.Native.search(reader, query, 10, 0)
      assert length(results) == 1
    end

    test "does not match when words are not adjacent", %{index_ref: index_ref, reader: reader} do
      {:ok, query} = SearchTantivy.Query.phrase(index_ref, :body, ["quick", "fox"])
      {:ok, results} = SearchTantivy.Native.search(reader, query, 10, 0)
      # "quick brown fox" — "quick" and "fox" are not adjacent
      assert results == []
    end
  end

  describe "phrase_prefix/3" do
    test "matches prefix phrases", %{index_ref: index_ref, reader: reader} do
      {:ok, query} = SearchTantivy.Query.phrase_prefix(index_ref, :body, ["quick", "bro"])
      {:ok, results} = SearchTantivy.Native.search(reader, query, 10, 0)
      assert length(results) == 1
    end
  end

  describe "regex/3" do
    test "matches regex pattern on string field", %{index_ref: index_ref, reader: reader} do
      {:ok, query} = SearchTantivy.Query.regex(index_ref, :slug, "elixir-.*")
      {:ok, results} = SearchTantivy.Native.search(reader, query, 10, 0)
      assert length(results) == 2
    end

    test "returns error for invalid regex", %{index_ref: index_ref} do
      assert {:error, _} = SearchTantivy.Query.regex(index_ref, :slug, "[invalid")
    end
  end

  describe "exists/2" do
    test "matches documents where field has a value", %{index_ref: index_ref, reader: reader} do
      {:ok, query} = SearchTantivy.Query.exists(index_ref, :category)
      {:ok, results} = SearchTantivy.Native.search(reader, query, 10, 0)
      assert length(results) == 4
    end
  end
end
