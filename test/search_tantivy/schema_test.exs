defmodule SearchTantivy.SchemaTest do
  use ExUnit.Case, async: true

  describe "build/1" do
    test "builds schema from field definitions" do
      assert {:ok, schema} =
               SearchTantivy.Schema.build([
                 {:title, :text, stored: true},
                 {:body, :text},
                 {:id, :u64, stored: true, indexed: true, fast: true}
               ])

      assert is_reference(schema)
    end

    test "builds schema with all field types" do
      fields =
        Enum.map(
          [:text, :string, :u64, :i64, :f64, :bool, :date, :bytes, :json, :ip_addr, :facet],
          fn type -> {:"field_#{type}", type, stored: true} end
        )

      assert {:ok, schema} = SearchTantivy.Schema.build(fields)
      assert is_reference(schema)
    end

    test "builds schema without options" do
      assert {:ok, schema} = SearchTantivy.Schema.build([{:title, :text}])
      assert is_reference(schema)
    end

    test "returns error for invalid field type" do
      assert {:error, msg} = SearchTantivy.Schema.build([{:bad, :nonexistent}])
      assert msg =~ "invalid field type"
    end

    test "returns error for invalid field definition" do
      assert {:error, msg} = SearchTantivy.Schema.build([:not_a_tuple])
      assert msg =~ "invalid field definition"
    end
  end

  describe "build!/1" do
    test "returns schema on success" do
      schema = SearchTantivy.Schema.build!([{:title, :text, stored: true}])
      assert is_reference(schema)
    end

    test "raises ArgumentError on error" do
      assert_raise ArgumentError, ~r/failed to build schema/, fn ->
        SearchTantivy.Schema.build!([{:bad, :nonexistent}])
      end
    end
  end
end
