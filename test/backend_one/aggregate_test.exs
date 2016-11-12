defmodule BackendOne.AggregateTest do
  use ExUnit.Case

  import MessageBuilder

  test "add a device message and does not return message to send" do
    {:wait, agr, nil} = Aggregate.add(%Aggregate{}, new_int_temp(value: 22))

    assert(agr == %Aggregate{
      sellers: %{
        seller_id => %Seller{
          :id => seller_id,
          data: %{
            rounded_now => %SellerData{
              int_avg_temp: %AvgMap{ avg: 22, total: 22, count: 1 }
            }
          }
        }
      }
    })
  end

  test "add a receipt and return wait" do
    {:wait, agr, nil} = Aggregate.add(%Aggregate{}, Receipt.new(receipt_id, seller_id, 123.00, now))

    assert(agr == %Aggregate{
      sellers: %{
        seller_id => %Seller{
          :id => seller_id,
          data: %{
            rounded_now => %SellerData{
              receipt: Receipt.new(receipt_id, seller_id, 123.00, now)
            }
          }
        }
      }
    })
  end

  test "add 2 device message and increment avg" do
    agr = %Aggregate{}
    {:wait, agr, nil} = Aggregate.add(agr, new_int_temp(value: 20, time: now))
    {:wait, agr, nil} = Aggregate.add(agr, new_int_temp(value: 30, time: Timex.shift(now, seconds: 1)))
    assert(agr == %Aggregate{
      sellers: %{
        seller_id => %Seller{
          :id => seller_id,
          data: %{
            rounded_now => %SellerData{
              int_avg_temp: %AvgMap{ avg: 25, total: 50, count: 2 }
            }
          }
        }
      }
    })
  end

  test "add some device messages" do
    agr = %Aggregate{}
    {:wait, agr, nil} = Aggregate.add(agr, new_int_temp(value: 22, time: now))
    {:wait, agr, nil} = Aggregate.add(agr, new_int_temp(value: 24, time: Timex.shift(now, seconds: 1)))
    {:wait, agr, nil} = Aggregate.add(agr, new_ext_temp(value: 40, time: now))
    {:wait, agr, nil} = Aggregate.add(agr, new_ext_temp(value: 44, time: Timex.shift(now, seconds: 1)))
    {:wait, agr, nil} = Aggregate.add(agr, new_ppl_cntr(value: +1, time: now))
    {:wait, agr, nil} = Aggregate.add(agr, new_ppl_cntr(value: +1, time: Timex.shift(now, seconds: 1)))
    assert(agr == %Aggregate{
      sellers: %{
        seller_id => %Seller{
          :id => seller_id,
          data: %{
            rounded_now => %SellerData{
              int_avg_temp: %AvgMap{ avg: 23, total: 46, count: 2 },
              ext_avg_temp: %AvgMap{ avg: 42, total: 84, count: 2 },
              people: 2
            }
          }
        }
      }
    })
  end

  test "return send when we have all data for a minute" do
    agg = %Aggregate{}
    {:wait, agg, nil} = Aggregate.add(agg, new_int_temp(value: 22, time: now))
    {:wait, agg, nil} = Aggregate.add(agg, new_int_temp(value: 25, time: after_1_min))
    {:wait, agg, nil} = Aggregate.add(agg, new_ext_temp(value: 40, time: now))
    {:wait, agg, nil} = Aggregate.add(agg, new_ext_temp(value: 43, time: after_1_min))
    {:wait, agg, nil} = Aggregate.add(agg, new_ppl_cntr(value: +1, time: now))
    {:wait, agg, nil} = Aggregate.add(agg, new_ppl_cntr(value: -1, time: after_1_min))
    {act, _, stats} = Aggregate.add(agg, Receipt.new(666, seller_id, 123.00, now))

    exp_stats = %{
      seller_id: seller_id,
      receipt: %{id: 666, amount: 123.00, date: Timex.format!(now, "{ISO:Extended:Z}")},
      internal_avg_temperature: 22.00,
      external_avg_temperature: 40.00,
      people: 1,
    }

    assert {act, stats} == {:send, exp_stats}
  end

  test "data can be received in different order" do
    agg = %Aggregate{}
    {:wait, agg, nil} = Aggregate.add(agg, new_int_temp(value: 22, time: now))
    {:wait, agg, nil} = Aggregate.add(agg, new_int_temp(value: 25, time: after_1_min))
    {:wait, agg, nil} = Aggregate.add(agg, new_ext_temp(value: 40, time: now))
    {:wait, agg, nil} = Aggregate.add(agg, new_ext_temp(value: 43, time: after_1_min))
    {:wait, agg, nil} = Aggregate.add(agg, new_ppl_cntr(value: +1, time: now))
    {:wait, agg, nil} = Aggregate.add(agg, Receipt.new(666, seller_id, 123.00, now))
    {act, _, stats} = Aggregate.add(agg, new_ppl_cntr(value: -1, time: after_1_min))

    exp_stats = %{
      seller_id: seller_id,
      receipt: %{id: 666, amount: 123.00, date: Timex.format!(now, "{ISO:Extended:Z}")},
      internal_avg_temperature: 22.00,
      external_avg_temperature: 40.00,
      people: 1,
    }

    assert {act, stats} == {:send, exp_stats}
  end

  test "data can be received in different temporal order" do
    agg = %Aggregate{}
    {:wait, agg, _} = Aggregate.add(agg, new_int_temp(value: 25, time: after_1_min))
    {:wait, agg, _} = Aggregate.add(agg, new_ext_temp(value: 43, time: after_1_min))
    {:wait, agg, _} = Aggregate.add(agg, Receipt.new(666, seller_id, 123.00, after_1_min))
    {:wait, agg, _} = Aggregate.add(agg, new_int_temp(value: 22, time: now))
    {:wait, agg, _} = Aggregate.add(agg, new_ext_temp(value: 40, time: now))
    {:wait, agg, _} = Aggregate.add(agg, new_ppl_cntr(value: +1, time: now))
    {:wait, agg, _} = Aggregate.add(agg, Receipt.new(666, seller_id, 123.00, now))

    {act, _, stats} = Aggregate.add(agg, new_ppl_cntr(value: -1,time: after_1_min))

    exp_stats = %{
      seller_id: seller_id,
      receipt: %{id: 666, amount: 123.00, date: Timex.format!(now, "{ISO:Extended:Z}")},
      internal_avg_temperature: 22.00,
      external_avg_temperature: 40.00,
      people: 1,
    }

    assert {act, stats} == {:send, exp_stats}
  end

  # What happen if in the same minute we receive two receipt from the same seller?


end
