defmodule SearchTantivy.QueryTest do
  use ExUnit.Case, async: true

  describe "all_query/0" do
    test "creates an all-documents query" do
      assert {:ok, query} = SearchTantivy.Query.all_query()
      assert is_reference(query)
    end
  end

  describe "parse/3" do
    setup do
      schema =
        SearchTantivy.Schema.build!([
          {:title, :text, stored: true},
          {:body, :text, stored: true}
        ])

      name = :"query_parse_test_#{System.unique_integer([:positive])}"
      {:ok, index} = SearchTantivy.Index.create(name, schema)
      {:ok, index_ref} = SearchTantivy.Index.index_ref(index)

      %{index: index, index_ref: index_ref}
    end

    test "parses a simple query string", %{index_ref: index_ref} do
      assert {:ok, query} = SearchTantivy.Query.parse(index_ref, "hello world")
      assert is_reference(query)
    end

    test "parses with specific fields", %{index_ref: index_ref} do
      assert {:ok, query} = SearchTantivy.Query.parse(index_ref, "hello", [:title])
      assert is_reference(query)
    end

    test "returns error for invalid query syntax", %{index_ref: index_ref} do
      assert {:error, _reason} = SearchTantivy.Query.parse(index_ref, "field::")
    end
  end

  describe "term_query/3" do
    setup do
      schema =
        SearchTantivy.Schema.build!([
          {:title, :text, stored: true},
          {:category, :string, stored: true},
          {:count, :u64, stored: true}
        ])

      name = :"query_term_test_#{System.unique_integer([:positive])}"
      {:ok, index} = SearchTantivy.Index.create(name, schema)
      {:ok, index_ref} = SearchTantivy.Index.index_ref(index)

      %{index: index, index_ref: index_ref}
    end

    test "creates a term query for text field", %{index_ref: index_ref} do
      assert {:ok, query} = SearchTantivy.Query.term_query(index_ref, :title, "hello")
      assert is_reference(query)
    end

    test "creates a term query for string field", %{index_ref: index_ref} do
      assert {:ok, query} = SearchTantivy.Query.term_query(index_ref, :category, "tech")
      assert is_reference(query)
    end

    test "creates a term query for u64 field", %{index_ref: index_ref} do
      assert {:ok, query} = SearchTantivy.Query.term_query(index_ref, :count, "42")
      assert is_reference(query)
    end

    test "returns error for unknown field", %{index_ref: index_ref} do
      assert {:error, _reason} = SearchTantivy.Query.term_query(index_ref, :nonexistent, "value")
    end
  end

  describe "boolean_query/1" do
    setup do
      schema =
        SearchTantivy.Schema.build!([
          {:title, :text, stored: true},
          {:body, :text, stored: true}
        ])

      name = :"query_bool_test_#{System.unique_integer([:positive])}"
      {:ok, index} = SearchTantivy.Index.create(name, schema)
      {:ok, index_ref} = SearchTantivy.Index.index_ref(index)

      %{index: index, index_ref: index_ref}
    end

    test "combines queries with must/should/must_not", %{index_ref: index_ref} do
      {:ok, q1} = SearchTantivy.Query.parse(index_ref, "hello")
      {:ok, q2} = SearchTantivy.Query.parse(index_ref, "world")
      {:ok, q3} = SearchTantivy.Query.parse(index_ref, "spam")

      assert {:ok, combined} =
               SearchTantivy.Query.boolean_query([
                 {:must, q1},
                 {:should, q2},
                 {:must_not, q3}
               ])

      assert is_reference(combined)
    end

    test "combines term and parsed queries", %{index_ref: index_ref} do
      {:ok, term_q} = SearchTantivy.Query.term_query(index_ref, :title, "elixir")
      {:ok, parsed_q} = SearchTantivy.Query.parse(index_ref, "functional")

      assert {:ok, combined} =
               SearchTantivy.Query.boolean_query([
                 {:must, term_q},
                 {:should, parsed_q}
               ])

      assert is_reference(combined)
    end

    test "returns error for invalid occur type", %{index_ref: index_ref} do
      {:ok, q} = SearchTantivy.Query.parse(index_ref, "hello")
      assert {:error, _reason} = SearchTantivy.Query.boolean_query([{:invalid, q}])
    end
  end

  describe "boost/2" do
    setup do
      schema =
        SearchTantivy.Schema.build!([
          {:title, :text, stored: true}
        ])

      name = :"query_boost_test_#{System.unique_integer([:positive])}"
      {:ok, index} = SearchTantivy.Index.create(name, schema)
      {:ok, index_ref} = SearchTantivy.Index.index_ref(index)

      %{index: index, index_ref: index_ref}
    end

    test "boosts a query by a factor", %{index_ref: index_ref} do
      {:ok, query} = SearchTantivy.Query.parse(index_ref, "hello")
      assert {:ok, boosted} = SearchTantivy.Query.boost(query, 2.0)
      assert is_reference(boosted)
    end

    test "can boost a term query", %{index_ref: index_ref} do
      {:ok, query} = SearchTantivy.Query.term_query(index_ref, :title, "elixir")
      assert {:ok, boosted} = SearchTantivy.Query.boost(query, 1.5)
      assert is_reference(boosted)
    end
  end
end
