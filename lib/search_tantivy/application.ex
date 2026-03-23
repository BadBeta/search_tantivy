defmodule SearchTantivy.Application do
  @moduledoc """
  Optional application callback for supervised index management.

  SearchTantivy is a library — it does not auto-start processes. To use
  supervised indexes, add `SearchTantivy.Application` to your application's
  supervision tree:

      # In your application.ex
      children = [
        SearchTantivy.Application,
        # ... your other children
      ]

  For unsupervised usage (scripts, tests), call
  `SearchTantivy.Index.start_link/1` directly.
  """
  use Supervisor

  @doc false
  def start_link(init_arg \\ []) do
    Supervisor.start_link(__MODULE__, init_arg, name: SearchTantivy.Supervisor)
  end

  @impl true
  def init(_init_arg) do
    children = [
      SearchTantivy.IndexRegistry,
      SearchTantivy.IndexSupervisor
    ]

    # :one_for_all — Registry must exist before DynamicSupervisor
    Supervisor.init(children, strategy: :one_for_all)
  end
end
