defmodule SearchTantivy.SearchTest do
  use ExUnit.Case, async: true

  setup_all do
    schema =
      SearchTantivy.Schema.build!([
        {:title, :text, stored: true},
        {:body, :text, stored: true},
        {:category, :string, stored: true}
      ])

    name = :"search_test_#{System.unique_integer([:positive])}"
    {:ok, index} = SearchTantivy.Index.create(name, schema)

    :ok =
      SearchTantivy.Index.add_documents(index, [
        %{title: "Elixir Programming", body: "Elixir is a functional language", category: "tech"},
        %{title: "Rust Systems", body: "Rust is a systems language", category: "tech"},
        %{title: "Cooking Pasta", body: "How to make great pasta", category: "food"},
        %{
          title: "Elixir Phoenix",
          body: "Phoenix is a web framework for Elixir",
          category: "tech"
        }
      ])

    :ok = SearchTantivy.Index.commit(index)

    %{index: index, index_name: name}
  end

  describe "search/3 with query string" do
    test "finds matching documents", %{index: index} do
      assert {:ok, results} = SearchTantivy.search(index, "elixir", limit: 10)
      assert [_ | _] = results

      titles = Enum.map(results, & &1.doc["title"])
      assert "Elixir Programming" in titles
    end

    test "respects limit option", %{index: index} do
      assert {:ok, results} = SearchTantivy.search(index, "language", limit: 1)
      assert length(results) == 1
    end

    test "returns empty list for no matches", %{index: index} do
      assert {:ok, []} = SearchTantivy.search(index, "zzzznonexistent", limit: 10)
    end

    test "results include score and doc", %{index: index} do
      {:ok, [result | _]} = SearchTantivy.search(index, "rust", limit: 1)
      assert is_float(result.score)
      assert result.score > 0.0
      assert is_map(result.doc)
    end

    test "searches specific fields", %{index: index} do
      assert {:ok, results} = SearchTantivy.search(index, "elixir", limit: 10, fields: [:title])
      assert [_ | _] = results
    end

    test "respects offset option", %{index: index} do
      {:ok, all_results} = SearchTantivy.search(index, "elixir", limit: 10)
      {:ok, offset_results} = SearchTantivy.search(index, "elixir", limit: 10, offset: 1)

      assert length(offset_results) == length(all_results) - 1
    end
  end

  describe "search by index name" do
    test "searches using atom name instead of pid", %{index_name: name} do
      assert {:ok, results} = SearchTantivy.search(name, "elixir", limit: 10)
      assert [_ | _] = results

      titles = Enum.map(results, & &1.doc["title"])
      assert "Elixir Programming" in titles
    end

    test "name-based search with options", %{index_name: name} do
      assert {:ok, results} = SearchTantivy.search(name, "language", limit: 1)
      assert length(results) == 1
    end
  end

  describe "search with query objects" do
    test "boolean must query via high-level API", %{index: index} do
      {:ok, index_ref} = SearchTantivy.Index.index_ref(index)
      {:ok, q1} = SearchTantivy.Query.parse(index_ref, "elixir")
      {:ok, q2} = SearchTantivy.Query.parse(index_ref, "phoenix")
      {:ok, combined} = SearchTantivy.Query.boolean_query([{:must, q1}, {:must, q2}])

      {:ok, results} = SearchTantivy.search(index, combined, limit: 10)

      titles = Enum.map(results, & &1.doc["title"])
      assert "Elixir Phoenix" in titles
    end

    test "boolean must_not excludes results", %{index: index} do
      {:ok, index_ref} = SearchTantivy.Index.index_ref(index)
      {:ok, q_tech} = SearchTantivy.Query.parse(index_ref, "language")
      {:ok, q_rust} = SearchTantivy.Query.parse(index_ref, "rust")
      {:ok, combined} = SearchTantivy.Query.boolean_query([{:must, q_tech}, {:must_not, q_rust}])

      {:ok, results} = SearchTantivy.search(index, combined, limit: 10)

      titles = Enum.map(results, & &1.doc["title"])
      refute "Rust Systems" in titles
    end

    test "boosted query affects score ordering", %{index: index} do
      {:ok, index_ref} = SearchTantivy.Index.index_ref(index)
      {:ok, q} = SearchTantivy.Query.parse(index_ref, "elixir")
      {:ok, boosted} = SearchTantivy.Query.boost(q, 10.0)

      {:ok, results} = SearchTantivy.search(index, boosted, limit: 10)
      assert [_ | _] = results
      assert hd(results).score > 0.0
    end

    test "all_query matches all documents", %{index: index} do
      {:ok, all_q} = SearchTantivy.Query.all_query()
      {:ok, results} = SearchTantivy.search(index, all_q, limit: 100)
      assert length(results) == 4
    end

    test "query object search works by name", %{index: index, index_name: name} do
      {:ok, index_ref} = SearchTantivy.Index.index_ref(index)
      {:ok, q} = SearchTantivy.Query.parse(index_ref, "rust")

      {:ok, results} = SearchTantivy.search(name, q, limit: 10)
      assert [_ | _] = results

      titles = Enum.map(results, & &1.doc["title"])
      assert "Rust Systems" in titles
    end
  end

  describe "search with highlighting" do
    test "returns atom keys in highlights", %{index: index} do
      {:ok, results} =
        SearchTantivy.search(index, "elixir", limit: 10, highlight: [:title, :body])

      assert [_ | _] = results

      first = hd(results)
      assert is_map(first.highlights)
      assert Map.has_key?(first.highlights, :title) or Map.has_key?(first.highlights, :body)

      highlight_values = Map.values(first.highlights)
      assert Enum.any?(highlight_values, &String.contains?(&1, "<b>"))
    end

    test "returns empty highlights when not requested", %{index: index} do
      {:ok, results} = SearchTantivy.search(index, "elixir", limit: 10)
      first = hd(results)
      assert first.highlights == %{}
    end

    test "highlighting works with name-based search", %{index_name: name} do
      {:ok, results} =
        SearchTantivy.search(name, "elixir", limit: 10, highlight: [:title])

      assert [_ | _] = results
      first = hd(results)
      assert Map.has_key?(first.highlights, :title)
    end
  end

  describe "search with keyword list boolean shorthand" do
    test "must clauses filter results", %{index: index} do
      {:ok, results} =
        SearchTantivy.search(index, [must: "elixir", must: "phoenix"], limit: 10)

      assert [_ | _] = results
      titles = Enum.map(results, & &1.doc["title"])
      assert "Elixir Phoenix" in titles
      refute "Elixir Programming" in titles
    end

    test "should clauses broaden results", %{index: index} do
      {:ok, results} =
        SearchTantivy.search(index, [should: "elixir", should: "pasta"], limit: 10)

      assert length(results) >= 2
    end

    test "must_not excludes results", %{index: index} do
      {:ok, results} =
        SearchTantivy.search(index, [must: "language", must_not: "rust"], limit: 10)

      titles = Enum.map(results, & &1.doc["title"])
      refute "Rust Systems" in titles
    end

    test "works with name-based search", %{index_name: name} do
      {:ok, results} =
        SearchTantivy.search(name, [must: "elixir", must: "phoenix"], limit: 10)

      assert [_ | _] = results
    end

    test "supports mixed string and query ref clauses", %{index: index} do
      {:ok, index_ref} = SearchTantivy.Index.index_ref(index)
      {:ok, q} = SearchTantivy.Query.parse(index_ref, "phoenix")

      {:ok, results} =
        SearchTantivy.search(index, [must: "elixir", must: q], limit: 10)

      assert [_ | _] = results
      titles = Enum.map(results, & &1.doc["title"])
      assert "Elixir Phoenix" in titles
    end
  end

  describe "add_and_commit/2" do
    test "adds documents and commits in one call" do
      schema =
        SearchTantivy.Schema.build!([
          {:title, :text, stored: true}
        ])

      name = :"add_commit_test_#{System.unique_integer([:positive])}"
      {:ok, index} = SearchTantivy.Index.create(name, schema)

      :ok =
        SearchTantivy.Index.add_and_commit(index, [
          %{title: "One Step"},
          %{title: "Easy API"}
        ])

      {:ok, results} = SearchTantivy.search(index, "easy", limit: 10)
      assert [_ | _] = results
      assert hd(results).doc["title"] == "Easy API"
    end
  end
end
