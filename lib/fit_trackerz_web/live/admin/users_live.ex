defmodule FitTrackerzWeb.Admin.UsersLive do
  use FitTrackerzWeb, :live_view

  @role_badge_classes %{
    platform_admin: "badge-error",
    gym_operator: "badge-primary",
    member: "badge-accent"
  }

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

  defp role_badge_class(role) do
    Map.get(@role_badge_classes, role, "badge-ghost")
  end

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
      <div class="space-y-8">
        <%!-- Page Header --%>
        <div class="flex items-center justify-between" id="users-header">
          <div class="flex items-center gap-3">
            <Layouts.back_button />
            <div>
              <h1 class="text-2xl sm:text-3xl font-brand">Users</h1>
              <p class="text-base-content/50 mt-1">
                {length(@users)} total users on the platform
              </p>
            </div>
          </div>
          <div class="w-12 h-12 rounded-xl bg-primary/10 flex items-center justify-center">
            <.icon name="hero-user-group-solid" class="size-6 text-primary" />
          </div>
        </div>

        <%!-- Users Table --%>
        <div class="ft-card p-6" id="users-table-card">
          <%= if Enum.empty?(@users) do %>
            <div class="flex flex-col items-center justify-center py-16 px-4" id="users-empty-state">
              <div class="w-16 h-16 rounded-2xl bg-base-200/30 rounded-xl flex items-center justify-center mb-4">
                <.icon name="hero-user-group" class="size-8 text-base-content/30" />
              </div>
              <p class="text-lg font-semibold text-base-content/50">No users found</p>
              <p class="text-sm text-base-content/30 mt-1">
                Users will appear here once they register.
              </p>
            </div>
          <% else %>
            <div class="ft-table overflow-x-auto">
              <table class="table" id="users-table">
                <thead>
                  <tr class="border-b border-base-200/50">
                    <th class="text-xs font-semibold text-base-content/40 uppercase tracking-wider">
                      Name
                    </th>
                    <th class="text-xs font-semibold text-base-content/40 uppercase tracking-wider">
                      Email
                    </th>
                    <th class="text-xs font-semibold text-base-content/40 uppercase tracking-wider">
                      Role
                    </th>
                    <th class="text-xs font-semibold text-base-content/40 uppercase tracking-wider">
                      Status
                    </th>
                    <th class="text-xs font-semibold text-base-content/40 uppercase tracking-wider">
                      Created
                    </th>
                    <th class="text-xs font-semibold text-base-content/40 uppercase tracking-wider">
                      Actions
                    </th>
                  </tr>
                </thead>
                <tbody>
                  <tr
                    :for={user <- @users}
                    class="border-b border-base-200/30 hover:bg-base-200/50"
                    id={"user-row-#{user.id}"}
                  >
                    <td class="font-semibold">{user.name}</td>
                    <td class="text-sm text-base-content/60">{user.email}</td>
                    <td>
                      <div class="flex items-center gap-2">
                        <form phx-change="change_role" id={"role-form-#{user.id}"}>
                          <input type="hidden" name="user_id" value={user.id} />
                          <select
                            name="role"
                            class="select select-bordered select-xs bg-base-200/30 rounded-xl font-medium"
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
                        <span class={"badge badge-xs #{role_badge_class(user.role)}"}>
                          {format_role(user.role)}
                        </span>
                      </div>
                    </td>
                    <td>
                      <%= if user.is_active do %>
                        <span
                          class="badge badge-sm badge-success gap-1"
                          id={"status-badge-#{user.id}"}
                        >
                          <.icon name="hero-check-circle-mini" class="size-3" /> Active
                        </span>
                      <% else %>
                        <span
                          class="badge badge-sm badge-error gap-1"
                          id={"status-badge-#{user.id}"}
                        >
                          <.icon name="hero-x-circle-mini" class="size-3" /> Inactive
                        </span>
                      <% end %>
                    </td>
                    <td class="text-sm text-base-content/50">
                      {format_datetime(user.inserted_at)}
                    </td>
                    <td>
                      <button
                        phx-click="toggle_active"
                        phx-value-id={user.id}
                        class={[
                          "btn btn-xs gap-1 font-medium press-scale",
                          if(user.is_active,
                            do: "btn-ghost text-error",
                            else: "btn-ghost text-success"
                          )
                        ]}
                        id={"toggle-active-#{user.id}"}
                      >
                        <%= if user.is_active do %>
                          <.icon name="hero-no-symbol-mini" class="size-3" /> Deactivate
                        <% else %>
                          <.icon name="hero-check-mini" class="size-3" /> Activate
                        <% end %>
                      </button>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
          <% end %>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
