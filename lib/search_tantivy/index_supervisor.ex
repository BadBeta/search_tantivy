defmodule SearchTantivy.IndexSupervisor do
  @moduledoc false
  use DynamicSupervisor

  @doc false
  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @doc false
  @spec start_index(Supervisor.child_spec() | {module(), term()}) ::
          DynamicSupervisor.on_start_child()
  def start_index(child_spec) do
    DynamicSupervisor.start_child(__MODULE__, child_spec)
  end
end
