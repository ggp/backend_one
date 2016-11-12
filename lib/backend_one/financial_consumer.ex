defmodule ReceiptMessage do
  @derive [Poison.Encoder]
  defstruct [:id, :sellerId, :amount, :date, header: [], rows: []]
end

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
    message |> Poison.decode!(as: %ReceiptMessage{}) |> notify
  end

  defp notify(receipt_message) do
    kv = Transformer.translate_keys(Map.from_struct(receipt_message), [
      {:sellerId, :seller_id},
      {:date, :time, fn v -> Timex.parse!(v, "{ISO:Extended}") end}
    ])
    BackendOne.AccumulatorService.async_add(struct!(Receipt, kv))
  end

  def __exchange__, do: @exchange
end
