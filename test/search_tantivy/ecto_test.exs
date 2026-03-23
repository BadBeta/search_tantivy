defmodule SearchTantivy.EctoTest do
  use ExUnit.Case, async: true

  @search_fields [
    {:title, :text, stored: true},
    {:body, :text, stored: true},
    {:slug, :string, stored: true, indexed: true}
  ]

  describe "to_document/2" do
    test "extracts fields from a map" do
      record = %{title: "Hello", body: "World", slug: "hello", extra: "ignored"}

      assert SearchTantivy.Ecto.to_document(record, @search_fields) == %{
               title: "Hello",
               body: "World",
               slug: "hello"
             }
    end

    test "extracts fields from a struct" do
      record = %URI{host: "example.com", port: 443, path: "/test"}
      fields = [{:host, :string}, {:path, :string}]

      assert SearchTantivy.Ecto.to_document(record, fields) == %{
               host: "example.com",
               path: "/test"
             }
    end

    test "returns nil for missing fields" do
      record = %{title: "Hello"}

      assert SearchTantivy.Ecto.to_document(record, @search_fields) == %{
               title: "Hello",
               body: nil,
               slug: nil
             }
    end

    test "works with two-element field tuples" do
      record = %{title: "Test", body: "Content"}
      fields = [{:title, :text}, {:body, :text}]

      assert SearchTantivy.Ecto.to_document(record, fields) == %{
               title: "Test",
               body: "Content"
             }
    end
  end

  describe "to_documents/2" do
    test "converts a list of records" do
      records = [
        %{title: "First", body: "One", slug: "first"},
        %{title: "Second", body: "Two", slug: "second"}
      ]

      result = SearchTantivy.Ecto.to_documents(records, @search_fields)

      assert length(result) == 2
      assert Enum.at(result, 0) == %{title: "First", body: "One", slug: "first"}
      assert Enum.at(result, 1) == %{title: "Second", body: "Two", slug: "second"}
    end

    test "returns empty list for empty input" do
      assert SearchTantivy.Ecto.to_documents([], @search_fields) == []
    end
  end

  describe "build_schema!/1" do
    test "builds a schema from field mappings" do
      schema = SearchTantivy.Ecto.build_schema!(@search_fields)
      assert is_reference(schema)
    end
  end

  describe "index_one/3 and index_all/3" do
    setup do
      index_name = :"test_ecto_#{System.unique_integer([:positive])}"
      schema = SearchTantivy.Ecto.build_schema!(@search_fields)
      {:ok, _pid} = SearchTantivy.create_index(index_name, schema)
      %{index_name: index_name}
    end

    test "index_one indexes and commits a single record", %{index_name: index_name} do
      record = %{title: "Test Post", body: "Some content here", slug: "test-post"}

      assert :ok = SearchTantivy.Ecto.index_one(index_name, record, @search_fields)

      via = SearchTantivy.IndexRegistry.via(index_name)
      {:ok, results} = SearchTantivy.search(via, "content", limit: 10)
      assert length(results) == 1
      assert hd(results).doc["title"] == "Test Post"
    end

    test "index_all indexes and commits multiple records", %{index_name: index_name} do
      records = [
        %{title: "First", body: "Alpha content", slug: "first"},
        %{title: "Second", body: "Beta content", slug: "second"}
      ]

      assert :ok = SearchTantivy.Ecto.index_all(index_name, records, @search_fields)

      via = SearchTantivy.IndexRegistry.via(index_name)
      {:ok, results} = SearchTantivy.search(via, "content", limit: 10)
      assert length(results) == 2
    end
  end

  describe "delete_one/3" do
    setup do
      index_name = :"test_ecto_del_#{System.unique_integer([:positive])}"
      schema = SearchTantivy.Ecto.build_schema!(@search_fields)
      {:ok, _pid} = SearchTantivy.create_index(index_name, schema)
      %{index_name: index_name}
    end

    test "deletes a document by field value", %{index_name: index_name} do
      records = [
        %{title: "Keep This", body: "Stays in index", slug: "keep"},
        %{title: "Remove This", body: "Gets deleted", slug: "remove"}
      ]

      :ok = SearchTantivy.Ecto.index_all(index_name, records, @search_fields)

      via = SearchTantivy.IndexRegistry.via(index_name)
      {:ok, before} = SearchTantivy.search(via, "index deleted", limit: 10)
      assert length(before) == 2

      :ok = SearchTantivy.Ecto.delete_one(index_name, :slug, "remove")

      {:ok, after_delete} = SearchTantivy.search(via, "index deleted", limit: 10)
      assert length(after_delete) == 1
      assert hd(after_delete).doc["slug"] == "keep"
    end
  end
end
