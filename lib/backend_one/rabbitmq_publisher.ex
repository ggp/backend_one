defmodule RabbitMQPublisher do
  require Logger

  def publish_stats(%AMQP.Channel{} = channel, stat_msg) do
    Logger.debug ">>> Send stats message with payload: #{inspect stat_msg}"
    :ok = AMQP.Basic.publish(
      channel,
      "stats",
      "amount",
      Poison.encode!(%{
        type: "stats",
        seller_id: stat_msg.seller_id,
        payload: stat_msg
      }))
  end
end
