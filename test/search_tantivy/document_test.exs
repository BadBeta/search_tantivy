defmodule SearchTantivy.DocumentTest do
  use ExUnit.Case, async: true

  setup do
    schema =
      SearchTantivy.Schema.build!([
        {:title, :text, stored: true},
        {:body, :text, stored: true},
        {:count, :u64, stored: true}
      ])

    %{schema: schema}
  end

  describe "new/2" do
    test "creates document from map", %{schema: schema} do
      assert {:ok, doc} =
               SearchTantivy.Document.new(schema, %{
                 title: "Hello",
                 body: "World",
                 count: 42
               })

      assert is_reference(doc)
    end

    test "handles various value types", %{schema: schema} do
      assert {:ok, _doc} =
               SearchTantivy.Document.new(schema, %{
                 title: "Test",
                 body: "Content",
                 count: 0
               })
    end
  end
end
