defmodule Tauros.Wallets.Account do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "accounts" do
    field :wallet_name, :string
    field :public_address, :string
    field :currency, :string
    belongs_to :agent, Tauros.Agents.Agent

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(account, attrs) do
    account
    |> cast(attrs, [:wallet_name, :public_address, :currency])
    |> validate_required([:wallet_name, :public_address, :currency])
    |> validate_public_address_by_currency()
  end

  @doc false
  def changeset_with_agent(account, attrs, agent_id) do
    account
    |> changeset(attrs)
    |> put_change(:agent_id, agent_id)
  end

  defp validate_public_address_by_currency(changeset) do
    currency = get_field(changeset, :currency)

    cond do
      currency == "BTC" ->
        validate_format(
          changeset,
          :public_address,
          taproot_btc_regex(),
          message: "must be a valid Taproot Bitcoin address"
        )

      currency == "ETH" ->
        validate_format(
          changeset,
          :public_address,
          eth_address_regex(),
          message: "must be a valid Ethereum address"
        )

      stablecoin?(currency) ->
        validate_format(
          changeset,
          :public_address,
          eth_address_regex(),
          message: "must be a valid Ethereum address"
        )

      fiat_currency?(currency) ->
        validate_format(
          changeset,
          :public_address,
          iban_regex(),
          message: "must be a valid IBAN"
        )

      true ->
        # Unknown / unsupported currency → allow as plain string
        changeset
    end
  end

  defp stablecoin?(currency) do
    currency in [
      "USDT",
      "USDC",
      "DAI",
      "TUSD",
      "BUSD",
      "FDUSD",
      "GUSD",
      "PAX",
      "USDP",
      "LUSD",
      "FRAX",
      "SUSD"
    ]
  end

  defp fiat_currency?(currency) do
    currency in [
      "USD",
      "EUR",
      "CHF",
      "GBP",
      "JPY",
      "CAD",
      "AUD",
      "NZD",
      "SEK",
      "NOK",
      "DKK",
      "SGD"
    ]
  end

  defp eth_address_regex do
    ~r/^0x[a-fA-F0-9]{40}$/
  end

  defp taproot_btc_regex do
    ~r/^bc1p[a-z0-9]{38,60}$/
  end

  defp iban_regex do
    ~r/^[A-Z]{2}[0-9]{2}[A-Z0-9]{11,30}$/
  end
end
