defmodule BackendOne.FinancialConsumer do
  use GenServer
  require Logger
  alias AMQP.{Basic, Exchange, Channel, Queue}

  @exchange "financial"
  @queue "backend_one_queue"
  @routing_key "#"

  def start_link(connection) do
    GenServer.start_link(__MODULE__, connection, name: __MODULE__)
  end

  ## Callbacks

  @doc false
  def init([connection]) do
    {:ok, channel} = Channel.open(connection)
    Exchange.declare(channel, @exchange, :topic, durable: true)
    Queue.declare(channel, @queue, durable: true)
    Queue.bind(channel, @queue, @exchange, routing_key: @routing_key)
    Basic.consume(channel, @queue, nil, [])
    Logger.info "Connect to exchange: #{@exchange} with queue: #{@queue} with rk: #{@routing_key}"
    {:ok, channel}
  end

  def handle_info({:basic_consume_ok, %{consumer_tag: consumer_tag}}, channel) do
    Logger.debug "#{consumer_tag} is registered as a consumer."
    {:noreply, channel}
  end

  def handle_info({:basic_deliver, payload, meta}, channel) do
    # Logger.debug "Consumed payload #{payload} from #{@queue}"
    dispatch_message(payload)
    AMQP.Basic.ack(channel, meta.delivery_tag)
    {:noreply, channel}
  end

  def handle_info(_, channel) do
    Logger.warn "Unknown message for FinancialConsumer #{self.inspect}"
    {:noreply, channel}
  end

  defp dispatch_message(message) do
    Logger.debug "Receipt: #{message}"
    message |> Poison.decode!() |> notify
  end

  defp notify(receipt) do
    send BackendOne.Accumulator, {:receipt, receipt}
  end

  def __routing_key__, do: @routing_key
  def __exchange__, do: @exchange
end
