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
        <div class="max-w-3xl w-full space-y-8">
          <div class="text-center animate-fade-up">
            <div class="inline-flex items-center gap-2 bg-primary/10 text-primary px-4 py-1.5 rounded-full text-sm font-semibold mb-6">
              <.icon name="hero-sparkles-solid" class="size-4" />
              <span>Welcome to FitTrackerz</span>
            </div>
            <h1 class="text-3xl sm:text-4xl font-brand">
              Choose Your <span class="text-primary">Role</span>
            </h1>
            <p class="text-base-content/50 mt-3 text-lg max-w-xl mx-auto">
              Select how you'd like to use FitTrackerz. You can always change this later.
            </p>
          </div>

          <div class="grid grid-cols-1 md:grid-cols-2 gap-6 max-w-2xl mx-auto" id="role-cards">
            <button
              phx-click="select_role"
              phx-value-role="member"
              class="ft-card ft-card-hover p-8 cursor-pointer text-left group press-scale animate-fade-up stagger-1"
              id="role-member"
            >
              <div class="flex flex-col items-center text-center">
                <div class="w-18 h-18 rounded-2xl bg-gradient-to-br from-primary/15 to-primary/5 flex items-center justify-center mb-5 group-hover:scale-110 transition-transform ring-4 ring-primary/5">
                  <.icon name="hero-user-solid" class="size-9 text-primary" />
                </div>
                <h2 class="text-xl font-bold">Member</h2>
                <p class="text-base-content/50 text-sm mt-2 leading-relaxed">
                  Book classes, follow workout plans, track your diet, and monitor your fitness journey.
                </p>
                <span class="btn btn-primary btn-sm font-semibold gap-2 mt-6 shadow-md shadow-primary/20 press-scale">
                  <.icon name="hero-arrow-right-mini" class="size-4" /> Join as Member
                </span>
              </div>
            </button>

            <button
              phx-click="select_role"
              phx-value-role="gym_operator"
              class="ft-card ft-card-hover p-8 cursor-pointer text-left group press-scale animate-fade-up stagger-2"
              id="role-gym-operator"
            >
              <div class="flex flex-col items-center text-center">
                <div class="w-18 h-18 rounded-2xl bg-gradient-to-br from-accent/15 to-accent/5 flex items-center justify-center mb-5 group-hover:scale-110 transition-transform ring-4 ring-accent/5">
                  <.icon name="hero-building-office-2-solid" class="size-9 text-accent" />
                </div>
                <h2 class="text-xl font-bold">Gym Operator</h2>
                <p class="text-base-content/50 text-sm mt-2 leading-relaxed">
                  Set up your gym, manage branches, invite members, create subscription plans.
                </p>
                <span class="btn btn-accent btn-sm font-semibold gap-2 mt-6 shadow-md shadow-accent/20 press-scale">
                  <.icon name="hero-arrow-right-mini" class="size-4" /> Join as Operator
                </span>
              </div>
            </button>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
