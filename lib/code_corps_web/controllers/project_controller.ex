defmodule CodeCorpsWeb.ProjectController do
  use CodeCorpsWeb, :controller

  alias CodeCorps.{Project, User}

  action_fallback CodeCorpsWeb.FallbackController
  plug CodeCorpsWeb.Plug.DataToAttributes

  @spec index(Conn.t, map) :: Conn.t
  def index(%Conn{} = conn, %{} = params) do
    with projects <- Project.Query.list(params) do
      conn |> render("index.json-api", data: projects)
    end
  end

  @spec show(Conn.t, map) :: Conn.t
  def show(%Conn{} = conn, %{} = params) do
    with %Project{} = project <- Project.Query.find(params) do
      conn |> render("show.json-api", data: project)
    end
  end

  @spec create(Plug.Conn.t, map) :: Conn.t
  def create(%Conn{} = conn, %{} = params) do
    with %User{} = current_user <- conn |> Guardian.Plug.current_resource,
         {:ok, :authorized} <- current_user |> Policy.authorize(:create, %Project{}, params),
         {:ok, %Project{} = project} <- %Project{} |> Project.create_changeset(params) |> Repo.insert do
      conn |> put_status(:created) |> render("show.json-api", data: project)
    end
  end

  @spec update(Conn.t, map) :: Conn.t
  def update(%Conn{} = conn, %{} = params) do
    with %Project{} = project <- Project.Query.find(params),
      %User{} = current_user <- conn |> Guardian.Plug.current_resource,
      {:ok, :authorized} <- current_user |> Policy.authorize(:update, project),
      {:ok, %Project{} = project} <- project |> Project.changeset(params) |> Repo.update do
        conn |> render("show.json-api", data: project)
    end
  end
end
