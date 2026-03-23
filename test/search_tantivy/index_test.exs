defmodule SearchTantivy.IndexTest do
  use ExUnit.Case, async: true

  setup do
    schema =
      SearchTantivy.Schema.build!([
        {:title, :text, stored: true},
        {:body, :text, stored: true}
      ])

    # Use unique names per test to avoid Registry conflicts
    name = :"index_test_#{System.unique_integer([:positive])}"
    %{schema: schema, name: name}
  end

  describe "create/3" do
    test "creates in-memory index", %{schema: schema, name: name} do
      assert {:ok, pid} = SearchTantivy.Index.create(name, schema)
      assert is_pid(pid)
      SearchTantivy.Index.close(pid)
    end

    test "creates persistent index", %{schema: schema, name: name} do
      path = Path.join(System.tmp_dir!(), "tantivy_test_#{name}")

      on_exit(fn -> File.rm_rf(path) end)

      assert {:ok, pid} = SearchTantivy.Index.create(name, schema, path: path)
      assert is_pid(pid)
      assert File.dir?(path)
      SearchTantivy.Index.close(pid)
    end
  end

  describe "add_documents/2 and commit/1" do
    test "adds and commits documents", %{schema: schema, name: name} do
      {:ok, index} = SearchTantivy.Index.create(name, schema)

      assert :ok =
               SearchTantivy.Index.add_documents(index, [
                 %{title: "Hello", body: "World"},
                 %{title: "Foo", body: "Bar"}
               ])

      assert :ok = SearchTantivy.Index.commit(index)
      SearchTantivy.Index.close(index)
    end
  end

  describe "reader/1" do
    test "returns a reader reference", %{schema: schema, name: name} do
      {:ok, index} = SearchTantivy.Index.create(name, schema)
      :ok = SearchTantivy.Index.commit(index)
      assert {:ok, reader} = SearchTantivy.Index.reader(index)
      assert is_reference(reader)
      SearchTantivy.Index.close(index)
    end
  end

  describe "close/1" do
    test "stops the GenServer gracefully", %{schema: schema, name: name} do
      {:ok, index} = SearchTantivy.Index.create(name, schema)
      ref = Process.monitor(index)
      :ok = SearchTantivy.Index.close(index)
      assert_receive {:DOWN, ^ref, :process, _, :normal}, 5000
    end
  end
end
