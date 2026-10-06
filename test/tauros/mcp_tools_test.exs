defmodule Tauros.McpToolsTest do
  @moduledoc """
  The AI capability surface is an exact, reviewed allowlist.

  Invariant A: every MCP tool runs an action classified `:agent_safe`.
  Invariant B: the tools are exactly the reviewed Epic 4 set, everywhere they
  are defined or served: `Tauros.Authority.mcp_tools/0`, the domain's `tools`
  block, the router's forward options and a live `tools/list`.

  B is stricter than A on purpose. `deactivate_payment_destination` is
  agent-safe, but it is not part of the reviewed AI surface; exposing it (or
  anything else) without updating this test must fail CI.
  """
  use TaurosWeb.ConnCase, async: true

  alias Tauros.Authority
  alias TaurosWeb.McpClient

  # The Epic 4 review. Change this list only together with docs/MCP.md.
  @reviewed ~w(
    create_invoice_draft
    get_invoice
    list_customers
    list_invoices
    list_payment_destinations
    revise_invoice
    submit_invoice
    withdraw_invoice
  )a

  @never_tools ~w(
    approve_invoice reject_invoice request_invoice_changes cancel_invoice
    invite_user bootstrap_approver create_agent update_agent destroy_agent rotate_agent_api_key
    create_customer update_customer destroy_customer
    deactivate_payment_destination create_payment_destination
    list_invoices_awaiting_approval list_invoice_revisions list_approvals list_invoice_events
  )a

  defp declared_tools do
    for domain <- Application.fetch_env!(:tauros, :ash_domains),
        AshAi in Spark.extensions(domain),
        tool <- AshAi.Info.tools(domain),
        do: tool
  end

  defp router_tools do
    [route] =
      TaurosWeb.Router
      |> Phoenix.Router.routes()
      |> Enum.filter(&(&1.plug == AshAi.Mcp.Router))

    Keyword.fetch!(route.plug_opts, :tools)
  end

  describe "invariant B: exactly the reviewed tools" do
    test "Tauros.Authority lists exactly the reviewed tools" do
      assert Enum.sort(Authority.mcp_tool_names()) == @reviewed
    end

    test "the domains declare exactly those tools, on exactly those actions" do
      declared = Map.new(declared_tools(), &{&1.name, {&1.resource, &1.action}})
      assert declared == Map.new(Authority.mcp_tools())
    end

    test "the router serves exactly those tools" do
      assert Enum.sort(router_tools()) == @reviewed
    end

    test "an authenticated agent discovers exactly those tools" do
      agent = agent(approver())

      assert McpClient.tool_names(agent.__metadata__.plaintext_api_key) ==
               Enum.map(@reviewed, &to_string/1)
    end

    test "no authority-bearing, management or narrower-than-reviewed tool exists anywhere" do
      names = Enum.map(declared_tools(), & &1.name) ++ router_tools()

      for name <- @never_tools do
        refute name in names, "#{name} must not be an MCP tool"
      end
    end
  end

  describe "invariant A: every tool runs an agent-safe action" do
    test "each tool's action is classified :agent_safe" do
      for {name, {resource, action}} <- Authority.mcp_tools() do
        assert Authority.classify(resource, action) == :agent_safe,
               "#{name} runs #{inspect(resource)}.#{action}, which is not agent-safe"
      end
    end

    test "no tool runs a human-only or internal action" do
      targets = Enum.map(declared_tools(), &{&1.resource, &1.action})

      for entry <- Authority.human_only() ++ Authority.internal() do
        refute entry in targets, "#{inspect(entry)} is exposed as a tool"
      end
    end

    test "being agent-safe is not enough to be a tool" do
      exposed = Keyword.values(Authority.mcp_tools())

      assert {Tauros.Revenue.PaymentDestination, :deactivate} in Authority.agent_safe()
      refute {Tauros.Revenue.PaymentDestination, :deactivate} in exposed
      refute {Tauros.Revenue.Invoice, :awaiting_approval} in exposed
    end
  end

  describe "schema contract: money never becomes a float" do
    setup do
      %{
        tools:
          Map.new(
            McpClient.tools(agent(approver()).__metadata__.plaintext_api_key),
            &{&1["name"], &1}
          )
      }
    end

    test "create_invoice_draft takes exactly the reviewed input shape", %{tools: tools} do
      %{"inputSchema" => %{"properties" => %{"input" => input}, "required" => ["input"]}} =
        tools["create_invoice_draft"]

      assert Enum.sort(input["required"]) ==
               ~w(currency customer_id due_date idempotency_key lines payment_destination_id reasoning)

      props = input["properties"]
      assert %{"type" => "string", "format" => "uuid"} = props["customer_id"]
      assert %{"type" => "string", "format" => "uuid"} = props["payment_destination_id"]
      assert %{"type" => "string", "format" => "date"} = props["due_date"]
      assert %{"type" => "string"} = props["idempotency_key"]
      assert %{"type" => "string"} = props["reasoning"]
      assert %{"type" => "string", "enum" => currencies} = props["currency"]

      assert Enum.sort(currencies) ==
               Tauros.Revenue.Currency.values() |> Enum.map(&to_string/1) |> Enum.sort()

      assert %{"type" => "array", "items" => line} = props["lines"]
      assert line["type"] == "object"
      assert Enum.sort(line["required"]) == ~w(description quantity unit_amount)
      assert Enum.sort(Map.keys(line["properties"])) == ~w(description quantity unit_amount)

      # Decimals travel as strings: JSON numbers would be parsed as IEEE floats.
      assert line["properties"]["quantity"]["type"] == "string"
      assert line["properties"]["unit_amount"]["type"] == "string"
    end

    test "revise_invoice requires only the invoice id and a reasoning", %{tools: tools} do
      schema = tools["revise_invoice"]["inputSchema"]
      assert schema["properties"]["id"]["format"] == "uuid"
      assert schema["properties"]["input"]["required"] == ["reasoning"]
    end

    test "no tool accepts a floating-point number anywhere", %{tools: tools} do
      for {name, tool} <- tools do
        refute "number" in schema_types(tool["inputSchema"]),
               "#{name} declares a JSON number; amounts must be decimal strings"
      end
    end

    test "no tool accepts a state, an owner or a computed financial field", %{tools: tools} do
      for {name, tool} <- tools,
          field <- ~w(state agent_id total payload_hash approver_id decision) do
        refute field in property_names(tool["inputSchema"]), "#{name} accepts #{field}"
      end
    end
  end

  defp schema_types(%{} = schema) do
    own = if is_binary(schema["type"]), do: [schema["type"]], else: List.wrap(schema["type"])
    own ++ Enum.flat_map(Map.values(schema), &schema_types/1)
  end

  defp schema_types(list) when is_list(list), do: Enum.flat_map(list, &schema_types/1)
  defp schema_types(_), do: []

  defp property_names(%{"properties" => props} = schema) do
    Map.keys(props) ++
      Enum.flat_map(Map.values(props), &property_names/1) ++
      property_names(Map.delete(schema, "properties"))
  end

  defp property_names(%{"items" => items}), do: property_names(items)
  defp property_names(_), do: []
end
