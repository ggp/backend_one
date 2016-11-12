defmodule BackendOne.AccumulatorServiceTest do
  use ExUnit.Case
  import MessageBuilder
  alias BackendOne.AccumulatorService, as: AccumulatorService

  setup_all do
    :ok = Application.stop(:backend_one)
    :ok
  end

  setup do
    test_pid = self
    mock = fn msg ->
      send test_pid, {:publish_from_mock, msg}
    end

    {:ok, pid} = BackendOne.AccumulatorService.start_link [mock]
    {:ok, [pid: pid]}
  end

  test "publish message when accumulator return it" do
    AccumulatorService.async_add(new_int_temp(value: 21.67, time: now))
    AccumulatorService.async_add(new_int_temp(value: 22.55, time: after_1_min))
    AccumulatorService.async_add(new_ext_temp(value: 39.45, time: now))
    AccumulatorService.async_add(new_ext_temp(value: 40.44, time: after_1_min))
    AccumulatorService.async_add(new_ppl_cntr(value: +1, time: now))
    AccumulatorService.async_add(new_ppl_cntr(value: -1, time: after_1_min))
    AccumulatorService.async_add(Receipt.new(666, seller_id, 99.43, now))

    assert_receive({:publish_from_mock, %{
      external_avg_temperature: 39.45,
      internal_avg_temperature: 21.67,
      people: 1,
      receipt: %{
        amount: 99.43,
        date: unquote(formatted_now),
        id: 666,
      },
    }}, 5000)
  end

end
