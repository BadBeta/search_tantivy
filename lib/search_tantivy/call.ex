defmodule SearchTantivy.Call do
  @moduledoc false

  @spec safe_call(GenServer.server(), term(), timeout()) :: term()
  def safe_call(server, message, timeout \\ 5_000) do
    GenServer.call(server, message, timeout)
  catch
    :exit, _ -> {:error, :not_available}
  end
end
