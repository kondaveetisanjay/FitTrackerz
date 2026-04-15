defmodule FitTrackerzWeb.Admin.UsersLive do
  use FitTrackerzWeb, :live_view

  @valid_roles ~w(platform_admin gym_operator member)a

  @impl true
  def mount(_params, _session, socket) do
    actor = socket.assigns.current_user

    users =
      case FitTrackerz.Accounts.list_users(actor: actor) do
        {:ok, users} -> users
        _ -> []
      end

    {:ok,
     assign(socket,
       page_title: "Manage Users",
       users: users
     )}
  end

  @impl true
  def handle_event("toggle_active", %{"id" => user_id}, socket) do
    actor = socket.assigns.current_user

    case FitTrackerz.Accounts.get_user(user_id, actor: actor) do
      {:ok, user} ->
        case FitTrackerz.Accounts.update_user(user, %{is_active: !user.is_active}, actor: actor) do
          {:ok, _} ->
            users =
              case FitTrackerz.Accounts.list_users(actor: actor) do
                {:ok, users} -> users
                _ -> []
              end

            {:noreply, assign(socket, users: users)}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Failed to update user status.")}
        end

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "User not found.")}
    end
  end

  @impl true
  def handle_event("change_role", %{"user_id" => user_id, "role" => role}, socket) do
    actor = socket.assigns.current_user
    role_atom = String.to_existing_atom(role)

    if role_atom in @valid_roles do
      case FitTrackerz.Accounts.get_user(user_id, actor: actor) do
        {:ok, user} ->
          case FitTrackerz.Accounts.update_user(user, %{role: role_atom}, actor: actor) do
            {:ok, _} ->
              users =
                case FitTrackerz.Accounts.list_users(actor: actor) do
                  {:ok, users} -> users
                  _ -> []
                end

              {:noreply, assign(socket, users: users)}

            {:error, _} ->
              {:noreply, put_flash(socket, :error, "Failed to update user role.")}
          end

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "User not found.")}
      end
    else
      {:noreply, put_flash(socket, :error, "Invalid role selected.")}
    end
  end

  defp role_badge_variant(:platform_admin), do: "error"
  defp role_badge_variant(:gym_operator), do: "primary"
  defp role_badge_variant(:member), do: "secondary"
  defp role_badge_variant(_), do: "neutral"

  defp format_role(role) do
    role
    |> Atom.to_string()
    |> String.replace("_", " ")
    |> String.split(" ")
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  defp format_datetime(nil), do: "--"

  defp format_datetime(dt) do
    Calendar.strftime(dt, "%b %d, %Y")
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <.page_header title="Users" subtitle={"#{length(@users)} total users on the platform"} back_path="/admin/dashboard" />

      <%= if Enum.empty?(@users) do %>
        <.card>
          <.empty_state
            icon="hero-user-group"
            title="No users found"
            subtitle="Users will appear here once they register."
          />
        </.card>
      <% else %>
        <.card padded={false}>
          <.data_table id="users-table" rows={@users} row_id={fn user -> "user-row-#{user.id}" end}>
            <:col :let={user} label="Name">
              <div class="flex items-center gap-2">
                <.avatar name={user.name} size="sm" />
                <span class="font-semibold">{user.name}</span>
              </div>
            </:col>
            <:col :let={user} label="Email">
              <span class="text-sm text-base-content/60">{user.email}</span>
            </:col>
            <:col :let={user} label="Role">
              <div class="flex items-center gap-2">
                <form phx-change="change_role" id={"role-form-#{user.id}"}>
                  <input type="hidden" name="user_id" value={user.id} />
                  <select
                    name="role"
                    class="select select-bordered select-xs bg-base-300/30 font-medium"
                    id={"role-select-#{user.id}"}
                  >
                    <option value="platform_admin" selected={user.role == :platform_admin}>
                      Platform Admin
                    </option>
                    <option value="gym_operator" selected={user.role == :gym_operator}>
                      Gym Operator
                    </option>
                    <option value="member" selected={user.role == :member}>
                      Member
                    </option>
                  </select>
                </form>
                <.badge variant={role_badge_variant(user.role)} size="sm">
                  {format_role(user.role)}
                </.badge>
              </div>
            </:col>
            <:col :let={user} label="Status">
              <%= if user.is_active do %>
                <.badge variant="success" size="sm">Active</.badge>
              <% else %>
                <.badge variant="error" size="sm">Inactive</.badge>
              <% end %>
            </:col>
            <:col :let={user} label="Created">
              <span class="text-sm text-base-content/50">{format_datetime(user.inserted_at)}</span>
            </:col>
            <:mobile_card :let={user}>
              <div class="flex items-center gap-3">
                <.avatar name={user.name} size="sm" />
                <div class="min-w-0">
                  <p class="font-semibold truncate">{user.name}</p>
                  <p class="text-xs text-base-content/50">{user.email}</p>
                  <div class="flex items-center gap-2 mt-1">
                    <.badge variant={role_badge_variant(user.role)} size="sm">{format_role(user.role)}</.badge>
                    <%= if user.is_active do %>
                      <.badge variant="success" size="sm">Active</.badge>
                    <% else %>
                      <.badge variant="error" size="sm">Inactive</.badge>
                    <% end %>
                  </div>
                </div>
              </div>
            </:mobile_card>
            <:actions :let={user}>
              <%= if user.is_active do %>
                <.button
                  variant="danger"
                  size="sm"
                  icon="hero-no-symbol-mini"
                  phx-click="toggle_active"
                  phx-value-id={user.id}
                >
                  Deactivate
                </.button>
              <% else %>
                <.button
                  variant="primary"
                  size="sm"
                  icon="hero-check-mini"
                  phx-click="toggle_active"
                  phx-value-id={user.id}
                >
                  Activate
                </.button>
              <% end %>
            </:actions>
          </.data_table>
        </.card>
      <% end %>
    </Layouts.app>
    """
  end
end
