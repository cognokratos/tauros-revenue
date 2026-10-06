defmodule TaurosWeb.Mcp.StrictArgumentsTest do
  @moduledoc """
  A tool call must express exactly the command Tauros declares: unknown input
  is an error, at the top level and inside `input`, for every tool.
  """
  use TaurosWeb.ConnCase, async: true

  import TaurosWeb.McpClient, only: [call: 3, as_json: 1, tools: 1]

  alias Tauros.Revenue

  setup do
    agent = agent(approver())
    %{agent: agent, key: agent.__metadata__.plaintext_api_key, invoice: invoice_draft(agent)}
  end

  test "the router runs every tool call through the boundary" do
    [route] =
      TaurosWeb.Router |> Phoenix.Router.routes() |> Enum.filter(&(&1.plug == AshAi.Mcp.Router))

    assert route.plug_opts[:tool_argument_transformer] == (&TaurosWeb.Mcp.StrictArguments.check/3)
  end

  test "every tool refuses an unknown top-level argument and names what it accepts", ctx do
    for tool <- tools(ctx.key) do
      name = tool["name"]
      accepted = tool["inputSchema"]["properties"] |> Map.keys() |> Enum.sort() |> Enum.join(", ")

      arguments =
        if tool["inputSchema"]["properties"]["id"],
          do: %{"id" => ctx.invoice.id, "bogus" => true},
          else: %{"bogus" => true}

      assert {:tool_error, message} = call(ctx.key, name, arguments)

      assert message == "Unknown arguments for #{name}: bogus. Accepted arguments: #{accepted}"
    end
  end

  test "the review's examples are refused and change nothing", ctx do
    id = ctx.invoice.id

    assert {:tool_error, "Unknown arguments for submit_invoice: state. Accepted arguments: id"} =
             call(ctx.key, "submit_invoice", %{"id" => id, "state" => "approved"})

    assert {:tool_error, "Unknown arguments for withdraw_invoice: force. Accepted arguments: id"} =
             call(ctx.key, "withdraw_invoice", %{"id" => id, "force" => true})

    assert {:tool_error,
            "Unknown arguments for get_invoice: include_secrets. Accepted arguments: id"} =
             call(ctx.key, "get_invoice", %{"id" => id, "include_secrets" => true})

    assert Revenue.get_invoice!(id, actor: ctx.agent).state == :draft
  end

  test "valid arguments still execute", ctx do
    assert {:ok, %{"state" => "pending_approval"}} =
             call(ctx.key, "submit_invoice", %{"id" => ctx.invoice.id})
  end

  test "unknown keys inside input are still refused", ctx do
    assert {:tool_error, "Unknown arguments provided: state." <> _} =
             call(ctx.key, "revise_invoice", %{
               "id" => ctx.invoice.id,
               "input" => %{"reasoning" => "x", "state" => "approved"}
             })
  end

  test "floats are still refused, after unknown arguments are", ctx do
    arguments = as_json(%{"input" => draft_input(ctx.agent, idempotency_key: "f")})

    floaty =
      put_in(arguments, ["input", "lines"], [
        %{"description" => "x", "quantity" => 1.5, "unit_amount" => "1"}
      ])

    assert {:tool_error, "input.lines.0.quantity: send amounts as decimal strings" <> _} =
             call(ctx.key, "create_invoice_draft", floaty)

    assert {:tool_error, "Unknown arguments for create_invoice_draft: extra." <> _} =
             call(ctx.key, "create_invoice_draft", Map.put(floaty, "extra", 1))
  end
end
