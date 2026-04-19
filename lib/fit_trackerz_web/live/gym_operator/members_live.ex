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
        trainers = load_trainers(gym.id, actor)
        pending_assignments = load_pending_assignments(gym.id, actor)

        invite_form = to_form(%{"email" => ""}, as: "invite")

        {:ok,
         assign(socket,
           page_title: "Members",
           gym: gym,
           members: members,
           all_members: members,
           plans: plans,
           subscriptions: subscriptions,
           sub_map: sub_map,
           trainers: trainers,
           pending_assignments: pending_assignments,
           invite_form: invite_form,
           show_invite: false,
           assigning_member_id: nil,
           assigning_trainer_member_id: nil,
           search: "",
           filter_status: "all",
           filter_trainer: "all",
           filter_payment: "all"
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
           trainers: [],
           pending_assignments: %{},
           invite_form: nil,
           show_invite: false,
           assigning_member_id: nil,
           assigning_trainer_member_id: nil,
           search: "",
           filter_status: "all",
           filter_trainer: "all",
           filter_payment: "all",
           all_members: []
         )}
    end
  end

  # -- Event Handlers --

  @impl true
  def handle_event("search", %{"search" => search}, socket) do
    {:noreply,
     socket
     |> assign(search: search)
     |> apply_member_filters()}
  end

  def handle_event("filter_status", %{"status" => status}, socket) do
    {:noreply,
     socket
     |> assign(filter_status: status)
     |> apply_member_filters()}
  end

  def handle_event("filter_trainer", %{"trainer" => trainer_id}, socket) do
    {:noreply,
     socket
     |> assign(filter_trainer: trainer_id)
     |> apply_member_filters()}
  end

  def handle_event("filter_payment", %{"payment" => payment}, socket) do
    {:noreply,
     socket
     |> assign(filter_payment: payment)
     |> apply_member_filters()}
  end

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
             |> assign(all_members: members)
             |> apply_member_filters()}

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

  def handle_event("show_assign_trainer", %{"member-id" => member_id}, socket) do
    {:noreply, assign(socket, assigning_trainer_member_id: member_id)}
  end

  def handle_event("cancel_assign_trainer", _params, socket) do
    {:noreply, assign(socket, assigning_trainer_member_id: nil)}
  end

  def handle_event("assign_trainer", %{"trainer_id" => trainer_id, "member_id" => member_id}, socket) do
    actor = socket.assigns.current_user
    gym = socket.assigns.gym

    if trainer_id == "" do
      {:noreply, socket}
    else
      case FitTrackerz.Gym.create_assignment_request(%{
        gym_id: gym.id,
        member_id: member_id,
        trainer_id: trainer_id,
        requested_by_id: actor.id
      }, actor: actor) do
        {:ok, _request} ->
          members = load_members(gym.id, actor)
          pending_assignments = load_pending_assignments(gym.id, actor)

          {:noreply,
           socket
           |> put_flash(:info, "Trainer assignment request sent! The trainer needs to accept.")
           |> assign(all_members: members, pending_assignments: pending_assignments, assigning_trainer_member_id: nil)
           |> apply_member_filters()}

        {:error, error} ->
          {:noreply, put_flash(socket, :error, AshErrorHelpers.user_friendly_message(error))}
      end
    end
  end

  def handle_event("assign_plan", %{"plan_id" => plan_id, "member_id" => member_id} = params, socket) do
    actor = socket.assigns.current_user
    gym = socket.assigns.gym

    plan = Enum.find(socket.assigns.plans, &(&1.id == plan_id))

    if plan do
      # Use custom start date if provided, otherwise use now
      starts_at = case params["starts_at"] do
        date when is_binary(date) and date != "" ->
          case Date.from_iso8601(date) do
            {:ok, d} -> DateTime.new!(d, ~T[00:00:00], "Etc/UTC")
            _ -> DateTime.utc_now()
          end
        _ -> DateTime.utc_now()
      end

      ends_at = calculate_end_date(starts_at, plan.duration)

      case FitTrackerz.Billing.create_subscription(%{
        member_id: member_id,
        subscription_plan_id: plan_id,
        gym_id: gym.id,
        starts_at: starts_at,
        ends_at: ends_at,
        payment_status: :pending
      }, actor: actor) do
        {:ok, _sub} ->
          # Also update member's joined_at if not set
          update_joined_at(member_id, starts_at, actor)

          subscriptions = load_subscriptions(gym.id, actor)
          sub_map = build_sub_map(subscriptions)
          members = load_members(gym.id, actor)

          # Send notification to the member
          notify_plan_assigned(member_id, plan, gym, actor)

          {:noreply,
           socket
           |> put_flash(:info, "Plan assigned successfully!")
           |> assign(subscriptions: subscriptions, sub_map: sub_map, all_members: members, assigning_member_id: nil)
           |> apply_member_filters()}

        {:error, error} ->
          {:noreply, put_flash(socket, :error, AshErrorHelpers.user_friendly_message(error))}
      end
    else
      {:noreply, put_flash(socket, :error, "Plan not found.")}
    end
  end

  def handle_event("renew_subscription", %{"id" => sub_id}, socket) do
    actor = socket.assigns.current_user
    gym = socket.assigns.gym

    sub = Enum.find(socket.assigns.subscriptions, &(&1.id == sub_id))

    if sub do
      now = DateTime.utc_now()
      # Start from now (or from ends_at if subscription hasn't expired yet)
      starts_at = if DateTime.compare(sub.ends_at, now) == :gt, do: sub.ends_at, else: now
      ends_at = calculate_end_date(starts_at, sub.subscription_plan.duration)

      case FitTrackerz.Billing.create_subscription(%{
        member_id: sub.member_id,
        subscription_plan_id: sub.subscription_plan_id,
        gym_id: gym.id,
        starts_at: starts_at,
        ends_at: ends_at,
        payment_status: :pending
      }, actor: actor) do
        {:ok, _new_sub} ->
          # Cancel the old subscription if it's expired
          if sub.status == :expired or DateTime.compare(sub.ends_at, now) != :gt do
            FitTrackerz.Billing.cancel_subscription(sub, actor: actor)
          end

          subscriptions = load_subscriptions(gym.id, actor)
          sub_map = build_sub_map(subscriptions)

          {:noreply,
           socket
           |> put_flash(:info, "Subscription renewed successfully!")
           |> assign(subscriptions: subscriptions, sub_map: sub_map)}

        {:error, error} ->
          {:noreply, put_flash(socket, :error, AshErrorHelpers.user_friendly_message(error))}
      end
    else
      {:noreply, put_flash(socket, :error, "Subscription not found.")}
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

  # -- Helpers --

  defp apply_member_filters(socket) do
    members =
      socket.assigns.all_members
      |> filter_members_by_search(socket.assigns.search)
      |> filter_members_by_status(socket.assigns.filter_status)
      |> filter_members_by_trainer(socket.assigns.filter_trainer)
      |> filter_members_by_payment(socket.assigns.filter_payment, socket.assigns.sub_map)

    assign(socket, members: members)
  end

  defp filter_members_by_payment(members, "all", _sub_map), do: members
  defp filter_members_by_payment(members, "paid", sub_map) do
    Enum.filter(members, fn m ->
      case Map.get(sub_map, m.id) do
        %{payment_status: :paid} -> true
        _ -> false
      end
    end)
  end
  defp filter_members_by_payment(members, "pending", sub_map) do
    Enum.filter(members, fn m ->
      case Map.get(sub_map, m.id) do
        %{payment_status: :pending} -> true
        _ -> false
      end
    end)
  end
  defp filter_members_by_payment(members, "no_plan", sub_map) do
    Enum.filter(members, fn m -> Map.get(sub_map, m.id) == nil end)
  end
  defp filter_members_by_payment(members, _, _sub_map), do: members

  defp payment_counts(members, sub_map) do
    Enum.reduce(members, %{paid: 0, pending: 0, no_plan: 0}, fn m, acc ->
      case Map.get(sub_map, m.id) do
        %{payment_status: :paid} -> Map.update!(acc, :paid, &(&1 + 1))
        %{payment_status: :pending} -> Map.update!(acc, :pending, &(&1 + 1))
        nil -> Map.update!(acc, :no_plan, &(&1 + 1))
        _ -> acc
      end
    end)
  end

  defp filter_members_by_search(members, ""), do: members
  defp filter_members_by_search(members, search) do
    q = String.downcase(search)
    Enum.filter(members, fn m ->
      String.contains?(String.downcase(m.user.name || ""), q) or
        String.contains?(String.downcase(to_string(m.user.email)), q)
    end)
  end

  defp filter_members_by_status(members, "all"), do: members
  defp filter_members_by_status(members, "active"), do: Enum.filter(members, & &1.is_active)
  defp filter_members_by_status(members, "inactive"), do: Enum.reject(members, & &1.is_active)
  defp filter_members_by_status(members, _), do: members

  defp filter_members_by_trainer(members, "all"), do: members
  defp filter_members_by_trainer(members, "unassigned") do
    Enum.filter(members, &is_nil(&1.assigned_trainer_id))
  end
  defp filter_members_by_trainer(members, trainer_id) do
    Enum.filter(members, &(&1.assigned_trainer_id == trainer_id))
  end

  defp load_members(gym_id, actor) do
    case FitTrackerz.Gym.list_members_by_gym(gym_id, actor: actor, load: [:user, assigned_trainer: [:user]]) do
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

  defp load_pending_assignments(gym_id, actor) do
    case FitTrackerz.Gym.list_pending_assignments_by_gym(gym_id, actor: actor) do
      {:ok, requests} -> Map.new(requests, &{&1.member_id, &1})
      _ -> %{}
    end
  end

  defp load_trainers(gym_id, actor) do
    case FitTrackerz.Gym.list_active_trainers_by_gym(gym_id, actor: actor, load: [:user]) do
      {:ok, trainers} -> trainers
      _ -> []
    end
  end

  defp load_subscriptions(gym_id, actor) do
    case FitTrackerz.Billing.list_subscriptions_by_gym(gym_id, actor: actor) do
      {:ok, subs} -> subs
      _ -> []
    end
  end

  defp update_joined_at(member_id, starts_at, actor) do
    case FitTrackerz.Gym.get_gym_member(member_id, actor: actor) do
      {:ok, member} ->
        if is_nil(member.joined_at) do
          FitTrackerz.Gym.update_gym_member(member, %{joined_at: DateTime.to_date(starts_at)}, actor: actor)
        end

      _ ->
        :ok
    end
  end

  defp notify_plan_assigned(member_id, plan, gym, actor) do
    case FitTrackerz.Gym.get_gym_member(member_id, actor: actor, load: [:user]) do
      {:ok, member} ->
        Ash.create(FitTrackerz.Notifications.Notification,
          %{
            type: :plan_assigned,
            title: "Plan Assigned",
            message: "You have been assigned the #{plan.name} plan at #{gym.name}.",
            user_id: member.user.id,
            gym_id: gym.id,
            metadata: %{"plan_id" => plan.id, "member_id" => member_id}
          },
          authorize?: false
        )

        Phoenix.PubSub.broadcast(
          FitTrackerz.PubSub,
          "notifications:#{member.user.id}",
          {:new_notification, %{type: :plan_assigned, title: "Plan Assigned"}}
        )

      _ ->
        :ok
    end
  end

  defp subscription_expiring?(sub) do
    if sub && sub.status == :active do
      days_left = DateTime.diff(sub.ends_at, DateTime.utc_now(), :day)
      days_left <= 3
    else
      false
    end
  end

  defp subscription_expired?(sub) do
    if sub do
      sub.status == :expired or DateTime.compare(sub.ends_at, DateTime.utc_now()) != :gt
    else
      false
    end
  end

  defp days_remaining(sub) do
    if sub do
      days = DateTime.diff(sub.ends_at, DateTime.utc_now(), :day)
      if days < 0, do: 0, else: days
    else
      0
    end
  end

  defp build_sub_map(subscriptions) do
    subscriptions
    |> Enum.filter(&(&1.status in [:active, :expired]))
    |> Enum.group_by(& &1.member_id)
    |> Enum.map(fn {member_id, subs} ->
      # Prefer active subscriptions, then most recent
      best = Enum.find(subs, &(&1.status == :active)) ||
             Enum.max_by(subs, & &1.inserted_at, DateTime)
      {member_id, best}
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

  # -- Render --

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} unread_notification_count={assigns[:unread_notification_count] || 0}>
      <div class="space-y-6">
        <.page_header title="Members" subtitle="Manage gym memberships, plans, and payments." back_path="/gym/dashboard">
          <:actions>
            <%= if @gym do %>
              <.button variant="primary" size="sm" icon="hero-user-plus-mini" phx-click="toggle_invite" id="toggle-invite-btn">Invite Member</.button>
            <% end %>
          </:actions>
        </.page_header>

        <%= if @gym == nil do %>
          <.empty_state icon="hero-building-office-solid" title="No Gym Found" subtitle="You need to create a gym first before managing members.">
            <:action>
              <.button variant="primary" size="sm" icon="hero-plus-mini" navigate="/gym/setup">Setup Gym</.button>
            </:action>
          </.empty_state>
        <% else %>
          <%!-- Invite Form --%>
          <%= if @show_invite do %>
            <.card title="Invite New Member" id="invite-member-card">
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
                    />
                  </div>
                  <div class="mb-2">
                    <.button variant="primary" size="sm" icon="hero-paper-airplane" type="submit" id="send-invite-btn">Send Invite</.button>
                  </div>
                </div>
              </.form>
            </.card>
          <% end %>

          <% pay_counts = payment_counts(@all_members, @sub_map) %>

          <%!-- Search & Filter --%>
          <.filter_bar search_placeholder="Search by name or email..." search_value={@search} on_search="search">
            <:filter>
              <div class="flex flex-wrap gap-2 items-center">
                <.button
                  variant={if(@filter_status == "all", do: "primary", else: "ghost")}
                  size="sm"
                  phx-click="filter_status"
                  phx-value-status="all"
                >
                  All <.badge variant="neutral" size="sm">{length(@all_members)}</.badge>
                </.button>
                <.button
                  variant={if(@filter_status == "active", do: "primary", else: "ghost")}
                  size="sm"
                  phx-click="filter_status"
                  phx-value-status="active"
                >
                  Active
                </.button>
                <.button
                  variant={if(@filter_status == "inactive", do: "primary", else: "ghost")}
                  size="sm"
                  phx-click="filter_status"
                  phx-value-status="inactive"
                >
                  Inactive
                </.button>
                <select
                  phx-change="filter_trainer"
                  name="trainer"
                  class="select select-bordered select-sm w-44"
                  id="filter-trainer-select"
                >
                  <option value="all" selected={@filter_trainer == "all"}>All Trainers</option>
                  <option value="unassigned" selected={@filter_trainer == "unassigned"}>Unassigned</option>
                  <%= for trainer <- @trainers do %>
                    <option value={trainer.id} selected={@filter_trainer == trainer.id}>
                      {trainer.user.name}
                    </option>
                  <% end %>
                </select>
              </div>
            </:filter>
          </.filter_bar>

          <%!-- Payment Filter --%>
          <div class="flex flex-wrap items-center gap-2 -mt-2">
            <span class="text-xs text-base-content/50 uppercase font-semibold mr-1">Payment:</span>
            <.button
              variant={if(@filter_payment == "all", do: "primary", else: "ghost")}
              size="sm"
              phx-click="filter_payment"
              phx-value-payment="all"
              id="filter-payment-all"
            >
              All <.badge variant="neutral" size="sm">{length(@all_members)}</.badge>
            </.button>
            <.button
              variant={if(@filter_payment == "paid", do: "primary", else: "ghost")}
              size="sm"
              phx-click="filter_payment"
              phx-value-payment="paid"
              id="filter-payment-paid"
            >
              Paid <.badge variant="success" size="sm">{pay_counts.paid}</.badge>
            </.button>
            <.button
              variant={if(@filter_payment == "pending", do: "primary", else: "ghost")}
              size="sm"
              phx-click="filter_payment"
              phx-value-payment="pending"
              id="filter-payment-pending"
            >
              Pending <.badge variant="warning" size="sm">{pay_counts.pending}</.badge>
            </.button>
            <.button
              variant={if(@filter_payment == "no_plan", do: "primary", else: "ghost")}
              size="sm"
              phx-click="filter_payment"
              phx-value-payment="no_plan"
              id="filter-payment-no-plan"
            >
              No Plan <.badge variant="neutral" size="sm">{pay_counts.no_plan}</.badge>
            </.button>
          </div>

          <%!-- Members Table --%>
          <.card title="All Members" subtitle={"#{length(@members)} members"}>
            <%= if @members == [] do %>
              <.empty_state
                icon="hero-user-group"
                title={if @search != "" or @filter_status != "all", do: "No members match your filters", else: "No members yet"}
                subtitle={if @search != "" or @filter_status != "all", do: "Try adjusting your search or filters.", else: "Send invitations to grow your gym!"}
              />
            <% else %>
              <div class="overflow-x-auto">
                <table class="table table-sm" id="members-table">
                  <thead>
                    <tr class="text-base-content/40">
                      <th>Name</th>
                      <th>Email</th>
                      <th>Joined</th>
                      <th>Status</th>
                      <th>Trainer</th>
                      <th>Plan</th>
                      <th>Payment</th>
                      <th>Actions</th>
                    </tr>
                  </thead>
                  <tbody>
                    <%= for member <- @members do %>
                      <% sub = Map.get(@sub_map, member.id) %>
                      <tr id={"member-#{member.id}"}>
                        <td>
                          <div class="flex items-center gap-2">
                            <.avatar name={member.user.name || "U"} size="sm" />
                            <span class="font-medium">{member.user.name}</span>
                          </div>
                        </td>
                        <td class="text-base-content/60">{member.user.email}</td>
                        <td class="text-sm text-base-content/60">
                          <%= if member.joined_at do %>
                            {Calendar.strftime(member.joined_at, "%b %d, %Y")}
                          <% else %>
                            <span class="text-base-content/30">--</span>
                          <% end %>
                        </td>
                        <td>
                          <%= if member.is_active do %>
                            <.badge variant="success" size="sm">Active</.badge>
                          <% else %>
                            <.badge variant="error" size="sm">Inactive</.badge>
                          <% end %>
                        </td>
                        <td>
                          <% pending_req = Map.get(@pending_assignments, member.id) %>
                          <%= cond do %>
                            <% member.assigned_trainer && member.assigned_trainer.user -> %>
                              <div class="flex items-center gap-2">
                                <.avatar name={member.assigned_trainer.user.name || "T"} size="sm" />
                                <span class="text-sm">{member.assigned_trainer.user.name}</span>
                              </div>
                            <% pending_req && pending_req.trainer && pending_req.trainer.user -> %>
                              <div class="flex items-center gap-2">
                                <.avatar name={pending_req.trainer.user.name || "T"} size="sm" />
                                <div class="flex flex-col leading-tight">
                                  <span class="text-sm">{pending_req.trainer.user.name}</span>
                                  <.badge variant="warning" size="sm">Pending</.badge>
                                </div>
                              </div>
                            <% true -> %>
                              <%= if @assigning_trainer_member_id == member.id do %>
                              <form phx-submit="assign_trainer" class="flex items-center gap-1" id={"trainer-form-#{member.id}"}>
                                <input type="hidden" name="member_id" value={member.id} />
                                <select
                                  class="select select-bordered select-xs w-32"
                                  name="trainer_id"
                                  id={"trainer-select-#{member.id}"}
                                >
                                  <option value="">Pick trainer</option>
                                  <%= for trainer <- @trainers do %>
                                    <option value={trainer.id}>{trainer.user.name}</option>
                                  <% end %>
                                </select>
                                <button type="submit" class="btn btn-info btn-xs" id={"submit-trainer-#{member.id}"}>
                                  <.icon name="hero-check-mini" class="size-3" />
                                </button>
                                <button
                                  type="button"
                                  phx-click="cancel_assign_trainer"
                                  class="btn btn-ghost btn-xs"
                                  id={"cancel-trainer-#{member.id}"}
                                >
                                  <.icon name="hero-x-mark-mini" class="size-3" />
                                </button>
                              </form>
                            <% else %>
                              <.button
                                variant="ghost"
                                size="sm"
                                icon="hero-plus-mini"
                                phx-click="show_assign_trainer"
                                phx-value-member-id={member.id}
                                id={"assign-trainer-#{member.id}"}
                              >
                                Assign
                              </.button>
                            <% end %>
                          <% end %>
                        </td>
                        <td>
                          <%= if sub do %>
                            <div class="flex flex-col">
                              <span class="text-sm font-medium">{sub.subscription_plan.name}</span>
                              <span class="text-xs text-base-content/40">
                                {format_duration(sub.subscription_plan.duration)} &middot; {format_price(sub.subscription_plan.price_in_paise)}
                              </span>
                              <%= if subscription_expired?(sub) do %>
                                <.badge variant="error" size="sm" class="mt-1 w-fit">Expired</.badge>
                              <% else %>
                                <%= if subscription_expiring?(sub) do %>
                                  <.badge variant="warning" size="sm" class="mt-1 w-fit">{days_remaining(sub)} days left</.badge>
                                <% else %>
                                  <span class="text-xs text-base-content/40">
                                    Ends: {Calendar.strftime(sub.ends_at, "%b %d, %Y")}
                                  </span>
                                <% end %>
                              <% end %>
                              <%= if subscription_expiring?(sub) or subscription_expired?(sub) do %>
                                <button
                                  phx-click="renew_subscription"
                                  phx-value-id={sub.id}
                                  class="btn btn-success btn-xs mt-1 gap-1"
                                  id={"renew-#{sub.id}"}
                                >
                                  <.icon name="hero-arrow-path-mini" class="size-3" /> Renew
                                </button>
                              <% end %>
                            </div>
                          <% else %>
                            <%= if @assigning_member_id == member.id do %>
                              <form phx-submit="assign_plan" class="flex flex-col gap-2" id={"assign-form-#{member.id}"}>
                                <input type="hidden" name="member_id" value={member.id} />
                                <%= if @plans == [] do %>
                                  <span class="text-xs text-base-content/40">No plans created yet</span>
                                <% else %>
                                  <div class="flex items-center gap-2">
                                    <select
                                      class="select select-bordered select-xs w-40"
                                      id={"plan-select-#{member.id}"}
                                      name="plan_id"
                                    >
                                      <option value="">Pick a plan</option>
                                      <%= for plan <- @plans do %>
                                        <option value={plan.id}>
                                          {plan.name}
                                        </option>
                                      <% end %>
                                    </select>
                                    <button
                                      type="button"
                                      phx-click="cancel_assign_plan"
                                      class="btn btn-ghost btn-xs"
                                      id={"cancel-assign-#{member.id}"}
                                    >
                                      <.icon name="hero-x-mark-mini" class="size-3.5" />
                                    </button>
                                  </div>
                                  <div class="flex items-center gap-2">
                                    <input
                                      type="date"
                                      name="starts_at"
                                      class="input input-bordered input-xs w-36"
                                      id={"start-date-#{member.id}"}
                                      value={Date.to_iso8601(Date.utc_today())}
                                      title="Joining / Start date"
                                    />
                                    <.button variant="primary" size="sm" icon="hero-check-mini" type="submit" id={"submit-plan-#{member.id}"}>Assign</.button>
                                  </div>
                                <% end %>
                              </form>
                            <% else %>
                              <.button
                                variant="ghost"
                                size="sm"
                                icon="hero-plus-mini"
                                phx-click="show_assign_plan"
                                phx-value-member-id={member.id}
                                id={"assign-plan-#{member.id}"}
                              >
                                Assign Plan
                              </.button>
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
                              <.badge variant={if(sub.payment_status == :paid, do: "success", else: "warning")} size="sm">
                                {sub.payment_status |> to_string() |> String.capitalize()}
                              </.badge>
                            </label>
                          <% else %>
                            <span class="text-xs text-base-content/30">--</span>
                          <% end %>
                        </td>
                        <td>
                          <div class="flex items-center gap-1">
                            <.button
                              variant="ghost"
                              size="sm"
                              phx-click="toggle_active"
                              phx-value-id={member.id}
                              id={"toggle-member-#{member.id}"}
                            >
                              <%= if member.is_active do %>
                                <.icon name="hero-pause" class="size-4 text-warning" />
                              <% else %>
                                <.icon name="hero-play" class="size-4 text-success" />
                              <% end %>
                            </.button>
                          </div>
                        </td>
                      </tr>
                    <% end %>
                  </tbody>
                </table>
              </div>
            <% end %>
          </.card>
        <% end %>
      </div>
    </Layouts.app>
    """
  end
end
