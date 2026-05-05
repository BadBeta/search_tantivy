defmodule SearchTantivy.SearcherCatchAllTest do
  use ExUnit.Case, async: true

  describe "search/3 catch-all" do
    test "returns {:error, :invalid_query} for an unsupported query shape" do
      # Map is neither binary, reference, nor non-empty list
      assert {:error, :invalid_query} =
               SearchTantivy.Searcher.search(:any_index, %{not_a_query: true}, [])
    end

    test "returns {:error, :invalid_query} for an empty list" do
      assert {:error, :invalid_query} =
               SearchTantivy.Searcher.search(:any_index, [], [])
    end
  end
end
