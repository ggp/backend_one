defmodule BackendOneTest do
  use ExUnit.Case
  doctest BackendOne
  require Logger

  @seller_id 42
  @receipt_id 666

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

  defp send_internal_temperature(key_values) do
    date_time = Keyword.fetch!(key_values, :date_time)
    value = Keyword.fetch!(key_values, :value)
    msg = <<@seller_id::big-unsigned-integer-size(16),
      2::size(8),
      Timex.to_unix(date_time)::big-unsigned-integer-size(32),
      value::big-signed-integer-size(16)>>
    RabbitHelper.mqtt_publish(msg)
  end

  defp send_external_temperature(key_values) do
    date_time = Keyword.fetch!(key_values, :date_time)
    value = Keyword.fetch!(key_values, :value)
    msg = <<@seller_id::big-unsigned-integer-size(16),
      1::size(8),
      Timex.to_unix(date_time)::big-unsigned-integer-size(32),
      value::big-signed-integer-size(16)>>
    RabbitHelper.mqtt_publish(msg)
  end

  defp send_people_counter(key_values) do
    date_time = Keyword.fetch!(key_values, :date_time)
    value = Keyword.fetch!(key_values, :value)
    msg = <<@seller_id::big-unsigned-integer-size(16),
      0::size(8),
      Timex.to_unix(date_time)::big-unsigned-integer-size(32),
      value::big-signed-integer-size(16)>>
    RabbitHelper.mqtt_publish(msg)
  end

  defp send_example_receipt(at) do
    receipt = %{
      "id" => @receipt_id,
      "date" => Timex.format!(at, "{ISO:Extended:Z}"),
      "sellerId" => @seller_id,
    }
    RabbitHelper.publish(
      BackendOne.FinancialConsumer.__exchange__,
      "test.receipts",
      receipt)
    receipt
  end

  test "Aggregate and publish internal temperature base on same minute on receipt" do
    to = self
    now = Timex.to_datetime({{2016, 01, 01}, {15, 42, 00}})
    RabbitHelper.listen_on("stats", "amount", fn (payload, _meta) ->
      Logger.debug "<<< RECEIVED message in stats queue"
      send(to, {:test_consumer, Poison.decode!(payload)})
    end)
    send_internal_temperature(value: 22, date_time: Timex.shift(now, seconds: 10))
    send_internal_temperature(value: 23, date_time: Timex.shift(now, seconds: 20))
    send_internal_temperature(value: 24, date_time: Timex.shift(now, seconds: 30))
    send_internal_temperature(value: 50, date_time: Timex.shift(now, minutes: 1))

    send_external_temperature(value: 12, date_time: Timex.shift(now, seconds: 21))
    send_external_temperature(value: 13, date_time: Timex.shift(now, seconds: 41))
    send_external_temperature(value: 14, date_time: Timex.shift(now, seconds: 51))
    send_external_temperature(value: 100, date_time: Timex.shift(now, minutes: 1))

    send_people_counter(value: 1, date_time: now)
    send_people_counter(value: 1, date_time: now)
    send_people_counter(value: -1, date_time: now)
    send_people_counter(value: -1, date_time: Timex.shift(now, minutes: 1))

    receipt_dt = Timex.shift(now, seconds: 18)
    send_example_receipt receipt_dt

    assert_receive({:test_consumer, %{
      "type" => "stats",
      "seller_id" => unquote(@seller_id),
      "payload" => %{
        "receipt" => %{ "date" => receipt_dt, "id" => unquote(@receipt_id)},
        "internal_avg_temperature" => 23.00,
        "external_avg_temperature" => 13.00,
        "people" => 1,
      }
    }}, 5000)
  end
end
