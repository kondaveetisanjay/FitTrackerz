defmodule FitTrackerzWeb.GymOperator.MembersLive do
  use FitTrackerzWeb, :live_view

  alias FitTrackerzWeb.AshErrorHelpers

  @impl true
  def mount(_params, _session, socket) do
    actor = socket.assigns.current_user

    case FitTrackerz.Gym.list_gyms_by_owner(actor.id, actor: actor) do
      {:ok, [gym | _]} ->
        members = load_members(gym.id, actor)
        plans = load_plans(gym.id, actor)
        subscriptions = load_subscriptions(gym.id, actor)
        sub_map = build_sub_map(subscriptions)

        invite_form = to_form(%{"email" => ""}, as: "invite")

        {:ok,
         assign(socket,
           page_title: "Members",
           gym: gym,
           members: members,
           plans: plans,
           subscriptions: subscriptions,
           sub_map: sub_map,
           invite_form: invite_form,
           show_invite: false,
           assigning_member_id: nil
         )}

      _ ->
        {:ok,
         assign(socket,
           page_title: "Members",
           gym: nil,
           members: [],
           plans: [],
           subscriptions: [],
           sub_map: %{},
           invite_form: nil,
           show_invite: false,
           assigning_member_id: nil
         )}
    end
  end

  # ── Event Handlers ──

  @impl true
  def handle_event("toggle_invite", _params, socket) do
    {:noreply, assign(socket, show_invite: !socket.assigns.show_invite)}
  end

  def handle_event("validate_invite", %{"invite" => _params}, socket) do
    {:noreply, socket}
  end

  def handle_event("invite", %{"invite" => params}, socket) do
    actor = socket.assigns.current_user
    gym = socket.assigns.gym
    email = params["email"]

    case FitTrackerz.Gym.create_member_invitation(%{
      invited_email: email,
      gym_id: gym.id,
      invited_by_id: actor.id
    }, actor: actor) do
      {:ok, _invitation} ->
        invite_form = to_form(%{"email" => ""}, as: "invite")

        {:noreply,
         socket
         |> put_flash(:info, "Invitation sent to #{email}!")
         |> assign(invite_form: invite_form, show_invite: false)}

      {:error, error} ->
        {:noreply, put_flash(socket, :error, AshErrorHelpers.user_friendly_message(error))}
    end
  end

  def handle_event("toggle_active", %{"id" => id}, socket) do
    actor = socket.assigns.current_user
    gym = socket.assigns.gym

    case FitTrackerz.Gym.get_gym_member(id, actor: actor) do
      {:ok, member} ->
        case FitTrackerz.Gym.update_gym_member(member, %{is_active: !member.is_active}, actor: actor) do
          {:ok, _updated} ->
            members = load_members(gym.id, actor)

            {:noreply,
             socket
             |> put_flash(:info, "Member status updated.")
             |> assign(members: members)}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Failed to update member status.")}
        end

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Member not found.")}
    end
  end

  def handle_event("show_assign_plan", %{"member-id" => member_id}, socket) do
    {:noreply, assign(socket, assigning_member_id: member_id)}
  end

  def handle_event("cancel_assign_plan", _params, socket) do
    {:noreply, assign(socket, assigning_member_id: nil)}
  end

  def handle_event("assign_plan", %{"plan_id" => plan_id, "member_id" => member_id}, socket) do
    actor = socket.assigns.current_user
    gym = socket.assigns.gym

    plan = Enum.find(socket.assigns.plans, &(&1.id == plan_id))

    if plan do
      now = DateTime.utc_now()
      ends_at = calculate_end_date(now, plan.duration)

      case FitTrackerz.Billing.create_subscription(%{
        member_id: member_id,
        subscription_plan_id: plan_id,
        gym_id: gym.id,
        starts_at: now,
        ends_at: ends_at,
        payment_status: :pending
      }, actor: actor) do
        {:ok, _sub} ->
          subscriptions = load_subscriptions(gym.id, actor)
          sub_map = build_sub_map(subscriptions)

          {:noreply,
           socket
           |> put_flash(:info, "Plan assigned successfully!")
           |> assign(subscriptions: subscriptions, sub_map: sub_map, assigning_member_id: nil)}

        {:error, error} ->
          {:noreply, put_flash(socket, :error, AshErrorHelpers.user_friendly_message(error))}
      end
    else
      {:noreply, put_flash(socket, :error, "Plan not found.")}
    end
  end

  def handle_event("toggle_payment", %{"id" => sub_id}, socket) do
    actor = socket.assigns.current_user
    gym = socket.assigns.gym

    sub = Enum.find(socket.assigns.subscriptions, &(&1.id == sub_id))

    if sub do
      new_status = if sub.payment_status == :paid, do: :pending, else: :paid

      case FitTrackerz.Billing.update_subscription(sub, %{payment_status: new_status}, actor: actor) do
        {:ok, _updated} ->
          subscriptions = load_subscriptions(gym.id, actor)
          sub_map = build_sub_map(subscriptions)

          {:noreply,
           socket
           |> put_flash(:info, "Payment marked as #{new_status}.")
           |> assign(subscriptions: subscriptions, sub_map: sub_map)}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to update payment status.")}
      end
    else
      {:noreply, put_flash(socket, :error, "Subscription not found.")}
    end
  end

  # ── Helpers ──

  defp load_members(gym_id, actor) do
    case FitTrackerz.Gym.list_members_by_gym(gym_id, actor: actor, load: [:user]) do
      {:ok, members} -> members
      _ -> []
    end
  end

  defp load_plans(gym_id, actor) do
    case FitTrackerz.Billing.list_plans_by_gym(gym_id, actor: actor) do
      {:ok, plans} -> plans
      _ -> []
    end
  end

  defp load_subscriptions(gym_id, actor) do
    case FitTrackerz.Billing.list_subscriptions_by_gym(gym_id, actor: actor) do
      {:ok, subs} -> subs
      _ -> []
    end
  end

  defp build_sub_map(subscriptions) do
    subscriptions
    |> Enum.filter(&(&1.status == :active))
    |> Enum.group_by(& &1.member_id)
    |> Enum.map(fn {member_id, subs} ->
      {member_id, Enum.max_by(subs, & &1.inserted_at, DateTime)}
    end)
    |> Map.new()
  end

  defp calculate_end_date(start, :day_pass), do: DateTime.add(start, 1, :day)
  defp calculate_end_date(start, :monthly), do: DateTime.add(start, 30, :day)
  defp calculate_end_date(start, :quarterly), do: DateTime.add(start, 90, :day)
  defp calculate_end_date(start, :half_yearly), do: DateTime.add(start, 180, :day)
  defp calculate_end_date(start, :annual), do: DateTime.add(start, 365, :day)
  defp calculate_end_date(start, :two_year), do: DateTime.add(start, 730, :day)
  defp calculate_end_date(start, _), do: DateTime.add(start, 30, :day)

  defp format_price(paise) when is_integer(paise) do
    rupees = div(paise, 100)
    "Rs. #{rupees}"
  end

  defp format_price(_), do: "--"

  defp format_duration(:day_pass), do: "1 Day"
  defp format_duration(:monthly), do: "1 Month"
  defp format_duration(:quarterly), do: "3 Months"
  defp format_duration(:half_yearly), do: "6 Months"
  defp format_duration(:annual), do: "12 Months"
  defp format_duration(:two_year), do: "24 Months"
  defp format_duration(other), do: other |> to_string() |> String.replace("_", " ") |> String.capitalize()

  # ── Render ──

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="space-y-8">
        <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
          <div class="flex items-center gap-3">
            <Layouts.back_button />
            <div>
              <h1 class="text-2xl sm:text-3xl font-brand">Members</h1>
              <p class="text-base-content/50 mt-1">Manage gym memberships, plans, and payments.</p>
            </div>
          </div>
          <%= if @gym do %>
            <button
              phx-click="toggle_invite"
              class="btn btn-primary btn-sm gap-2 font-semibold"
              id="toggle-invite-btn"
            >
              <.icon name="hero-user-plus-mini" class="size-4" /> Invite Member
            </button>
          <% end %>
        </div>

        <%= if @gym == nil do %>
          <div class="card bg-base-200/50 border border-base-300/50" id="no-gym-card">
            <div class="card-body p-6 text-center">
              <.icon name="hero-building-office-solid" class="size-12 text-base-content/20 mx-auto" />
              <h2 class="text-lg font-bold mt-4">No Gym Found</h2>
              <p class="text-base-content/50 mt-1">
                You need to create a gym first before managing members.
              </p>
              <a href="/gym/setup" class="btn btn-primary btn-sm mt-4 gap-2">
                <.icon name="hero-plus-mini" class="size-4" /> Setup Gym
              </a>
            </div>
          </div>
        <% else %>
          <%!-- Invite Form --%>
          <%= if @show_invite do %>
            <div class="card bg-base-200/50 border border-base-300/50" id="invite-member-card">
              <div class="card-body p-6">
                <h2 class="text-lg font-bold flex items-center gap-2 mb-4">
                  <.icon name="hero-envelope-solid" class="size-5 text-primary" /> Invite New Member
                </h2>
                <.form
                  for={@invite_form}
                  id="invite-member-form"
                  phx-change="validate_invite"
                  phx-submit="invite"
                >
                  <div class="flex flex-col sm:flex-row gap-4 items-end">
                    <div class="flex-1">
                      <.input
                        field={@invite_form[:email]}
                        type="email"
                        label="Email Address"
                        placeholder="member@example.com"
                        required
                      />
                    </div>

                    <div class="mb-2">
                      <button type="submit" class="btn btn-primary btn-sm gap-2" id="send-invite-btn">
                        <.icon name="hero-paper-airplane" class="size-4" /> Send Invite
                      </button>
                    </div>
                  </div>
                </.form>
              </div>
            </div>
          <% end %>

          <%!-- Members Table --%>
          <div class="card bg-base-200/50 border border-base-300/50" id="members-table-card">
            <div class="card-body p-6">
              <h2 class="text-lg font-bold flex items-center gap-2 mb-4">
                <.icon name="hero-user-group-solid" class="size-5 text-primary" /> All Members
                <span class="badge badge-neutral badge-sm">{length(@members)}</span>
              </h2>
              <%= if @members == [] do %>
                <div class="flex items-center gap-3 p-4 rounded-lg bg-base-300/20">
                  <div class="w-2 h-2 rounded-full bg-base-content/20 shrink-0"></div>
                  <p class="text-sm text-base-content/50">
                    No members yet. Send invitations to grow your gym!
                  </p>
                </div>
              <% else %>
                <div class="overflow-x-auto">
                  <table class="table table-sm" id="members-table">
                    <thead>
                      <tr class="text-base-content/40">
                        <th>Name</th>
                        <th>Email</th>
                        <th>Status</th>
                        <th>Plan</th>
                        <th>Payment</th>
                        <th>Actions</th>
                      </tr>
                    </thead>
                    <tbody>
                      <%= for member <- @members do %>
                        <% sub = Map.get(@sub_map, member.id) %>
                        <tr id={"member-#{member.id}"}>
                          <td class="font-medium">{member.user.name}</td>
                          <td class="text-base-content/60">{member.user.email}</td>
                          <td>
                            <%= if member.is_active do %>
                              <span class="badge badge-success badge-sm">Active</span>
                            <% else %>
                              <span class="badge badge-error badge-sm">Inactive</span>
                            <% end %>
                          </td>
                          <td>
                            <%= if sub do %>
                              <div class="flex flex-col">
                                <span class="text-sm font-medium">{sub.subscription_plan.name}</span>
                                <span class="text-xs text-base-content/40">
                                  {format_duration(sub.subscription_plan.duration)} &middot; {format_price(sub.subscription_plan.price_in_paise)}
                                </span>
                              </div>
                            <% else %>
                              <%= if @assigning_member_id == member.id do %>
                                <div class="flex items-center gap-2">
                                  <%= if @plans == [] do %>
                                    <span class="text-xs text-base-content/40">No plans created yet</span>
                                  <% else %>
                                    <select
                                      class="select select-bordered select-xs w-40"
                                      id={"plan-select-#{member.id}"}
                                      phx-change="assign_plan"
                                      phx-value-member_id={member.id}
                                      name="plan_id"
                                    >
                                      <option value="">Pick a plan</option>
                                      <%= for plan <- @plans do %>
                                        <option value={plan.id}>
                                          {plan.name}
                                        </option>
                                      <% end %>
                                    </select>
                                  <% end %>
                                  <button
                                    phx-click="cancel_assign_plan"
                                    class="btn btn-ghost btn-xs"
                                    id={"cancel-assign-#{member.id}"}
                                  >
                                    <.icon name="hero-x-mark-mini" class="size-3.5" />
                                  </button>
                                </div>
                              <% else %>
                                <button
                                  phx-click="show_assign_plan"
                                  phx-value-member-id={member.id}
                                  class="btn btn-ghost btn-xs gap-1 text-primary"
                                  id={"assign-plan-#{member.id}"}
                                >
                                  <.icon name="hero-plus-mini" class="size-3.5" /> Assign Plan
                                </button>
                              <% end %>
                            <% end %>
                          </td>
                          <td>
                            <%= if sub do %>
                              <label class="flex items-center gap-2 cursor-pointer">
                                <input
                                  type="checkbox"
                                  class="checkbox checkbox-sm checkbox-success"
                                  checked={sub.payment_status == :paid}
                                  phx-click="toggle_payment"
                                  phx-value-id={sub.id}
                                  id={"payment-toggle-#{sub.id}"}
                                />
                                <span class={"text-xs font-medium #{if sub.payment_status == :paid, do: "text-success", else: "text-warning"}"}>
                                  {sub.payment_status |> to_string() |> String.capitalize()}
                                </span>
                              </label>
                            <% else %>
                              <span class="text-xs text-base-content/30">--</span>
                            <% end %>
                          </td>
                          <td>
                            <div class="flex items-center gap-1">
                              <button
                                phx-click="toggle_active"
                                phx-value-id={member.id}
                                class="btn btn-ghost btn-xs"
                                id={"toggle-member-#{member.id}"}
                              >
                                <%= if member.is_active do %>
                                  <.icon name="hero-pause" class="size-4 text-warning" />
                                <% else %>
                                  <.icon name="hero-play" class="size-4 text-success" />
                                <% end %>
                              </button>
                            </div>
                          </td>
                        </tr>
                      <% end %>
                    </tbody>
                  </table>
                </div>
              <% end %>
            </div>
          </div>
        <% end %>
      </div>
    </Layouts.app>
    """
  end
end
