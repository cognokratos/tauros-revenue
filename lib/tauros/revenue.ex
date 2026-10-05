defmodule Tauros.Revenue do
  @moduledoc """
  The financial core: who Tauros bills (`Customer`), where payments are
  received (`PaymentDestination`), and what is owed (`Invoice`, whose content
  lives in immutable `InvoiceRevision`s). Settlement will live here too.
  """
  use Ash.Domain, otp_app: :tauros, extensions: [AshJsonApi.Domain]

  json_api do
    routes do
      base_route "/customers", Tauros.Revenue.Customer do
        index :read
        get :read
        post :create
        patch :update
        delete :destroy
      end

      base_route "/payment-destinations", Tauros.Revenue.PaymentDestination do
        index :read
        get :read
        post :create
        patch :deactivate, route: "/:id/deactivate"
      end

      base_route "/invoices", Tauros.Revenue.Invoice do
        index :read
        get :read

        post :create_draft do
          metadata fn _subject, invoice, _request ->
            %{idempotent_replay: invoice.__metadata__.idempotent_replay}
          end
        end

        patch :revise, route: "/:id/revise"
      end
    end
  end

  resources do
    resource Tauros.Revenue.Customer do
      define :list_customers,
        action: :read,
        default_options: [query: [sort: [inserted_at: :desc]]]

      define :get_customer, action: :read, get_by: :id
      define :create_customer, action: :create
      define :update_customer, action: :update
      define :destroy_customer, action: :destroy
    end

    resource Tauros.Revenue.PaymentDestination do
      define :list_payment_destinations,
        action: :read,
        default_options: [query: [sort: [inserted_at: :desc]]]

      define :get_payment_destination, action: :read, get_by: :id
      define :create_payment_destination, action: :create
      define :deactivate_payment_destination, action: :deactivate
    end

    resource Tauros.Revenue.Invoice do
      define :list_invoices,
        action: :read,
        default_options: [query: [sort: [updated_at: :desc]]]

      define :get_invoice, action: :read, get_by: :id
      define :create_invoice_draft, action: :create_draft
      define :revise_invoice, action: :revise
    end

    resource Tauros.Revenue.InvoiceRevision
  end
end
