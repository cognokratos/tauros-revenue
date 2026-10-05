defmodule TaurosWeb.McpClient do
  @moduledoc """
  A minimal MCP client for tests: JSON-RPC over HTTP to `/mcp`, speaking the
  current protocol revision (2026-07-28: version and client identity in
  `_meta` on every request, mirrored in headers).
  """
  import Plug.Conn
  import Phoenix.ConnTest

  @endpoint TaurosWeb.Endpoint
  @version "2026-07-28"

  def protocol_version, do: @version

  @doc "Sends one JSON-RPC request with `credential` as the bearer token (or none)."
  def request(credential, method, params \\ %{}) do
    meta = %{
      "io.modelcontextprotocol/protocolVersion" => @version,
      "io.modelcontextprotocol/clientInfo" => %{"name" => "tauros-test", "version" => "1.0"},
      "io.modelcontextprotocol/clientCapabilities" => %{}
    }

    body = %{
      "jsonrpc" => "2.0",
      "id" => System.unique_integer([:positive]),
      "method" => method,
      "params" => Map.put(params, "_meta", meta)
    }

    build_conn()
    |> maybe_authorize(credential)
    |> put_req_header("content-type", "application/json")
    |> put_req_header("accept", "application/json, text/event-stream")
    |> put_req_header("mcp-protocol-version", @version)
    |> put_req_header("mcp-method", method)
    |> maybe_name(params["name"])
    |> post("/mcp", Jason.encode!(body))
  end

  @doc "The names of the tools offered to `credential`."
  def tool_names(credential) do
    credential |> tools() |> Enum.map(& &1["name"]) |> Enum.sort()
  end

  @doc "The tool definitions offered to `credential`."
  def tools(credential) do
    %{"result" => %{"tools" => tools}} = credential |> request("tools/list") |> json()
    tools
  end

  @doc """
  Calls a tool. Returns `{:ok, structured_result}`, `{:tool_error, text}` (the
  tool ran and refused) or `{:rpc_error, message}` (e.g. no such tool).
  """
  def call(credential, name, arguments \\ %{}) do
    case credential
         |> request("tools/call", %{"name" => name, "arguments" => arguments})
         |> json() do
      %{"result" => %{"isError" => false, "structuredContent" => content}} ->
        {:ok, content}

      # A plain JSON list (an unpaginated read) is only returned as text content.
      %{"result" => %{"isError" => false, "content" => [%{"text" => text}]}} ->
        {:ok, Jason.decode!(text)}

      %{"result" => %{"isError" => true, "content" => [%{"text" => text} | _]}} ->
        {:tool_error, text}

      %{"error" => %{"message" => message}} ->
        {:rpc_error, message}
    end
  end

  @doc "Arguments exactly as a JSON client would send them (string keys, no atoms)."
  def as_json(term), do: term |> Jason.encode!() |> Jason.decode!()

  defp json(conn), do: Jason.decode!(conn.resp_body)

  defp maybe_authorize(conn, nil), do: conn

  defp maybe_authorize(conn, credential),
    do: put_req_header(conn, "authorization", "Bearer " <> credential)

  defp maybe_name(conn, nil), do: conn
  defp maybe_name(conn, name), do: put_req_header(conn, "mcp-name", name)
end
