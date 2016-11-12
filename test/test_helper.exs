ExUnit.start()

defmodule MessageBuilder do
  @now Timex.to_datetime({{2016, 01, 01}, {15, 42, 13}})
  @rounded_now Timex.to_datetime({{2016, 01, 01}, {15, 42, 00}})
  @after_1_min Timex.shift(@now, minutes: 1)
  @seller_id 42
  @receipt_id 666

  def seller_id, do: @seller_id
  def rounded_now, do: @rounded_now
  def receipt_id, do: @receipt_id
  def now, do: @now
  def after_1_min, do: @after_1_min
  def formatted_now, do: Timex.format!(now, "{ISO:Extended:Z}")

  def new_dev_msg(args) do
    type = Keyword.fetch!(args, :type)
    value = Keyword.fetch!(args, :value)
    seller_id = Keyword.get(args, :seller_id, @seller_id)
    time = Keyword.get(args, :time, @now)
    DeviceMessage.new(type, seller_id, value, time)
  end

  def new_int_temp(args) do
    new_dev_msg(Keyword.merge(args, type: :int))
  end

  def new_ext_temp(args) do
    new_dev_msg(Keyword.merge(args, type: :ext))
  end

  def new_ppl_cntr(args) do
    new_dev_msg(Keyword.merge(args, type: :ppl))
  end

end

defmodule RabbitHelper do
  require Logger
  @otp_app Mix.Project.config[:app]
  @queue "test_queue"

  def mqtt_publish(msg, rabbit_opts \\ []) do
    amqp_opts = Application.get_env(Mix.Project.config[:app], :amqp) || rabbit_opts
    Logger.debug(">>> Publish MQTT message: #{inspect msg} with opts: #{inspect amqp_opts}")
    {:ok, connection} = AMQP.Connection.open(amqp_opts)
    {:ok, channel} = AMQP.Channel.open(connection)
    :ok = AMQP.Basic.publish(channel, "", "MQTT", msg)
  end

  def publish(exchange, rk, msg, rabbit_opts \\ []) do
    amqp_opts = Application.get_env(Mix.Project.config[:app], :amqp) || rabbit_opts
    Logger.debug(">>> Publish message: #{inspect msg} on exchange: #{exchange} with rk: #{rk} with opts: #{inspect amqp_opts}")
    {:ok, connection} = AMQP.Connection.open(amqp_opts)
    {:ok, channel} = AMQP.Channel.open(connection)
    AMQP.Exchange.declare(channel, exchange, :topic, durable: true)
    :ok = AMQP.Basic.publish(channel, exchange, rk, Poison.encode!(msg))
  end

  def listen_on(exchange, rk, on_msg) do
    amqp_opts = Application.get_env(@otp_app, :amqp) || []
    Logger.debug "amqp_opts: #{inspect amqp_opts}"
    {:ok, connection} = AMQP.Connection.open(amqp_opts)
    {:ok, channel} = AMQP.Channel.open(connection)
    AMQP.Exchange.declare(channel, exchange, :topic, durable: true)
    AMQP.Queue.declare(channel, @queue, durable: false)
    AMQP.Queue.bind(channel, @queue, exchange, routing_key: rk)
    AMQP.Queue.subscribe(channel, @queue, on_msg)
  end
end
