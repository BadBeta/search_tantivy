defmodule SearchTantivy.Ecto do
  @moduledoc """
  Helper functions for integrating SearchTantivy with Ecto schemas.

  This module provides pure functions that convert Ecto structs to
  search documents using field mappings. No macros, no magic — call
  these functions explicitly in your context modules.

  ## Field Mappings

  A field mapping is the same format used by `SearchTantivy.Schema.build/1`:

      @search_fields [
        {:title, :text, stored: true},
        {:body, :text, stored: true},
        {:slug, :string, stored: true, indexed: true}
      ]

  The field name (first element) must match both the Ecto schema field
  and the search index field.

  ## Usage in Context Modules

      defmodule Blog do
        @search_fields [
          {:title, :text, stored: true},
          {:body, :text, stored: true},
          {:slug, :string, stored: true, indexed: true}
        ]

        def create_post(attrs) do
          with {:ok, post} <- Repo.insert(Post.changeset(%Post{}, attrs)) do
            SearchTantivy.Ecto.index_one(:blog_posts, post, @search_fields)
            {:ok, post}
          end
        end

        def reindex_all do
          posts = Repo.all(Post)
          SearchTantivy.Ecto.index_all(:blog_posts, posts, @search_fields)
        end
      end

  ## Static Content

  These helpers work with any map or struct, not just Ecto schemas.
  Pass plain maps for static content, file-based data, or API responses:

      articles = [%{title: "Hello", body: "World", slug: "hello"}]
      SearchTantivy.Ecto.index_all(:blog, articles, @search_fields)

  """

  @type field_mapping ::
          {atom(), SearchTantivy.Schema.field_type()}
          | {atom(), SearchTantivy.Schema.field_type(), [SearchTantivy.Schema.field_option()]}

  @doc """
  Converts a struct or map to a document map using the field mapping.

  Extracts only the fields listed in the mapping. Missing fields
  become `nil` values (which tantivy will skip).

  ## Examples

      iex> post = %{title: "Hello", body: "World", slug: "hello", inserted_at: ~U[2024-01-01 00:00:00Z]}
      iex> fields = [{:title, :text}, {:body, :text}, {:slug, :string}]
      iex> SearchTantivy.Ecto.to_document(post, fields)
      %{title: "Hello", body: "World", slug: "hello"}

  """
  @spec to_document(map() | struct(), [field_mapping()]) :: map()
  def to_document(record, fields) when is_list(fields) do
    Map.new(fields, fn
      {field, _type} -> {field, get_field(record, field)}
      {field, _type, _opts} -> {field, get_field(record, field)}
    end)
  end

  @doc """
  Converts a list of structs or maps to document maps.

  ## Examples

      iex> posts = [%{title: "A", body: "1"}, %{title: "B", body: "2"}]
      iex> fields = [{:title, :text}, {:body, :text}]
      iex> SearchTantivy.Ecto.to_documents(posts, fields)
      [%{title: "A", body: "1"}, %{title: "B", body: "2"}]

  """
  @spec to_documents([map() | struct()], [field_mapping()]) :: [map()]
  def to_documents(records, fields) when is_list(records) and is_list(fields) do
    Enum.map(records, &to_document(&1, fields))
  end

  @doc """
  Indexes a single record into the named index, then commits.

  Convenience function that converts the record to a document,
  adds it to the index, and commits in one step.

  Returns `:ok` or `{:error, reason}`.

  ## Examples

      SearchTantivy.Ecto.index_one(:blog_posts, post, @search_fields)

  """
  @spec index_one(atom(), map() | struct(), [field_mapping()]) :: :ok | {:error, term()}
  def index_one(index_name, record, fields) do
    via = SearchTantivy.IndexRegistry.via(index_name)
    doc = to_document(record, fields)

    with :ok <- SearchTantivy.Index.add_documents(via, [doc]) do
      SearchTantivy.Index.commit(via)
    end
  end

  @doc """
  Indexes a list of records into the named index, then commits.

  Converts all records to documents, adds them in a single batch,
  and commits once. More efficient than calling `index_one/3` in a loop.

  Returns `:ok` or `{:error, reason}`.

  ## Examples

      posts = Repo.all(Post)
      SearchTantivy.Ecto.index_all(:blog_posts, posts, @search_fields)

  """
  @spec index_all(atom(), [map() | struct()], [field_mapping()]) :: :ok | {:error, term()}
  def index_all(index_name, records, fields) when is_list(records) do
    via = SearchTantivy.IndexRegistry.via(index_name)
    docs = to_documents(records, fields)

    with :ok <- SearchTantivy.Index.add_documents(via, docs) do
      SearchTantivy.Index.commit(via)
    end
  end

  @doc """
  Builds a SearchTantivy schema from a field mapping list.

  Passes the field mapping directly to `SearchTantivy.Schema.build!/1`.
  This lets you use the same `@search_fields` module attribute for
  both schema creation and document conversion.

  ## Examples

      @search_fields [
        {:title, :text, stored: true},
        {:body, :text, stored: true}
      ]

      schema = SearchTantivy.Ecto.build_schema!(@search_fields)
      {:ok, _index} = SearchTantivy.create_index(:blog, schema)

  """
  @spec build_schema!([field_mapping()]) :: SearchTantivy.Schema.t()
  def build_schema!(fields) when is_list(fields) do
    SearchTantivy.Schema.build!(fields)
  end

  @doc """
  Deletes a record from the index by a unique field value, then commits.

  Typically used with a slug, ID, or other unique identifier field.

  ## Examples

      SearchTantivy.Ecto.delete_one(:blog_posts, :slug, post.slug)

  """
  @spec delete_one(atom(), atom(), term()) :: :ok | {:error, term()}
  def delete_one(index_name, field, value) do
    via = SearchTantivy.IndexRegistry.via(index_name)

    with :ok <- SearchTantivy.Index.delete_documents(via, field, value) do
      SearchTantivy.Index.commit(via)
    end
  end

  # --- Private ---

  defp get_field(map, field) when is_map(map), do: Map.get(map, field)
end
