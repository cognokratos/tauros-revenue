defmodule TaurosWeb.Mcp.AuthenticationTest do
  @moduledoc """
  MCP is machine capability, so MCP callers are agents: only an agent API key
  authenticates at /mcp. Whatever authenticates becomes the Ash actor, and
  from there Ash policies decide, exactly as for REST and the UI.
  """
  use TaurosWeb.ConnCase, async: true

  alias TaurosWeb.McpClient

  setup do
    owner = approver()
    agent = agent(owner)
    token = owner |> with_token() |> Map.fetch!(:__metadata__) |> Map.fetch!(:token)
    %{owner: owner, agent: agent, key: agent.__metadata__.plaintext_api_key, human_token: token}
  end

  test "a request without a credential is refused" do
    conn = McpClient.request(nil, "tools/list")

    assert conn.status == 401
    assert get_resp_header(conn, "www-authenticate") == [~s(Bearer realm="tauros-mcp")]

    assert %{"error" => %{"message" => "An agent API key is required" <> _}} =
             Jason.decode!(conn.resp_body)
  end

  test "an invalid or revoked agent key is refused", %{owner: owner, agent: agent, key: key} do
    assert McpClient.request("tauros_not-a-real-key", "tools/list").status == 401

    {:ok, _} = Tauros.Accounts.rotate_agent_api_key(agent, actor: owner)
    assert McpClient.request(key, "tools/list").status == 401
  end

  test "a human bearer token is refused, even an approver's", %{human_token: token} do
    # The same token works on the REST API; MCP accepts agents only, so a human
    # can never become a more privileged MCP actor.
    assert McpClient.request(token, "tools/list").status == 401
    assert build_conn() |> authorize(token) |> get("/api/v1/invoices") |> json_response(200)
  end

  test "a valid agent key is accepted and the agent is the actor", %{agent: agent, key: key} do
    mine = customer(agent)
    _other = customer(agent(user()))

    assert McpClient.request(key, "tools/list").status == 200
    assert {:ok, %{"results" => [%{"id" => id}]}} = McpClient.call(key, "list_customers")
    assert id == mine.id
  end

  test "older clients negotiate a protocol revision through initialize", %{key: key} do
    conn =
      build_conn()
      |> authorize(key)
      |> put_req_header("content-type", "application/json")
      |> put_req_header("accept", "application/json, text/event-stream")
      |> post(
        "/mcp",
        Jason.encode!(%{
          jsonrpc: "2.0",
          id: 1,
          method: "initialize",
          params: %{
            protocolVersion: "2025-06-18",
            capabilities: %{},
            clientInfo: %{name: "legacy", version: "1"}
          }
        })
      )

    assert %{"result" => %{"protocolVersion" => "2025-06-18"}} = Jason.decode!(conn.resp_body)
  end

  test "a session id carries no identity: each request runs as its own key", %{agent: agent} do
    other = agent(user())
    mine = customer(agent)
    theirs = customer(other)

    # Agent A initializes and receives a session id.
    session =
      build_conn()
      |> authorize(agent.__metadata__.plaintext_api_key)
      |> put_req_header("content-type", "application/json")
      |> post(
        "/mcp",
        Jason.encode!(%{
          jsonrpc: "2.0",
          id: 1,
          method: "initialize",
          params: %{
            protocolVersion: "2025-06-18",
            capabilities: %{},
            clientInfo: %{name: "a", version: "1"}
          }
        })
      )
      |> get_resp_header("mcp-session-id")
      |> List.first()

    assert is_binary(session)

    # Agent B presents A's session id with its own key: it acts as B.
    response =
      build_conn()
      |> authorize(other.__metadata__.plaintext_api_key)
      |> put_req_header("content-type", "application/json")
      |> put_req_header("mcp-session-id", session)
      |> put_req_header("mcp-protocol-version", "2025-06-18")
      |> post(
        "/mcp",
        Jason.encode!(%{
          jsonrpc: "2.0",
          id: 2,
          method: "tools/call",
          params: %{name: "list_customers", arguments: %{}}
        })
      )
      |> Map.fetch!(:resp_body)
      |> Jason.decode!()

    ids = response["result"]["structuredContent"]["results"] |> Enum.map(& &1["id"])
    assert ids == [theirs.id]
    refute mine.id in ids
  end

  test "MCP offers tools only: no resources and no prompts", %{key: key} do
    assert %{"result" => %{"resources" => []}} =
             key
             |> McpClient.request("resources/list")
             |> Map.fetch!(:resp_body)
             |> Jason.decode!()

    assert %{"error" => _} =
             key |> McpClient.request("prompts/list") |> Map.fetch!(:resp_body) |> Jason.decode!()
  end
end
