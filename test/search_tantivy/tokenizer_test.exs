defmodule SearchTantivy.TokenizerTest do
  use ExUnit.Case, async: true

  @search_fields [
    {:title, :text, stored: true},
    {:body, :text, stored: true}
  ]

  setup do
    index_name = :"test_tokenizer_#{System.unique_integer([:positive])}"
    schema = SearchTantivy.Ecto.build_schema!(@search_fields)
    {:ok, _pid} = SearchTantivy.create_index(index_name, schema)

    via = SearchTantivy.IndexRegistry.via(index_name)
    {:ok, index_ref} = SearchTantivy.Index.index_ref(via)

    %{index_ref: index_ref, index_name: index_name}
  end

  describe "register/2" do
    test "registers built-in tokenizers without error", %{index_ref: index_ref} do
      assert :ok = SearchTantivy.Tokenizer.register(index_ref, :default)
      assert :ok = SearchTantivy.Tokenizer.register(index_ref, :raw)
      assert :ok = SearchTantivy.Tokenizer.register(index_ref, :whitespace)
    end

    test "registers language-specific stemming tokenizers", %{index_ref: index_ref} do
      languages = ~w(en fr de es pt it nl sv no da fi hu ro ru tr ar ta el)a

      for lang <- languages do
        tokenizer = :"#{lang}_stem"
        assert :ok = SearchTantivy.Tokenizer.register(index_ref, tokenizer)
      end
    end

    test "returns error for unknown tokenizer", %{index_ref: index_ref} do
      assert {:error, msg} = SearchTantivy.Tokenizer.register(index_ref, :nonexistent)
      assert msg =~ "unknown tokenizer"
    end

    test "en_stem tokenizer stems English words" do
      stemmed_fields = [
        {:title, :text, stored: true, tokenizer: :en_stem},
        {:body, :text, stored: true, tokenizer: :en_stem}
      ]

      index_name = :"test_stem_#{System.unique_integer([:positive])}"
      schema = SearchTantivy.Ecto.build_schema!(stemmed_fields)
      {:ok, _pid} = SearchTantivy.create_index(index_name, schema)

      via = SearchTantivy.IndexRegistry.via(index_name)
      {:ok, index_ref} = SearchTantivy.Index.index_ref(via)

      # Register the tokenizer on the index before indexing
      :ok = SearchTantivy.Tokenizer.register(index_ref, :en_stem)

      articles = [
        %{title: "Running Fast", body: "The runners are running quickly"},
        %{title: "Swimming Pools", body: "Swimmers swim in the pool"}
      ]

      :ok = SearchTantivy.Ecto.index_all(index_name, articles, stemmed_fields)

      {:ok, reader} = SearchTantivy.Index.reader(via)

      # "run" should match "running" and "runners" via stemming
      {:ok, query} = SearchTantivy.Query.parse(index_ref, "run", [:body])
      {:ok, results} = SearchTantivy.Native.search(reader, query, 10, 0)
      assert length(results) == 1
    end
  end
end
