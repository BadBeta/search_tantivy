defmodule SearchTantivy.CallTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias SearchTantivy.Call

  describe "safe_call/3" do
    test "returns {:error, :not_available} when the target process is missing" do
      assert {:error, :not_available} = Call.safe_call(:nonexistent_process_xyz, :ping)
    end

    test "logs a warning with the server and exit reason on :exit" do
      log =
        capture_log(fn ->
          Call.safe_call(:nonexistent_process_xyz, :ping)
        end)

      assert log =~ "safe_call exited"
      assert log =~ "nonexistent_process_xyz"
    end

    test "returns the GenServer reply on success" do
      {:ok, server} =
        GenServer.start_link(SearchTantivy.CallTest.Echo, :ok)

      assert :pong = Call.safe_call(server, :ping)
    end
  end

  defmodule Echo do
    @moduledoc false
    use GenServer
    @impl true
    def init(:ok), do: {:ok, %{}}
    @impl true
    def handle_call(:ping, _from, state), do: {:reply, :pong, state}
  end
end
