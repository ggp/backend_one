defmodule BackendOne.AccumulatorService do
  use GenServer
  require Logger

  def start_link(publisher) do
    GenServer.start_link(__MODULE__, publisher, name: __MODULE__)
  end

  def init([publisher]) do
    {:ok, %{publisher: publisher, aggregate: %Aggregate{}}}
  end

  def async_add(msg) do
    GenServer.cast(__MODULE__, msg)
  end

  def handle_cast(%DeviceMessage{} = message, state) do
    {act, agr, msg} = Aggregate.add(state.aggregate, message)
    publish(state.publisher, act, msg)
    {:noreply, Map.put(state, :aggregate, agr)}
  end

  def handle_cast(%Receipt{} = message, state) do
    {act, agr, msg} = Aggregate.add(state.aggregate, message)
    publish(state.publisher, act, msg)
    {:noreply, Map.put(state, :aggregate, agr)}
  end

  defp publish(publisher, :send, msg), do: publisher.(msg)
  defp publish(_, _, _) do end

end
