defmodule Gnat.ConnectionSupervisor do
  use GenServer
  require Logger

  @moduledoc """
  A process that can supervise a named connection for you

  If you would like to supervise a Gnat connection and have it automatically re-connect in case of failure you can use this module in your supervision tree.
  It takes a map with the following data:

  ```
  gnat_supervisor_settings = %{
    name: :gnat, # (required) the registered named you want to give the Gnat connection
    backoff_period: 4_000, # number of milliseconds to wait between consecurity reconnect attempts (default: 2_000)
    connection_settings: [
      %{host: '10.0.0.100', port: 4222},
      %{host: '10.0.0.101', port: 4222},
    ]
  }
  ```

  The connection settings can specify all of the same values that you pass to `Gnat.start_start_link/1`. Each time a connection is attempted we will use one of the provided connection settings to open the connection. This is a simplistic way of load balancing your connections across a cluster of nats nodes and allowing failove to other nodes in the cluster if one goes down.

  To use this in your supervision tree add an entry like this:

  ```
  import Supervisor.Spec
  worker(Gnat.ConnectionSupervisor, [gnat_supervisor_settings])
  ```
  """

  def start_link(options) do
    GenServer.start_link(__MODULE__, options, name: __MODULE__)
  end

  def init(options) do
    state = %{
      backoff_period: Map.get(options, :backoff_period, 2000),
      connection_settings: Map.fetch!(options, :connection_settings),
      name: Map.fetch!(options, :name),
      gnat: nil,
    }
    Process.flag(:trap_exit, true)
    send self(), :attempt_connection
    {:ok, state}
  end

  def handle_info(:attempt_connection, state) do
    connection_config = random_connection_config(state)
    Logger.info "connecting to #{inspect connection_config}"
    case Gnat.start_link(connection_config, name: state.name) do
      {:ok, gnat} -> {:noreply, %{state | gnat: gnat}}
      {:error, err} ->
        Logger.error "failed to connect #{inspect err}"
        {:noreply, %{state | gnat: nil}} # we will get an :EXIT message and handle it there
    end
  end
  def handle_info({:EXIT, _pid, reason}, %{gnat: nil}=state) do
    Logger.error "failed to connect #{inspect reason}"
    Process.send_after(self(), :attempt_connection, state.backoff_period)
    {:noreply, state}
  end
  def handle_info({:EXIT, _pid, reason}, state) do
    Logger.error "connection failed #{inspect reason}"
    send self(), :attempt_connection
    {:noreply, state}
  end
  def handle_info(msg, state) do
    Logger.error "#{__MODULE__} received unexpected message #{inspect msg}"
    {:noreply, state}
  end

  defp random_connection_config(%{connection_settings: connection_settings}) do
    connection_settings |> Enum.random()
  end
end

