defmodule TransformerTest do
  use ExUnit.Case

  test "translate one key to another" do
    assert Transformer.translate_key(%{id: 12}, :id, :xx) == %{xx: 12}
  end

  test "translate some keys to another" do
    assert Transformer.translate_keys(
      %{:X1 => 1, "X2" => 2, :X3 => 3},
      [{:X1, :k1}, {"X2", :k2}, {:X3, "k3"}]
    ) == %{:k1 => 1, :k2 => 2, "k3" => 3}
  end

  test "ignore key not present in map" do
    assert(Transformer.translate_keys(%{a: 1}, a: :b, c: :d) == %{b: 1})
  end

  test "translate key and map new value" do
    assert(Transformer.translate_keys(
      %{a: 1, b: 666},
      [{:a, :A, fn v -> "T#{v}" end}]
      ) == %{A: "T1", b: 666})
  end

end
