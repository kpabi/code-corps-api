defmodule CodeCorps.Accounts do
  @moduledoc ~S"""
  Main entry-point for managing accounts.

  All actions to acounts should go through here.
  """

  alias CodeCorps.{
    Comment,
    GitHub.Adapters,
    GithubAppInstallation,
    User,
    Repo,
    Task
  }
  alias Ecto.{Changeset, Multi}

  import Ecto.Query

  @doc ~S"""
  Creates a user record using attributes from a GitHub payload.
  """
  @spec create_from_github(map) :: {:ok, User.t} | {:error, Changeset.t}
  def create_from_github(%{} = attrs) do
    %User{}
    |> create_from_github_changeset(attrs)
    |> Repo.insert
  end

  @doc ~S"""
  Casts a changeset used for creating a user account from a github user payload
  """
  @spec create_from_github_changeset(struct, map) :: Changeset.t
  def create_from_github_changeset(struct, %{} = params) do
    struct
    |> Changeset.change(params |> Adapters.User.from_github_user())
    |> Changeset.put_change(:sign_up_context, "github")
    |> Changeset.unique_constraint(:email)
    |> Changeset.validate_inclusion(:type, ["bot", "user"])
  end

  @doc ~S"""
  Ensures an email is set without overwriting an existing email.
  """
  @spec ensure_email(Changeset.t, map) :: Changeset.t
  def ensure_email(%Changeset{} = changeset, %{"email" => new_email} = _params) do
    case changeset |> Changeset.get_field(:email) do
      nil -> changeset |> Changeset.put_change(:email, new_email)
      _email -> changeset
    end
  end
  def ensure_email(%Changeset{} = changeset, _params), do: changeset

  @doc ~S"""
  Updates a user record using attributes from a GitHub payload along with the
  access token.
  """
  @spec update_from_github_oauth(User.t, map, String.t) :: {:ok, User.t} | {:error, Changeset.t}
  def update_from_github_oauth(%User{} = user, %{} = params, access_token) do
    params =
      params
      |> Adapters.User.from_github_user()
      |> Map.put(:github_auth_token, access_token)

    changeset = user |> update_from_github_oauth_changeset(params)

    multi =
      Multi.new
      |> Multi.update(:user, changeset)
      |> Multi.run(:installations, fn %{user: %User{} = user} -> user |> associate_installations() end)
      |> Multi.run(:tasks, fn %{user: %User{} = user} -> user |> associate_tasks() end)
      |> Multi.run(:comments, fn %{user: %User{} = user} -> user |> associate_comments() end)

    case Repo.transaction(multi) do
      {:ok, %{user: %User{} = user, installations: installations}} ->
        {:ok, user |> Map.put(:github_app_installations, installations)}
      {:error, :user, %Changeset{} = changeset, _actions_done} ->
        {:error, changeset}
    end
  end

  @doc ~S"""
  Casts a changeset used for creating a user account from a github user payload
  """
  @spec update_from_github_oauth_changeset(struct, map) :: Changeset.t
  def update_from_github_oauth_changeset(struct, %{} = params) do
    struct
    |> Changeset.cast(params, [:github_auth_token, :github_avatar_url, :github_id, :github_username, :type])
    |> ensure_email(params)
    |> Changeset.validate_required([:github_auth_token, :github_avatar_url, :github_id, :github_username, :type])
  end

  @spec associate_installations(User.t) :: {:ok, list(GithubAppInstallation.t)}
  defp associate_installations(%User{id: user_id, github_id: github_id}) do
    updates = [set: [user_id: user_id]]
    update_options = [returning: true]

    GithubAppInstallation
    |> where([i], i.sender_github_id == ^github_id)
    |> where([i], is_nil(i.user_id))
    |> Repo.update_all(updates, update_options)
    |> (fn {_count, installations} -> {:ok, installations} end).()
  end

  @spec associate_tasks(User.t) :: {:ok, list(Task.t)}
  defp associate_tasks(%User{id: user_id, github_id: github_id}) do
    updates = [set: [user_id: user_id]]
    update_options = [returning: true]

    existing_user_ids =
      User
      |> where(github_id: ^github_id)
      |> select([u], u.id)
      |> Repo.all

    Task
    |> where([t], t.user_id in ^existing_user_ids)
    |> Repo.update_all(updates, update_options)
    |> (fn {_count, tasks} -> {:ok, tasks} end).()
  end

  @spec associate_comments(User.t) :: {:ok, list(Comment.t)}
  defp associate_comments(%User{id: user_id, github_id: github_id}) do
    updates = [set: [user_id: user_id]]
    update_options = [returning: true]

    existing_user_ids =
      User
      |> where(github_id: ^github_id)
      |> select([u], u.id)
      |> Repo.all

    Comment
    |> where([c], c.user_id in ^existing_user_ids)
    |> Repo.update_all(updates, update_options)
    |> (fn {_count, comments} -> {:ok, comments} end).()
  end


end
