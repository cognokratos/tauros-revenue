defmodule Tauros.Revenue.PaymentDestination.Validations.Receivable do
  @moduledoc """
  A destination must be able to receive its currency: the network has to carry
  the currency, and the address has to be valid for the network's rail.
  """
  use Ash.Resource.Validation

  alias Tauros.Revenue.{Address, Network}

  @impl true
  def validate(changeset, _opts, _context) do
    currency = Ash.Changeset.get_attribute(changeset, :currency)
    network = Ash.Changeset.get_attribute(changeset, :network)
    address = Ash.Changeset.get_attribute(changeset, :address)

    cond do
      # Missing values are reported by `allow_nil? false`.
      nil in [currency, network, address] -> :ok
      Network.carries?(network, currency) -> validate_address(network, address)
      true -> {:error, not_carried(network, currency)}
    end
  end

  defp validate_address(network, address) do
    case Address.validate(Network.rail(network), address) do
      :ok -> :ok
      {:error, message} -> {:error, field: :address, message: message}
    end
  end

  defp not_carried(network, currency) do
    networks = Enum.join(Network.for_currency(currency), ", ")
    [field: :network, message: "#{network} does not carry #{currency}; use one of: #{networks}"]
  end
end
