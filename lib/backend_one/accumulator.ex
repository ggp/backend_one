defmodule BackendOne.Accumulator do
  require Logger

  @initial_state %{
    internal_avg_temperature: %{},
    external_avg_temperature: %{},
    people: %{},
    receipt: %{},
  }

  def run(channel, state \\ @initial_state) do
    {new_state, time, seller_id} = receive do
      {:receipt, receipt} ->
        Logger.debug("[BackendOne.Accumulator] receive receipt: #{inspect receipt}")
        t = Map.get(receipt, "date")
          |> Timex.parse!("{ISO:Extended}")
          |> Timex.to_datetime
          |> get_time_minutes_rounded
        s = update_state_with_receipt(state, receipt, t)
        {s, t, Map.get(receipt, "sellerId")}
      {:device, message} ->
        Logger.debug("[BackendOne.Accumulator] receive device: #{inspect message}")
        t = get_time_minutes_rounded(Timex.from_unix(message.time))
        s = update_state(state, message, t)
        {s, t, nil}
      msg ->
        Logger.debug("[BackendOne.Accumulator] receive unknown message: #{inspect msg}")
        {state, nil}
    end
    Logger.debug("State was:\n#{inspect state}\nnow is:\n#{inspect new_state}")
    publish_stats_message(channel, new_state, time, seller_id)
    run(channel, new_state)
  end

  defp get_time_minutes_rounded(time) do
    {date, {h, m, _s}} = Timex.to_erl(time)
    Timex.to_datetime({date, {h, m, 0}}, time.time_zone)
  end

  defp update_state_with_receipt(state, receipt, time) do
    Map.merge(state, %{ receipt: increase_map_list(state.receipt, receipt, time) })
  end

  # people
  defp update_state(state, %{type: 0} = message, time) do
    Map.merge(state, %{ people: increase_map_counter(state.people, message.value, time) })
  end

  # external temperature
  defp update_state(state, %{type: 1} = message, time) do
    Map.merge(state, %{ external_avg_temperature: increase_map_average(state.external_avg_temperature, message.value, time) })
  end

  # internal temperature
  defp update_state(state, %{type: 2} = message, time) do
    Map.merge(state, %{ internal_avg_temperature: increase_map_average(state.internal_avg_temperature, message.value, time) })
  end

  defp publish_stats_message(channel, state, time, seller_id) do
    [:internal_avg_temperature, :external_avg_temperature, :people]
      |> Enum.reduce({true, %{}}, fn key, {all, msg} ->
        filled = Map.get(state, key) |> Map.get(Timex.shift(time, minutes: 1))
        Logger.debug "Key #{inspect key} is present? #{inspect bool(filled)}"
        value = get_value(state, key, time)
        {bool(all && filled), Map.put(msg, key, value)}
      end)
      |> merge_receipt(state, time)
      |> do_publish_stats_message(channel, seller_id)
    state
  end

  defp get_value(state, :people = key, time) do
    Map.get(state, key) |> Map.get(time)
  end

  defp get_value(state, key, time) do
    m = Map.get(state, key) |> Map.get(time)
    m && Map.get(m, :value)
  end

  defp merge_receipt({filled, msg}, state, time) do
    value = Map.get(state, :receipt) |> Map.get(time, [nil]) |> hd
    Logger.debug "Receipt is present? #{inspect bool(filled && value)} #{inspect value}"
    {bool(filled && value), value && Map.put(msg, :receipt, %{
      "date" => Map.get(value, "date"),
      "id" => Map.get(value, "id"),
      "seller_id" => Map.get(value, "sellerId"),
      "amount" => Map.get(value, "totalAmount")
    })}
  end

  defp do_publish_stats_message({true, payload}, channel, seller_id) do
    Logger.info ">>> Send message with payload: #{inspect payload}"
    :ok = AMQP.Basic.publish(
      channel,
      "stats",
      "amount",
      Poison.encode!(%{
        type: "stats",
        seller_id: seller_id,
        payload: payload,
      }))
  end

  defp do_publish_stats_message({_, msg}, _, _) do
    Logger.debug "WAIT for send message, now message is #{inspect msg}"
  end

  defp increase_map_average(map, value, time) do
    Map.update(map, time, %{value: value, total: value, count: 1}, fn m ->
      t = m.total + value
      c = m.count + 1
      %{ value: t / c, total: t, count: c }
    end)
  end

  defp increase_map_counter(map, value, time) do
    Map.update(map, time, value, &(value + &1))
  end

  defp increase_map_list(map, value, time) do
    Map.update(map, time, [value], &([value | &1]))
  end

  defp bool(v) do
    if v, do: true, else: false
  end

end
