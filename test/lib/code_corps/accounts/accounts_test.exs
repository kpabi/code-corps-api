defmodule CodeCorps.AccountsTest do
  @moduledoc false

  use CodeCorps.DbAccessCase

  alias CodeCorps.{Accounts, User, GitHub.TestHelpers}
  alias Ecto.Changeset

  describe "create_from_github/1" do
    test "creates proper user from provided payload" do
      {:ok, %User{} = user} =
        "user"
        |> TestHelpers.load_endpoint_fixture
        |> Accounts.create_from_github

      assert user.id
      assert user.sign_up_context == "github"
      assert user.type == "user"
    end

    test "returns changeset if there was a validation error" do
      %{"email" => email} = payload = TestHelpers.load_endpoint_fixture("user")
      # email must be unique, so if a user with email already exists, this
      # triggers a validation error
      insert(:user, email: email)

      {:error, %Changeset{} = changeset} = payload |> Accounts.create_from_github
      assert changeset.errors[:email] == {"has already been taken", []}
    end
  end

  describe "create_from_github_changeset/1" do
    test "validates inclusion of type" do
      params = %{"email" => "test@email.com", "type" => "Organization"}
      changeset = Accounts.create_from_github_changeset(%User{}, params)
      assert changeset.errors[:type] == {"is invalid", [validation: :inclusion]}
    end
  end

  describe "ensure_email/2" do
    test "ensures an email is not overridden when the user has an email" do
      user = insert(:user, email: "original@email.com")
      params = %{"email" => "new@email.com"}
      changeset =
        user
        |> Changeset.cast(params, [])
        |> Accounts.ensure_email(params)
      refute changeset.changes[:email]
    end

    test "ensures an email is not set to nil" do
      user = insert(:user, email: "original@email.com")
      params = %{"email" => nil}
      changeset =
        user
        |> Changeset.cast(params, [])
        |> Accounts.ensure_email(params)
      refute changeset.changes[:email]
    end

    test "ensures an email is set when initially nil" do
      user = insert(:user, email: nil)
      params = %{"email" => "new@email.com"}
      changeset =
        user
        |> Changeset.cast(params, [])
        |> Accounts.ensure_email(params)
      assert changeset.changes[:email]
    end

    test "works without email params" do
      user = insert(:user)
      changeset =
        user
        |> Changeset.cast(%{}, [])
        |> Accounts.ensure_email(%{})
      assert changeset.valid?
    end

  end

  describe "update_from_github_oauth/3" do
    test "updates proper user from provided payload" do
      user = insert(:user)
      params = TestHelpers.load_endpoint_fixture("user")
      token = "random_token"

      {:ok, %User{} = user} =
        user
        |> Accounts.update_from_github_oauth(params, token)

      assert user.id
      assert user.github_auth_token == token
      assert user.sign_up_context == "default"
      assert user.type == "user"
    end
  end
end
