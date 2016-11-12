defmodule BackendOneTest do
  use ExUnit.Case
  doctest BackendOne
  require Logger

  @seller_id 42
  @receipt_id 666

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
    receipt_dt = Timex.shift(now, seconds: 18)
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

    send_example_receipt(receipt_dt)

    fdt = Timex.format!(receipt_dt, "{ISO:Extended:Z}")
    assert_receive({:test_consumer, %{
      "type" => "stats",
      "seller_id" => unquote(@seller_id),
      "payload" => %{
        "receipt" => %{ "date" => fdt, "id" => unquote(@receipt_id)},
        "internal_avg_temperature" => 23.00,
        "external_avg_temperature" => 13.00,
        "people" => 1,
        "seller_id" => unquote(@seller_id),
      },
    }}, 5000)
  end
end
