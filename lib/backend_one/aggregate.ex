defmodule DeviceMessage do
  @enforce_keys [:type, :seller_id, :value, :time]
  defstruct [:type, :seller_id, :value, :time]

  def new(type, seller_id, value, %DateTime{} = time \\ Timex.now) do
    %DeviceMessage{type: type, seller_id: seller_id, value: value, time: time}
  end

  @type_id %{
    0 => :ppl,
    1 => :ext,
    2 => :int,
  }

  def type_from(id) when is_number(id) do
    Map.get(@type_id, id)
  end
end

defmodule Receipt do
  @enforce_keys [:id, :seller_id, :amount, :time]
  defstruct [:id, :seller_id, :amount, :time, header: [], rows: []]

  def new(id, seller_id, amount, %DateTime{} = time \\ Timex.now, header \\ [], rows \\ []) do
    %Receipt{
      id: id,
      seller_id: seller_id,
      amount: amount,
      time: time,
      header: header,
      rows: rows
    }
  end
end

defmodule AvgMap do
  defstruct [avg: 0, total: 0, count: 0]
end

#
# %Seller{
#   Datetime => %SellerData{
#
#   }
# }
defmodule Seller do
  @enforce_keys [:id]
  defstruct [:id, data: %{}]

  def create_from(data) do
    %Seller{
      :id => data.seller_id,
      data: %{
        get_time_minutes_rounded(data.time) => SellerData.create_from(data)
      }
    }
  end

  def update_with(data) do
    fn smap ->
      sid = smap.id
      ^sid = data.seller_id
      data = Map.update(
        smap.data,
        get_time_minutes_rounded(data.time),
        SellerData.create_from(data),
        SellerData.update_with(data))
      %{smap | data: data}
    end
  end

  def get_stats_msg(%Seller{} = seller, %{seller_id: seller_id, time: time}) do
    ^seller_id = seller.id
    rtime = get_time_minutes_rounded(time)
    data = seller.data[rtime]
    after_1_min = get_time_minutes_rounded(Timex.shift(time, minutes: 1))
    data_after = seller.data[after_1_min]
    if SellerData.is_filled?(data) && SellerData.is_enough?(data_after) do
      {:send, create_stats_map(seller_id, data)}
    else
      {:wait, nil}
    end
  end

  def create_stats_map(seller_id, data) do
    %{
      seller_id: seller_id,
      receipt: %{ id: data.receipt.id, amount: data.receipt.amount, date: Timex.format!(data.receipt.time, "{ISO:Extended:Z}") },
      internal_avg_temperature: data.int_avg_temp.avg*1.0,
      external_avg_temperature: data.ext_avg_temp.avg*1.0,
      people: data.people,
    }
  end

  defp get_time_minutes_rounded(%DateTime{} = time) do
    {date, {h, m, _s}} = Timex.to_erl(time)
    Timex.to_datetime({date, {h, m, 0}}, time.time_zone)
  end

end

defmodule SellerData do
  defstruct [int_avg_temp: %AvgMap{}, ext_avg_temp: %AvgMap{}, people: nil, receipt: nil]

  @key_of %{
    int: :int_avg_temp,
    ext: :ext_avg_temp,
    ppl: :people,
  }

  def create_from(%Receipt{} = receipt) do
    %SellerData{ receipt: receipt}
  end

  def create_from(%DeviceMessage{type: type} = msg) when type in [:ext, :int] do
    struct!(SellerData, %{
      @key_of[msg.type] => %AvgMap{
        avg: msg.value, total: msg.value, count: 1
      }
    })
  end

  def create_from(%DeviceMessage{type: type} = msg) when type in [:ppl] do
    struct!(SellerData, %{ @key_of[msg.type] => msg.value })
  end

  def is_filled?(nil), do: false
  def is_filled?(%SellerData{} = data) do
    data.receipt != nil
      && data.int_avg_temp.count > 0
      && data.ext_avg_temp.count > 0
      && data.people != nil
  end

  def is_enough?(nil), do: false
  def is_enough?(%SellerData{} = data) do
    data.int_avg_temp.count > 0
      && data.ext_avg_temp.count > 0
      && data.people != nil
  end

  defp default_of(%DeviceMessage{} = msg) do
    cond do
      msg.type in [:int, :ext] ->
        %AvgMap{
          avg: msg.value, total: msg.value, count: 1
        }
      msg.type == :ppl -> 0
    end
  end

  defp update_function_of(%DeviceMessage{} = msg) do
    cond do
      msg.type in [:int, :ext] ->
        fn avg_map ->
          total = avg_map.total + msg.value
          count = avg_map.count + 1
          %AvgMap{
            avg: total / count,
            total: total,
            count: count
          }
        end
      msg.type == :ppl ->
        fn ppl ->
          (ppl || 0) + msg.value
        end
    end
  end

  def update_with(%Receipt{} = receipt) do
    fn sdata ->
      %{sdata | receipt: receipt}
    end
  end

  def update_with(msg) do
    fn sdata ->
      Map.update(
        sdata,
        @key_of[msg.type],
        default_of(msg),
        update_function_of(msg))
    end
  end
end

defmodule Aggregate do
  defstruct [sellers: %{}]

  def add(%Aggregate{} = agr, data) do
    sellers = Map.update(
      agr.sellers,
      data.seller_id,
      Seller.create_from(data),
      Seller.update_with(data))

    {act, stats} = Seller.get_stats_msg(sellers[data.seller_id], data)
    {act, %{agr | sellers: sellers }, stats}
  end

end
