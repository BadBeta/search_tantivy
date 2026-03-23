defmodule SearchTantivy.TestFixtures do
  @moduledoc false

  @doc "Returns a basic schema for testing"
  def basic_schema do
    SearchTantivy.Schema.build!([
      {:title, :text, stored: true},
      {:body, :text, stored: true}
    ])
  end

  @doc "Returns sample documents for testing"
  def sample_documents do
    [
      %{title: "First Post", body: "Hello world, this is the first post"},
      %{title: "Second Post", body: "Another post about Elixir"},
      %{title: "Third Post", body: "Rust and NIFs are great"}
    ]
  end
end
