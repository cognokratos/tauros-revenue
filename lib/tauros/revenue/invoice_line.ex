defmodule Tauros.Revenue.InvoiceLine do
  @moduledoc """
  One billed item of an invoice revision: a description, a quantity and a unit
  amount in the revision's currency. Lines are embedded in their revision, so
  they are as immutable as the revision itself.

  Amounts are `Decimal`, never floats.
  """
  use Ash.Resource, data_layer: :embedded

  attributes do
    attribute :description, :string do
      allow_nil? false
      public? true
      constraints trim?: true, min_length: 1, max_length: 500
    end

    attribute :quantity, :decimal do
      description "How many units, e.g. 1, 3 or 1.5 (hours)."
      allow_nil? false
      public? true
      constraints greater_than: 0
    end

    attribute :unit_amount, :decimal do
      description "Price of one unit in the revision's currency."
      allow_nil? false
      public? true
      constraints min: 0
    end
  end
end
