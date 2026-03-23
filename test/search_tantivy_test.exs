defmodule SearchTantivyTest do
  use ExUnit.Case, async: true

  describe "integration" do
    test "full index, search, and retrieve workflow" do
      schema =
        SearchTantivy.Schema.build!([
          {:title, :text, stored: true},
          {:body, :text, stored: true},
          {:url, :string, stored: true}
        ])

      {:ok, index} = SearchTantivy.create_index(:integration_test, schema)

      :ok =
        SearchTantivy.Index.add_documents(index, [
          %{title: "Hello World", body: "This is the first post", url: "/hello"},
          %{title: "Elixir Search", body: "tantivy is fast", url: "/search"},
          %{title: "Rust NIFs", body: "Rustler makes NIFs easy", url: "/rust"}
        ])

      :ok = SearchTantivy.Index.commit(index)

      {:ok, results} = SearchTantivy.search(index, "hello", limit: 10)

      assert [_ | _] = results

      first = hd(results)
      assert is_float(first.score)
      assert is_map(first.doc)

      SearchTantivy.Index.close(index)
    end
  end
end
