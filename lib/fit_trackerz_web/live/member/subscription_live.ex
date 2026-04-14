defmodule FitTrackerzWeb.Member.SubscriptionLive do
  use FitTrackerzWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    actor = socket.assigns.current_user

    memberships = case FitTrackerz.Gym.list_active_memberships(actor.id, actor: actor, load: [:gym]) do
      {:ok, memberships} -> memberships
      _ -> []
    end

    case memberships do
      [] ->
        {:ok,
         assign(socket,
           page_title: "Subscription",
           memberships: [],
           subscriptions: [],
           no_gym: true
         )}

      memberships ->
        member_ids = Enum.map(memberships, & &1.id)

        subscriptions = case FitTrackerz.Billing.list_active_subscriptions_by_member(member_ids, actor: actor, load: [:subscription_plan, :gym]) do
          {:ok, subs} -> Enum.sort_by(subs, & &1.inserted_at, {:desc, DateTime})
          _ -> []
        end

        {:ok,
         assign(socket,
           page_title: "Subscription",
           memberships: memberships,
           subscriptions: subscriptions,
           no_gym: false
         )}
    end
  end

  defp format_datetime(datetime) do
    Calendar.strftime(datetime, "%b %d, %Y")
  end

  defp format_price(price_in_paise) when is_integer(price_in_paise) do
    rupees = div(price_in_paise, 100)
    paise = rem(price_in_paise, 100)

    if paise == 0 do
      "Rs. #{rupees}"
    else
      "Rs. #{rupees}.#{String.pad_leading(Integer.to_string(paise), 2, "0")}"
    end
  end

  defp format_price(_), do: "--"

  defp format_duration(:day_pass), do: "1 Day Pass"
  defp format_duration(:monthly), do: "1 Month"
  defp format_duration(:quarterly), do: "3 Months"
  defp format_duration(:half_yearly), do: "6 Months"
  defp format_duration(:annual), do: "12 Months"
  defp format_duration(:two_year), do: "24 Months"

  defp format_duration(other),
    do: other |> to_string() |> String.replace("_", " ") |> String.capitalize()

  defp format_plan_type(:general), do: "General"
  defp format_plan_type(:personal_training), do: "Personal Training"
  defp format_plan_type(other), do: other |> to_string() |> String.capitalize()

  defp subscription_badge_variant(:active), do: "success"
  defp subscription_badge_variant(:cancelled), do: "error"
  defp subscription_badge_variant(:expired), do: "neutral"
  defp subscription_badge_variant(_), do: "neutral"

  defp payment_badge_variant(:pending), do: "warning"
  defp payment_badge_variant(:paid), do: "success"
  defp payment_badge_variant(:failed), do: "error"
  defp payment_badge_variant(:refunded), do: "info"
  defp payment_badge_variant(_), do: "neutral"

  defp format_status(status), do: status |> to_string() |> String.capitalize()

  defp time_remaining_pct(sub) do
    starts = sub.starts_at
    ends = sub.ends_at
    now = DateTime.utc_now()
    total = DateTime.diff(ends, starts, :second)
    elapsed = DateTime.diff(now, starts, :second)
    if total > 0, do: min(100, max(0, round(elapsed / total * 100))), else: 0
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <.page_header title="My Subscriptions" subtitle="Manage your gym subscriptions and billing." back_path="/member" />

      <%= if @no_gym do %>
        <.empty_state
          icon="hero-building-office-2"
          title="No Gym Membership"
          subtitle="You haven't joined any gym yet. Ask a gym operator to invite you."
        />
      <% else %>
        <%= if @subscriptions == [] do %>
          <.empty_state
            icon="hero-credit-card"
            title="No Active Subscription"
            subtitle="You don't have any subscriptions yet. Contact your gym to subscribe to a plan."
          />
        <% else %>
          <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
            <div
              :for={sub <- @subscriptions}
              id={"subscription-#{sub.id}"}
            >
              <.card>
                <div class="space-y-5">
                  <%!-- Header --%>
                  <div class="flex items-start justify-between gap-3">
                    <div>
                      <h2 class="text-xl font-bold">{sub.subscription_plan.name}</h2>
                      <%= if sub.gym do %>
                        <p class="text-sm text-base-content/50 mt-1 flex items-center gap-1">
                          <.icon name="hero-building-office-2-mini" class="size-3" />
                          {sub.gym.name}
                        </p>
                      <% end %>
                    </div>
                    <.badge variant={subscription_badge_variant(sub.status)}>
                      {format_status(sub.status)}
                    </.badge>
                  </div>

                  <%!-- Time remaining progress --%>
                  <.progress_bar
                    value={time_remaining_pct(sub)}
                    color="primary"
                    label="Time Elapsed"
                  />

                  <%!-- Plan Details --%>
                  <.detail_grid>
                    <:item label="Plan Type">{format_plan_type(sub.subscription_plan.plan_type)}</:item>
                    <:item label="Duration">{format_duration(sub.subscription_plan.duration)}</:item>
                    <:item label="Price">{format_price(sub.subscription_plan.price_in_paise)}</:item>
                    <:item label="Payment">
                      <.badge variant={payment_badge_variant(sub.payment_status)} size="sm">
                        {format_status(sub.payment_status)}
                      </.badge>
                    </:item>
                  </.detail_grid>

                  <%!-- Dates --%>
                  <div class="flex items-center gap-4 text-sm text-base-content/60 pt-3 border-t border-base-300/30">
                    <div class="flex items-center gap-1.5">
                      <.icon name="hero-calendar-mini" class="size-4 text-base-content/40" />
                      <span>Starts: {format_datetime(sub.starts_at)}</span>
                    </div>
                    <div class="flex items-center gap-1.5">
                      <.icon name="hero-calendar-days-mini" class="size-4 text-base-content/40" />
                      <span>Ends: {format_datetime(sub.ends_at)}</span>
                    </div>
                  </div>
                </div>
              </.card>
            </div>
          </div>
        <% end %>
      <% end %>
    </Layouts.app>
    """
  end
end
