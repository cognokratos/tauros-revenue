# Project Context (User Provided)

# Таурос Revenue
- **Tech Stack:**
  - **Elixir** & **Phoenix**
    - use **LiveView**
    - use `mix phx.gen.auth Accounts User users`
  - **TailwindCSS**
    - Using _TailwindUI_ pre-existing HTML templates
  - **PostgreSQL** + **pg_vector**
    - use **Ecto** for ORM
    - use **Arcana** for RAG
  - **Blockchain**
    - _generate_invoice_ using `public address` as payment destination
  - _Model Context Protocol_ server with **Anubis MCP**
    ```elixir
    defp deps do
      [
        {:anubis_mcp, "~> 0.17.0"}
      ]
    end
    ```
  - _Retrieval-Augmented Generation_ with **Arcana**
    ```elixir
    defp deps do
      [
        {:arcana, "~> 1.2.0"}
      ]
    end
    ```
    - use custom `OllamaEmbedder` using Ollama embed API
  - **Docker**
    - use `pgvector/pgvector:pg18-trixie`
    - use `mix phx.gen.release --docker`
- **Features:**
  - **User** registers a new _Agent_
  - **User** registers a new _Customer_
  - **Wallet Service** registers a new _Account_
  - **Agent** creates new _Invoice_ for _Customer_
  - **Agent** queries _Invoices_ using _RAG_
  - **Reporting Service** updates _Invoice_ status
- **Data Schemas:**
  - _User_:
    - _ID_: UUID
    - _Email_: String
  - _Agent_:
    - _ID_: UUID
    - _User ID_: UUID
    - _Name_: String
    - _Hashed API Key_: String
  - _Customer_:
    - _ID_: UUID
    - _Agent ID_: UUID
    - _Name_: String
    - _Email_: String
  - _Account_:
    - _ID_: UUID
    - _Agent ID_: UUID
    - _Wallet Name_: String
    - _Public Address_: String
    - _Currency_: BTC | ETH | ERC20 Symbol
  - _Invoice_:
    - _ID_: UUID
    - _Agent ID_: UUID
    - _Customer ID_: UUID
    - _Account ID_: UUID
    - _Description_: Text
    - _Amount_: Number
    - _Payment Status_: Pending | Paid | Overdue
- **Supported Blockchains:**
  - Bitcoin
  - Ethereum
- **Supported Interfaces:**
  - **LiveView UI** for _Users_
  - **JSON REST API** for _Services_
  - **HTTP MCP Server** for _Agents_
