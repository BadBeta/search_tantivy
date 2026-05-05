defmodule SearchTantivy.IndexRegistry do
  @moduledoc """
  Process registry for `SearchTantivy.Index` GenServers.

  Each index process registers itself under a unique name so callers can
  address it by atom (`:my_index`) without holding a pid. The registry
  is started once by `SearchTantivy.Application` and shared by every
  index in the supervision tree.

  Use `via/1` whenever you need to talk to a named index — it returns
  the `{:via, Registry, _}` tuple that `GenServer.call/3` understands.
  Cross-context callers (e.g. `SearchTantivy.Searcher`,
  `SearchTantivy.Aggregation`) rely on this module — it is part of the
  public API even though instances are typically created indirectly via
  `SearchTantivy.create_index/3`.
  """

  @doc """
  Supervisor child spec for the registry. Called by
  `SearchTantivy.Application` during startup.
  """
  @spec child_spec(term()) :: Supervisor.child_spec()
  def child_spec(_) do
    Registry.child_spec(keys: :unique, name: __MODULE__)
  end

  @doc """
  Returns a `{:via, Registry, _}` tuple for addressing the index named
  `name`. Use as the first argument to `GenServer.call/3` /
  `SearchTantivy.search/3` etc.

  ## Examples

      iex> SearchTantivy.IndexRegistry.via(:my_index)
      {:via, Registry, {SearchTantivy.IndexRegistry, :my_index}}

  """
  @spec via(atom()) :: {:via, Registry, {__MODULE__, atom()}}
  def via(name) do
    {:via, Registry, {__MODULE__, name}}
  end
end
