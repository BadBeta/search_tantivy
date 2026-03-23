defmodule SearchTantivy.Index do
  @moduledoc """
  Manages index lifecycle via GenServer.

  The GenServer wraps tantivy's IndexWriter, which requires serialized access.
  IndexReaders are thread-safe and created on demand without process overhead.

  Business logic lives in private pure functions. The GenServer handles
  process mechanics only.

  ## Usage

  Indexes can be used supervised (via `SearchTantivy.IndexSupervisor`) or
  unsupervised (via `start_link/1` directly):

      # Supervised — registered by name, automatically restarted
      {:ok, pid} = SearchTantivy.create_index(:blog, schema, path: "/tmp/blog")

      # Unsupervised — for scripts, tests, one-off use
      {:ok, pid} = SearchTantivy.Index.start_link(name: :test, schema: schema)

  """
  use GenServer

  require Logger

  @type t :: GenServer.server()

  @default_memory_budget 50_000_000

  # --- Client API ---

  @doc """
  Creates a new index.

  ## Options

    * `:path` - directory for persistent storage (omit for RAM index)
    * `:memory_budget` - writer memory budget in bytes (default: 50MB)

  """
  @spec create(atom(), SearchTantivy.Schema.t(), keyword()) :: {:ok, t()} | {:error, term()}
  def create(name, schema, opts \\ []) do
    child_spec = {__MODULE__, Keyword.merge(opts, name: name, schema: schema)}

    case SearchTantivy.IndexSupervisor.start_index(child_spec) do
      {:ok, pid} -> {:ok, pid}
      {:error, {:already_started, pid}} -> {:ok, pid}
      {:error, _} = error -> error
    end
  end

  @doc """
  Opens an existing index from disk.
  """
  @spec open(atom(), String.t()) :: {:ok, t()} | {:error, term()}
  def open(name, path) when is_atom(name) and is_binary(path) do
    child_spec = {__MODULE__, name: name, path: path, open: true}

    case SearchTantivy.IndexSupervisor.start_index(child_spec) do
      {:ok, pid} -> {:ok, pid}
      {:error, {:already_started, pid}} -> {:ok, pid}
      {:error, _} = error -> error
    end
  end

  @doc """
  Adds documents to the index. Documents are maps with atom keys.

  Documents are buffered in the writer. Call `commit/1` to make them searchable.
  """
  @spec add_documents(t(), [map()], timeout()) :: :ok | {:error, term()}
  def add_documents(index, documents, timeout \\ 30_000) when is_list(documents) do
    GenServer.call(index, {:add_documents, documents}, timeout)
  end

  @doc """
  Adds documents and commits in one step.

  Convenience function that combines `add_documents/2` and `commit/1`.

  ## Examples

      :ok = SearchTantivy.Index.add_and_commit(index, [
        %{title: "Hello", body: "World"}
      ])

  """
  @spec add_and_commit(t(), [map()], timeout()) :: :ok | {:error, term()}
  def add_and_commit(index, documents, timeout \\ 30_000) when is_list(documents) do
    with :ok <- add_documents(index, documents, timeout) do
      commit(index)
    end
  end

  @doc """
  Deletes documents matching the given field and value.
  """
  @spec delete_documents(t(), atom(), term()) :: :ok | {:error, term()}
  def delete_documents(index, field, value) when is_atom(field) do
    GenServer.call(index, {:delete_documents, field, value})
  end

  @doc """
  Commits pending changes, making them visible to readers.

  Returns `{:ok, opstamp}` where `opstamp` is a monotonically increasing
  operation identifier.
  """
  @spec commit(t()) :: :ok | {:error, term()}
  def commit(index) do
    GenServer.call(index, :commit, 30_000)
  end

  @doc """
  Gets a reader handle for searching.

  Readers are thread-safe and lightweight. They can be used concurrently
  from multiple processes.
  """
  @spec reader(t()) :: {:ok, reference()} | {:error, term()}
  def reader(index) do
    GenServer.call(index, :reader)
  end

  @doc """
  Gets the raw index reference for query parsing.
  """
  @spec index_ref(t()) :: {:ok, reference()} | {:error, term()}
  def index_ref(index) do
    GenServer.call(index, :index_ref)
  end

  @doc """
  Gets the schema reference from the index.
  """
  @spec schema_ref(t()) :: {:ok, reference()} | {:error, term()}
  def schema_ref(index) do
    GenServer.call(index, :schema_ref)
  end

  @doc """
  Stops the index GenServer gracefully.
  """
  @spec close(t()) :: :ok
  def close(index) do
    GenServer.stop(index, :normal)
  end

  # --- Child Spec ---

  @doc false
  def child_spec(opts) do
    name = Keyword.fetch!(opts, :name)

    %{
      id: {__MODULE__, name},
      start: {__MODULE__, :start_link, [opts]},
      restart: :transient,
      type: :worker
    }
  end

  # --- Start ---

  @doc false
  def start_link(opts) do
    name = Keyword.fetch!(opts, :name)
    GenServer.start_link(__MODULE__, opts, name: SearchTantivy.IndexRegistry.via(name))
  end

  # --- Server Callbacks ---

  @impl true
  def init(opts) do
    Process.flag(:trap_exit, true)

    case do_initialize(opts) do
      {:ok, state} ->
        {:ok, state}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  @impl true
  def handle_call({:add_documents, documents}, _from, state) do
    case do_add_documents(state, documents) do
      :ok -> {:reply, :ok, state}
      {:error, _} = error -> {:reply, error, state}
    end
  end

  @impl true
  def handle_call({:delete_documents, field, value}, _from, state) do
    case SearchTantivy.Native.writer_delete_documents(
           state.writer_ref,
           Atom.to_string(field),
           to_string(value)
         ) do
      {:ok, _} -> {:reply, :ok, state}
      {:error, _} = error -> {:reply, error, state}
    end
  end

  @impl true
  def handle_call(:commit, _from, state) do
    case SearchTantivy.Native.writer_commit(state.writer_ref) do
      {:ok, _opstamp} -> {:reply, :ok, state}
      {:error, _} = error -> {:reply, error, state}
    end
  end

  @impl true
  def handle_call(:reader, _from, state) do
    {:reply, SearchTantivy.Native.index_reader(state.index_ref), state}
  end

  @impl true
  def handle_call(:index_ref, _from, state) do
    {:reply, {:ok, state.index_ref}, state}
  end

  @impl true
  def handle_call(:schema_ref, _from, state) do
    {:reply, {:ok, state.schema_ref}, state}
  end

  @impl true
  def handle_info(msg, state) do
    Logger.warning("SearchTantivy.Index received unexpected message: #{inspect(msg)}")
    {:noreply, state}
  end

  @impl true
  def terminate(reason, %{writer_ref: writer_ref}) do
    Logger.info(
      "SearchTantivy.Index terminating (#{inspect(reason)}), committing pending changes..."
    )

    case SearchTantivy.Native.writer_commit(writer_ref) do
      {:ok, _} -> :ok
      {:error, reason} -> Logger.warning("Failed to commit on shutdown: #{inspect(reason)}")
    end

    :ok
  end

  def terminate(_reason, _state), do: :ok

  @impl true
  def format_status(status) do
    Map.update(status, :state, %{}, fn state ->
      Map.drop(state, [:index_ref, :writer_ref, :schema_ref])
    end)
  end

  # --- Private ---

  defp do_initialize(opts) do
    if opts[:open] do
      do_open_index(opts)
    else
      do_create_index(opts)
    end
  end

  defp do_create_index(opts) do
    schema = Keyword.fetch!(opts, :schema)
    memory_budget = Keyword.get(opts, :memory_budget, @default_memory_budget)

    index_result =
      case Keyword.get(opts, :path) do
        nil -> SearchTantivy.Native.index_create_in_ram(schema)
        path -> SearchTantivy.Native.index_create(schema, path)
      end

    with {:ok, index_ref} <- index_result,
         {:ok, writer_ref} <- SearchTantivy.Native.index_writer_new(index_ref, memory_budget) do
      {:ok,
       %{
         name: Keyword.fetch!(opts, :name),
         index_ref: index_ref,
         writer_ref: writer_ref,
         schema_ref: schema,
         path: Keyword.get(opts, :path)
       }}
    end
  end

  defp do_open_index(opts) do
    path = Keyword.fetch!(opts, :path)
    memory_budget = Keyword.get(opts, :memory_budget, @default_memory_budget)

    with {:ok, index_ref} <- SearchTantivy.Native.index_open(path),
         {:ok, writer_ref} <- SearchTantivy.Native.index_writer_new(index_ref, memory_budget) do
      {:ok,
       %{
         name: Keyword.fetch!(opts, :name),
         index_ref: index_ref,
         writer_ref: writer_ref,
         schema_ref: nil,
         path: path
       }}
    end
  end

  defp do_add_documents(state, documents) do
    Enum.reduce_while(documents, :ok, fn doc_map, :ok ->
      field_values =
        Enum.map(doc_map, fn {k, v} ->
          {Atom.to_string(k), SearchTantivy.Value.to_string_value(v)}
        end)

      with {:ok, doc_ref} <- SearchTantivy.Native.document_create(state.schema_ref, field_values),
           {:ok, _} <- SearchTantivy.Native.writer_add_document(state.writer_ref, doc_ref) do
        {:cont, :ok}
      else
        {:error, _} = error -> {:halt, error}
      end
    end)
  end
end
