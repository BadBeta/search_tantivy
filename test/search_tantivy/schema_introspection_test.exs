defmodule SearchTantivy.SchemaIntrospectionTest do
  use ExUnit.Case, async: true

  @search_fields [
    {:title, :text, stored: true},
    {:body, :text, stored: true},
    {:slug, :string, stored: true, indexed: true},
    {:view_count, :u64, stored: true, fast: true}
  ]

  setup do
    index_name = :"test_introspect_#{System.unique_integer([:positive])}"
    schema = SearchTantivy.Ecto.build_schema!(@search_fields)
    {:ok, _pid} = SearchTantivy.create_index(index_name, schema)

    via = SearchTantivy.IndexRegistry.via(index_name)
    {:ok, index_ref} = SearchTantivy.Index.index_ref(via)

    %{index_ref: index_ref}
  end

  describe "field_exists?/2" do
    test "returns true for existing fields", %{index_ref: index_ref} do
      assert SearchTantivy.Schema.field_exists?(index_ref, :title)
      assert SearchTantivy.Schema.field_exists?(index_ref, :slug)
      assert SearchTantivy.Schema.field_exists?(index_ref, :view_count)
    end

    test "returns false for non-existing fields", %{index_ref: index_ref} do
      refute SearchTantivy.Schema.field_exists?(index_ref, :nonexistent)
      refute SearchTantivy.Schema.field_exists?(index_ref, :missing)
    end
  end

  describe "field_names/1" do
    test "returns all field names as atoms", %{index_ref: index_ref} do
      names = SearchTantivy.Schema.field_names(index_ref)
      assert :title in names
      assert :body in names
      assert :slug in names
      assert :view_count in names
      assert length(names) == 4
    end
  end

  describe "field_type/2" do
    test "returns text type for text fields", %{index_ref: index_ref} do
      assert {:ok, :text} = SearchTantivy.Schema.field_type(index_ref, :title)
      assert {:ok, :text} = SearchTantivy.Schema.field_type(index_ref, :body)
    end

    test "returns string type for string fields", %{index_ref: index_ref} do
      assert {:ok, :string} = SearchTantivy.Schema.field_type(index_ref, :slug)
    end

    test "returns u64 type for numeric fields", %{index_ref: index_ref} do
      assert {:ok, :u64} = SearchTantivy.Schema.field_type(index_ref, :view_count)
    end

    test "returns error for unknown field", %{index_ref: index_ref} do
      assert {:error, _} = SearchTantivy.Schema.field_type(index_ref, :nonexistent)
    end
  end
end
