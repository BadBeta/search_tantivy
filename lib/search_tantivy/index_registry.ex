defmodule SearchTantivy.IndexRegistry do
  @moduledoc false

  @doc false
  def child_spec(_) do
    Registry.child_spec(keys: :unique, name: __MODULE__)
  end

  @doc false
  @spec via(atom()) :: {:via, Registry, {__MODULE__, atom()}}
  def via(name) do
    {:via, Registry, {__MODULE__, name}}
  end
end
