defmodule SearchTantivy.Call do
  @moduledoc false

  require Logger

  @spec safe_call(GenServer.server(), term(), timeout()) :: term()
  def safe_call(server, message, timeout \\ 5_000) do
    GenServer.call(server, message, timeout)
  catch
    :exit, reason ->
      # §§ elixir-reviewing CE-28 — error path must not be silent
      Logger.warning("safe_call exited: server=#{inspect(server)} reason=#{inspect(reason)}")

      {:error, :not_available}
  end
end
