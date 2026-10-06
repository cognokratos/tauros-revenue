defmodule Tauros.Accounts.UserTest do
  use Tauros.DataCase, async: true

  alias Tauros.Accounts
  alias Tauros.Accounts.User

  describe "registration is closed" do
    test "there is no registration action and no strategy registers anyone" do
      refute Ash.Resource.Info.action(User, :register_with_password)

      for strategy <- AshAuthentication.Info.authentication_strategies(User),
          Map.has_key?(strategy, :registration_enabled?) do
        refute strategy.registration_enabled?, "#{strategy.name} must not register humans"
      end
    end

    test "a magic link requested for an unknown email creates nobody" do
      strategy = AshAuthentication.Info.strategy!(User, :magic_link)

      assert :ok =
               AshAuthentication.Strategy.action(strategy, :request, %{
                 "email" => "stranger@example.com"
               })

      assert [] = Ash.read!(User, authorize?: false)
    end
  end

  describe "bootstrap_approver" do
    test "designates the first approver on an empty installation" do
      assert {:ok, %{role: :approver, email: email}} =
               Accounts.bootstrap_approver("first@example.com")

      assert to_string(email) == "first@example.com"
    end

    test "promotes an existing human after an upgrade from before roles existed" do
      operator = user()

      assert {:ok, %{id: id, role: :approver}} =
               Accounts.bootstrap_approver(to_string(operator.email))

      assert id == operator.id
    end

    test "is never available to an agent, even before any approver exists" do
      agent = agent(user())

      assert {:error, %Ash.Error.Forbidden{}} =
               Accounts.bootstrap_approver("ai@example.com", actor: agent)
    end

    test "is refused as soon as an approver exists, for any caller" do
      approver = approver()

      for actor <- [nil, approver, user()] do
        assert {:error, %Ash.Error.Forbidden{}} =
                 Accounts.bootstrap_approver("second@example.com", actor: actor)
      end
    end
  end

  describe "invite" do
    test "an approver invites operators and approvers" do
      approver = approver()

      assert {:ok, %{role: :operator}} =
               Accounts.invite_user("ops@example.com", :operator, actor: approver)

      assert {:ok, %{role: :approver}} =
               Accounts.invite_user("cfo@example.com", :approver, actor: approver)
    end

    test "operators, agents and anonymous callers cannot invite anyone" do
      operator = user()

      for actor <- [operator, agent(operator), nil] do
        assert {:error, %Ash.Error.Forbidden{}} =
                 Accounts.invite_user("new@example.com", :approver, actor: actor)
      end
    end
  end

  describe "a role is fixed once granted" do
    test "no update action accepts role" do
      for action <- Ash.Resource.Info.actions(User), action.type == :update do
        refute :role in action.accept, "#{action.name} must not accept role"
      end
    end

    test "an operator cannot make themselves an approver" do
      operator = user()

      assert {:error, %Ash.Error.Invalid{}} =
               operator
               |> Ash.Changeset.for_update(
                 :change_password,
                 %{
                   role: :approver,
                   current_password: valid_password(),
                   password: "another password",
                   password_confirmation: "another password"
                 },
                 actor: operator
               )
               |> Ash.update()

      assert Ash.get!(User, operator.id, authorize?: false).role == :operator
    end
  end

  describe "approval authority" do
    test "only a human approver matches HumanApprover" do
      alias Tauros.Accounts.Checks.HumanApprover

      operator = user()
      assert HumanApprover.match?(approver(), %{}, [])
      refute HumanApprover.match?(operator, %{}, [])
      refute HumanApprover.match?(agent(operator), %{}, [])
      refute HumanApprover.match?(nil, %{}, [])
    end
  end
end
