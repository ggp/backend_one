defmodule Transformer do

  def translate_key(map, from, to) do
    translate_keys(map, [{from, to}])
  end

  def translate_keys(map, keywords) do
    Enum.filter(keywords, fn t ->
      [from | _] = Tuple.to_list(t)
      Map.has_key?(map, from)
    end)
    |> Enum.reduce(map, &translate_map/2)
  end

  defp translate_map({from, to}, map) do
    {v, m} = Map.pop(map, from)
    Map.put(m, to, v)
  end

  defp translate_map({from, to, fn_map}, map) do
    {v, m} = Map.pop(map, from)
    Map.put(m, to, fn_map.(v))
  end

end
