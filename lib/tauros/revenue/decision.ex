defmodule Tauros.Revenue.Decision do
  @moduledoc "What a human approver decided about one invoice revision."
  use Ash.Type.Enum,
    values: [
      approved: "The exact payload is authorized",
      rejected: "The proposal is refused for good",
      changes_requested: "The agent must propose a new revision"
    ]
end
