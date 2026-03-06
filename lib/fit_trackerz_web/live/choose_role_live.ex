defmodule FitTrackerzWeb.ChooseRoleLive do
  use FitTrackerzWeb, :live_view

  @valid_roles ~w(member gym_operator)

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    role = get_role(user)

    if role != :member do
      {:ok, redirect(socket, to: dashboard_path_for_role(role))}
    else
      {:ok, assign(socket, page_title: "Choose Your Role")}
    end
  end

  @impl true
  def handle_event("select_role", %{"role" => role}, socket) when role in @valid_roles do
    actor = socket.assigns.current_user
    role_atom = String.to_existing_atom(role)

    case FitTrackerz.Accounts.get_user(actor.id, actor: actor) do
      {:ok, user} ->
        case FitTrackerz.Accounts.update_user(user, %{role: role_atom}, actor: actor) do
          {:ok, _} ->
            {:noreply, redirect(socket, to: ~p"/role-selected")}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Failed to set role. Please try again.")}
        end

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "User not found.")}
    end
  end

  def handle_event("select_role", _params, socket) do
    {:noreply, put_flash(socket, :error, "Invalid role selected.")}
  end

  defp get_role(%{role: role}) when is_atom(role), do: role
  defp get_role(%{role: role}) when is_binary(role), do: String.to_existing_atom(role)
  defp get_role(_), do: :member

  defp dashboard_path_for_role(:platform_admin), do: "/admin/dashboard"
  defp dashboard_path_for_role(:gym_operator), do: "/gym/dashboard"
  defp dashboard_path_for_role(:member), do: "/member/dashboard"
  defp dashboard_path_for_role(_), do: "/member/dashboard"

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="min-h-[70vh] flex items-center justify-center">
        <div class="max-w-4xl w-full space-y-8">
          <%!-- Welcome Header --%>
          <div class="text-center">
            <div class="inline-flex items-center gap-2 bg-primary/10 text-primary px-4 py-1.5 rounded-full text-sm font-semibold mb-6">
              <.icon name="hero-sparkles-solid" class="size-4" />
              <span>Welcome to <span class="text-primary">FIT</span>TRACKRPRO</span>
            </div>
            <h1 class="text-3xl sm:text-4xl font-brand">
              Choose Your <span class="text-primary">Role</span>
            </h1>
            <p class="text-base-content/50 mt-3 text-lg max-w-xl mx-auto">
              Select how you'd like to use FitTrackerz. You can always change this later.
            </p>
          </div>

          <%!-- Role Cards --%>
          <div class="grid grid-cols-1 md:grid-cols-2 gap-6 max-w-2xl mx-auto" id="role-cards">
            <%!-- Member Card --%>
            <button
              phx-click="select_role"
              phx-value-role="member"
              class="card bg-base-200/50 border-2 border-base-300/50 hover:border-primary/50 shadow-sm hover:shadow-xl hover:-translate-y-1 cursor-pointer text-left group"
              id="role-member"
            >
              <div class="card-body items-center text-center p-8">
                <div class="w-16 h-16 rounded-2xl bg-primary/10 flex items-center justify-center mb-4 group-hover:bg-primary/20 group-hover:scale-110">
                  <.icon name="hero-user-solid" class="size-8 text-primary" />
                </div>
                <h2 class="card-title text-xl">Member</h2>
                <p class="text-base-content/50 text-sm mt-2 leading-relaxed">
                  Book classes, follow workout plans, track your diet, and monitor your fitness journey.
                </p>
                <div class="mt-6">
                  <span class="btn btn-primary btn-sm font-semibold gap-2 group-hover:shadow-lg group-hover:shadow-primary/25">
                    <.icon name="hero-arrow-right-mini" class="size-4" /> Join as Member
                  </span>
                </div>
              </div>
            </button>

            <%!-- Gym Operator Card --%>
            <button
              phx-click="select_role"
              phx-value-role="gym_operator"
              class="card bg-base-200/50 border-2 border-base-300/50 hover:border-accent/50 shadow-sm hover:shadow-xl hover:-translate-y-1 cursor-pointer text-left group"
              id="role-gym-operator"
            >
              <div class="card-body items-center text-center p-8">
                <div class="w-16 h-16 rounded-2xl bg-accent/10 flex items-center justify-center mb-4 group-hover:bg-accent/20 group-hover:scale-110">
                  <.icon name="hero-building-office-2-solid" class="size-8 text-accent" />
                </div>
                <h2 class="card-title text-xl">Gym Operator</h2>
                <p class="text-base-content/50 text-sm mt-2 leading-relaxed">
                  Set up your gym, manage branches, invite members, create subscription plans.
                </p>
                <div class="mt-6">
                  <span class="btn btn-accent btn-sm font-semibold gap-2 group-hover:shadow-lg group-hover:shadow-accent/25">
                    <.icon name="hero-arrow-right-mini" class="size-4" /> Join as Operator
                  </span>
                </div>
              </div>
            </button>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
