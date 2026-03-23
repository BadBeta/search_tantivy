defmodule SearchTantivy.AggregationTest do
  use ExUnit.Case, async: true

  alias SearchTantivy.Aggregation

  @search_fields [
    {:title, :text, stored: true},
    {:category, :string, stored: true, fast: true},
    {:price, :f64, stored: true, fast: true, indexed: true},
    {:quantity, :u64, stored: true, fast: true, indexed: true}
  ]

  setup do
    index_name = :"test_agg_#{System.unique_integer([:positive])}"
    schema = SearchTantivy.Ecto.build_schema!(@search_fields)
    {:ok, _pid} = SearchTantivy.create_index(index_name, schema)

    products = [
      %{title: "Laptop Pro", category: "electronics", price: 999.99, quantity: 10},
      %{title: "Laptop Basic", category: "electronics", price: 499.99, quantity: 25},
      %{title: "Phone X", category: "electronics", price: 799.99, quantity: 50},
      %{title: "Running Shoes", category: "sports", price: 89.99, quantity: 100},
      %{title: "Tennis Racket", category: "sports", price: 149.99, quantity: 30},
      %{title: "Novel Book", category: "books", price: 14.99, quantity: 200},
      %{title: "Cookbook", category: "books", price: 24.99, quantity: 150}
    ]

    :ok = SearchTantivy.Ecto.index_all(index_name, products, @search_fields)

    %{index_name: index_name}
  end

  describe "aggregate/3 (high-level API)" do
    test "groups by category with no query filter", %{index_name: index_name} do
      {:ok, result} =
        Aggregation.aggregate(index_name, %{
          "by_category" => Aggregation.terms(:category, size: 10)
        })

      buckets = result["by_category"]["buckets"]
      assert length(buckets) == 3

      category_counts = Map.new(buckets, fn b -> {b["key"], b["doc_count"]} end)
      assert category_counts["electronics"] == 3
      assert category_counts["sports"] == 2
      assert category_counts["books"] == 2
    end

    test "filters with query string", %{index_name: index_name} do
      {:ok, result} =
        Aggregation.aggregate(
          index_name,
          %{"price_stats" => Aggregation.stats(:price)},
          query: "laptop"
        )

      stats = result["price_stats"]
      # Only "Laptop Pro" and "Laptop Basic" match
      assert stats["count"] == 2
      assert_in_delta stats["min"], 499.99, 0.01
      assert_in_delta stats["max"], 999.99, 0.01
    end

    test "available via SearchTantivy.aggregate/3 facade", %{index_name: index_name} do
      {:ok, result} =
        SearchTantivy.aggregate(index_name, %{
          "avg_price" => Aggregation.avg(:price)
        })

      assert is_float(result["avg_price"]["value"])
    end
  end

  describe "metric aggregations" do
    test "avg price", %{index_name: index_name} do
      {:ok, result} =
        Aggregation.aggregate(index_name, %{"avg_price" => Aggregation.avg(:price)})

      avg = result["avg_price"]["value"]
      expected = (999.99 + 499.99 + 799.99 + 89.99 + 149.99 + 14.99 + 24.99) / 7
      assert_in_delta avg, expected, 0.01
    end

    test "min price", %{index_name: index_name} do
      {:ok, result} =
        Aggregation.aggregate(index_name, %{"min_price" => Aggregation.min(:price)})

      assert_in_delta result["min_price"]["value"], 14.99, 0.01
    end

    test "max price", %{index_name: index_name} do
      {:ok, result} =
        Aggregation.aggregate(index_name, %{"max_price" => Aggregation.max(:price)})

      assert_in_delta result["max_price"]["value"], 999.99, 0.01
    end

    test "sum of quantities", %{index_name: index_name} do
      {:ok, result} =
        Aggregation.aggregate(index_name, %{"total_qty" => Aggregation.sum(:quantity)})

      expected = 10 + 25 + 50 + 100 + 30 + 200 + 150
      assert_in_delta result["total_qty"]["value"], expected, 0.01
    end

    test "stats aggregation", %{index_name: index_name} do
      {:ok, result} =
        Aggregation.aggregate(index_name, %{"price_stats" => Aggregation.stats(:price)})

      stats = result["price_stats"]
      assert stats["count"] == 7
      assert_in_delta stats["min"], 14.99, 0.01
      assert_in_delta stats["max"], 999.99, 0.01
      assert is_float(stats["avg"])
      assert is_float(stats["sum"])
    end
  end

  describe "histogram aggregation" do
    test "groups prices into buckets", %{index_name: index_name} do
      {:ok, result} =
        Aggregation.aggregate(index_name, %{
          "price_hist" => Aggregation.histogram(:price, 200.0)
        })

      buckets = result["price_hist"]["buckets"]
      assert is_list(buckets)
      assert buckets != []

      bucket_map = Map.new(buckets, fn b -> {b["key"], b["doc_count"]} end)
      assert bucket_map[0.0] == 4
      assert bucket_map[400.0] == 1
      assert bucket_map[800.0] == 1
    end
  end

  describe "range aggregation" do
    test "groups prices into custom ranges", %{index_name: index_name} do
      {:ok, result} =
        Aggregation.aggregate(index_name, %{
          "price_ranges" =>
            Aggregation.range(:price, [
              %{to: 100.0},
              %{from: 100.0, to: 500.0},
              %{from: 500.0}
            ])
        })

      buckets = result["price_ranges"]["buckets"]
      assert length(buckets) == 3

      [cheap, mid, expensive] = buckets
      assert cheap["doc_count"] == 3
      assert mid["doc_count"] == 2
      assert expensive["doc_count"] == 2
    end
  end

  describe "multiple aggregations" do
    test "runs multiple aggregations in one search", %{index_name: index_name} do
      {:ok, result} =
        Aggregation.aggregate(index_name, %{
          "by_category" => Aggregation.terms(:category),
          "avg_price" => Aggregation.avg(:price),
          "price_stats" => Aggregation.stats(:price)
        })

      assert result["by_category"]["buckets"]
      assert result["avg_price"]["value"]
      assert result["price_stats"]["count"] == 7
    end
  end

  describe "nested aggregations" do
    test "terms with nested avg metric", %{index_name: index_name} do
      {:ok, result} =
        Aggregation.aggregate(index_name, %{
          "by_category" =>
            Aggregation.terms(:category,
              aggs: %{"avg_price" => Aggregation.avg(:price)}
            )
        })

      buckets = result["by_category"]["buckets"]
      electronics = Enum.find(buckets, &(&1["key"] == "electronics"))
      assert electronics
      assert is_float(electronics["avg_price"]["value"])

      expected_electronics_avg = (999.99 + 499.99 + 799.99) / 3
      assert_in_delta electronics["avg_price"]["value"], expected_electronics_avg, 0.01
    end
  end

  describe "builder functions" do
    test "terms builds correct structure" do
      result = Aggregation.terms(:category, size: 20)
      assert result == %{"terms" => %{"field" => "category", "size" => 20}}
    end

    test "histogram builds correct structure" do
      result = Aggregation.histogram(:price, 50.0)
      assert result == %{"histogram" => %{"field" => "price", "interval" => 50.0}}
    end

    test "range builds correct structure" do
      result = Aggregation.range(:price, [%{to: 100.0}, %{from: 100.0}])

      assert result == %{
               "range" => %{
                 "field" => "price",
                 "ranges" => [%{"to" => 100.0}, %{"from" => 100.0}]
               }
             }
    end

    test "metric builders" do
      assert Aggregation.avg(:price) == %{"avg" => %{"field" => "price"}}
      assert Aggregation.min(:price) == %{"min" => %{"field" => "price"}}
      assert Aggregation.max(:price) == %{"max" => %{"field" => "price"}}
      assert Aggregation.sum(:price) == %{"sum" => %{"field" => "price"}}
      assert Aggregation.count(:price) == %{"value_count" => %{"field" => "price"}}
      assert Aggregation.stats(:price) == %{"stats" => %{"field" => "price"}}
    end

    test "percentiles builds correct structure" do
      result = Aggregation.percentiles(:latency, [50.0, 95.0, 99.0])

      assert result == %{
               "percentiles" => %{
                 "field" => "latency",
                 "percents" => [50.0, 95.0, 99.0]
               }
             }
    end
  end
end
