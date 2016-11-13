defmodule BackendOne.DeviceConsumer do
  use GenServer
  require Logger
  alias AMQP.{Basic, Channel, Queue}

  @exchange "amq.topic"
  @queue "MQTT"
  @routing_key "#"

  def start_link(connection) do
    GenServer.start_link(__MODULE__, connection, name: __MODULE__)
  end

  def init([connection]) do
    {:ok, channel} = Channel.open(connection)
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
    Logger.warn "Unknown message for DeviceConsumer #{self.inspect}"
    {:noreply, channel}
  end

  defp dispatch_message(<<type::size(8), value::big-signed-integer-size(32)>>) do
    print_message(type, value)
  end

  defp dispatch_message(<<seller_id::big-unsigned-integer-size(16), type_id::size(8), time::big-unsigned-integer-size(32), value::big-signed-integer-size(16)>>) do
    print_message(type_id, seller_id, time, value)
    notify(DeviceMessage.new(
      DeviceMessage.type_from(type_id),
      seller_id,
      value,
      Timex.from_unix(time)))
  end

  defp dispatch_message(message) do
    print_message(message)
  end

  def print_message(0, number) do
    Logger.debug "People: #{number}"
  end

  def print_message(1, number) do
    Logger.debug "External temperature: #{number}"
  end

  def print_message(2, number) do
    Logger.debug "Internal temperature : #{number}"
  end

  def print_message(_, number) do
    Logger.debug "La muerte : #{number}"
  end

  def print_message(0, seller_id, time, value) do
    Logger.debug "People from seller #{seller_id} at #{format(time)} are #{value}"
  end

  def print_message(1, seller_id, time, value) do
    Logger.debug "External temperature at seller #{seller_id} at #{format(time)} is #{value}"
  end

  def print_message(2, seller_id, time, value) do
    Logger.debug "Internal temperature at seller #{seller_id} at #{format(time)} is #{value}"
  end

  defp print_message(message) do
    Logger.debug "Unable to parse message: #{inspect message}"
  end

  defp format(time) do
    Timex.from_unix(time)
      |> Timex.Timezone.convert(Timex.Timezone.local)
      |> Timex.format!("{ISOdate} {ISOtime}")
  end

  defp notify(message) do
    BackendOne.AccumulatorService.async_add message
  end
end
