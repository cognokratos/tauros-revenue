defimpl AshJsonApi.ToJsonApiError, for: AshAuthentication.Errors.AuthenticationFailed do
  # A failed sign-in is an authentication failure (401), not a policy denial (403).
  # The detail is deliberately generic so it cannot be used to enumerate accounts.
  def to_json_api_error(_error) do
    %AshJsonApi.Error{
      id: Ash.UUID.generate(),
      status_code: 401,
      code: "invalid_credentials",
      title: "Unauthorized",
      detail: "Invalid email or password",
      meta: %{}
    }
  end
end
