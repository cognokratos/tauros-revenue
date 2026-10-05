defmodule Tauros.Revenue.FinancialPayloadTest do
  @moduledoc """
  The payload hash is what a human authorizes, so it must be stable for the
  same intent and different for any material change.
  """
  use ExUnit.Case, async: true

  alias Tauros.Revenue.FinancialPayload

  @destination %{
    id: "8a0f2c1e-6a43-4f2b-9d0e-0c6f1d2b3a4e",
    network: :arbitrum,
    address: "0x1234567890123456789012345678901234567890",
    label: "Treasury"
  }

  defp fields(overrides \\ %{}) do
    Map.merge(
      %{
        customer_id: "5c2b9d3e-1f4a-4b6c-8d7e-9f0a1b2c3d4e",
        currency: :USDC,
        due_date: ~D[2030-01-31],
        lines: [
          %{description: "Design", quantity: Decimal.new("1"), unit_amount: Decimal.new("400")},
          %{description: "Build", quantity: Decimal.new("2"), unit_amount: Decimal.new("400")}
        ]
      },
      overrides
    )
  end

  defp hash(fields, destination \\ @destination),
    do: fields |> FinancialPayload.seal(destination) |> elem(1)

  describe "the same intent always hashes the same" do
    test "equal decimals written differently" do
      written_differently =
        fields(%{
          lines: [
            %{
              description: "Design",
              quantity: Decimal.new("1.000"),
              unit_amount: Decimal.new("400.00")
            },
            %{description: "Build", quantity: Decimal.new("2"), unit_amount: Decimal.new("4E+2")}
          ]
        })

      assert hash(written_differently) == hash(fields())
    end

    test "map key order and extra presentation fields" do
      reordered =
        fields()
        |> Enum.reverse()
        |> Map.new()
        |> Map.update!(:lines, fn lines ->
          Enum.map(lines, &(&1 |> Enum.reverse() |> Map.new() |> Map.put(:amount, "ignored")))
        end)

      assert hash(reordered) == hash(fields())
      assert hash(fields(), %{@destination | label: "Renamed"}) == hash(fields())
    end

    test "Unicode text in composed or decomposed form" do
      composed = fields(%{lines: [line("Café design", "1", "400")]})
      decomposed = fields(%{lines: [line("Café design", "1", "400")]})

      assert hash(composed) == hash(decomposed)
    end

    test "the canonical JSON has sorted keys, no whitespace and a schema tag" do
      {json, hash} = FinancialPayload.seal(fields(), @destination)

      assert json =~ ~r/^\{"currency":"USDC","customer_id":/
      refute json =~ ~r/\s"/
      assert json =~ ~s("schema":"tauros.invoice.v1")
      assert json =~ ~s("total":"1200")
      assert hash == :sha256 |> :crypto.hash(json) |> Base.encode16(case: :lower)
    end
  end

  describe "any material change hashes differently" do
    test "amounts, quantities, descriptions, currency, customer and due date" do
      original = hash(fields())

      changes = [
        %{lines: [line("Design", "1", "400"), line("Build", "2", "400.01")]},
        %{lines: [line("Design", "1", "400"), line("Build", "3", "400")]},
        %{lines: [line("Design", "1", "400"), line("Build and run", "2", "400")]},
        %{lines: [line("Design", "1", "400")]},
        %{currency: :USDT},
        %{customer_id: "00000000-0000-0000-0000-000000000000"},
        %{due_date: ~D[2030-02-01]}
      ]

      for change <- changes do
        refute hash(fields(change)) == original, "#{inspect(change)} must change the hash"
      end
    end

    test "the destination's address, network or identity" do
      original = hash(fields())

      for change <- [
            %{address: "0x0000000000000000000000000000000000000001"},
            %{network: :base},
            %{id: "00000000-0000-0000-0000-000000000000"}
          ] do
        refute hash(fields(), Map.merge(@destination, change)) == original
      end
    end

    test "the order of lines" do
      [first, second] = fields().lines
      refute hash(fields(%{lines: [second, first]})) == hash(fields())
    end
  end

  test "18-decimal amounts beyond Decimal's default 34 digits stay exact and distinct" do
    unit = "987654321098765.123456789012345678"
    one_wei_more = "987654321098765.123456789012345679"

    # 37 significant digits. The default Decimal context would give …1604.
    total = FinancialPayload.total([line("ETH", "123.7", unit)])
    assert Decimal.to_string(total, :normal) == "122172839519917245.7716048008271603686"

    refute hash(fields(%{currency: :ETH, lines: [line("ETH", "123.7", unit)]})) ==
             hash(fields(%{currency: :ETH, lines: [line("ETH", "123.7", one_wei_more)]}))
  end

  test "the total is exact: no float, no rounding" do
    lines = [line("a", "3", "0.1"), line("b", "1", "0.2")]
    assert FinancialPayload.total(lines) == Decimal.new("0.5")
  end

  defp line(description, quantity, unit_amount),
    do: %{
      description: description,
      quantity: Decimal.new(quantity),
      unit_amount: Decimal.new(unit_amount)
    }
end
