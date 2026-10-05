defmodule Tauros.Revenue.Errors.Conflict do
  @moduledoc """
  A command that conflicts with something that already happened: an
  idempotency key reused with a different payload, a decision about a stale
  revision, or a revision that was already decided. The JSON:API reports it as
  `409 Conflict` with `code` explaining which conflict it is.
  """
  use Splode.Error, fields: [:code, :field, :message], class: :invalid

  def message(%{message: message}), do: message
end

defimpl AshJsonApi.ToJsonApiError, for: Tauros.Revenue.Errors.Conflict do
  def to_json_api_error(error) do
    %AshJsonApi.Error{
      id: Ash.UUID.generate(),
      status_code: 409,
      code: to_string(error.code),
      title: "Conflict",
      detail: error.message,
      source_pointer: if(error.field, do: "/data/attributes/#{error.field}", else: :undefined),
      meta: %{}
    }
  end
end

defimpl AshJsonApi.ToJsonApiError, for: AshStateMachine.Errors.NoMatchingTransition do
  def to_json_api_error(error) do
    %AshJsonApi.Error{
      id: Ash.UUID.generate(),
      status_code: 409,
      code: "invalid_transition",
      title: "Invalid transition",
      detail: "#{error.action} is not allowed from state #{error.old_state}",
      meta: %{from: error.old_state, action: error.action}
    }
  end
end
