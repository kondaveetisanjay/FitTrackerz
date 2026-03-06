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

  defp subscription_status_class(:active), do: "badge-success"
  defp subscription_status_class(:cancelled), do: "badge-error"
  defp subscription_status_class(:expired), do: "badge-ghost"
  defp subscription_status_class(_), do: "badge-ghost"

  defp payment_status_class(:pending), do: "badge-warning"
  defp payment_status_class(:paid), do: "badge-success"
  defp payment_status_class(:failed), do: "badge-error"
  defp payment_status_class(:refunded), do: "badge-info"
  defp payment_status_class(_), do: "badge-ghost"

  defp format_status(status), do: status |> to_string() |> String.capitalize()

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="space-y-8">
        <%!-- Page Header --%>
        <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
          <div class="flex items-center gap-3">
            <Layouts.back_button />
            <div>
              <h1 class="text-2xl sm:text-3xl font-brand">My Subscriptions</h1>
              <p class="text-base-content/50 mt-1">Manage your gym subscriptions and billing.</p>
            </div>
          </div>
        </div>

        <%= if @no_gym do %>
          <%!-- No Gym Membership --%>
          <div class="card bg-base-200/50 border border-base-300/50" id="no-gym-card">
            <div class="card-body items-center text-center p-8">
              <div class="w-16 h-16 rounded-2xl bg-warning/10 flex items-center justify-center mb-4">
                <.icon name="hero-building-office-2" class="size-8 text-warning" />
              </div>
              <h2 class="text-lg font-bold">No Gym Membership</h2>
              <p class="text-sm text-base-content/50 max-w-md mt-2">
                You haven't joined any gym yet. Ask a gym operator to invite you.
              </p>
            </div>
          </div>
        <% else %>
          <%= if @subscriptions == [] do %>
            <%!-- Empty State --%>
            <div class="card bg-base-200/50 border border-base-300/50" id="no-subscriptions">
              <div class="card-body items-center text-center p-8">
                <div class="w-16 h-16 rounded-2xl bg-warning/10 flex items-center justify-center mb-4">
                  <.icon name="hero-credit-card" class="size-8 text-warning" />
                </div>
                <h2 class="text-lg font-bold">No Active Subscription</h2>
                <p class="text-sm text-base-content/50 max-w-md mt-2">
                  You don't have any subscriptions yet. Contact your gym to subscribe to a plan.
                </p>
              </div>
            </div>
          <% else %>
            <%!-- Subscription Cards --%>
            <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
              <div
                :for={sub <- @subscriptions}
                class="card bg-base-200/50 border border-base-300/50"
                id={"subscription-#{sub.id}"}
              >
                <div class="card-body p-5">
                  <%!-- Header --%>
                  <div class="flex items-start justify-between gap-3">
                    <div>
                      <h2 class="text-lg font-bold flex items-center gap-2">
                        <.icon name="hero-credit-card-solid" class="size-5 text-warning" />
                        {sub.subscription_plan.name}
                      </h2>
                      <%= if sub.gym do %>
                        <p class="text-xs text-base-content/50 mt-1 flex items-center gap-1">
                          <.icon name="hero-building-office-2-mini" class="size-3" />
                          {sub.gym.name}
                        </p>
                      <% end %>
                    </div>
                    <span class={"badge badge-sm #{subscription_status_class(sub.status)}"}>
                      {format_status(sub.status)}
                    </span>
                  </div>

                  <%!-- Plan Details --%>
                  <div class="mt-4 grid grid-cols-2 gap-3">
                    <div class="p-3 rounded-lg bg-base-300/20">
                      <p class="text-xs text-base-content/40 font-medium uppercase tracking-wider">
                        Plan Type
                      </p>
                      <p class="text-sm font-semibold mt-1">
                        {format_plan_type(sub.subscription_plan.plan_type)}
                      </p>
                    </div>
                    <div class="p-3 rounded-lg bg-base-300/20">
                      <p class="text-xs text-base-content/40 font-medium uppercase tracking-wider">
                        Duration
                      </p>
                      <p class="text-sm font-semibold mt-1">
                        {format_duration(sub.subscription_plan.duration)}
                      </p>
                    </div>
                    <div class="p-3 rounded-lg bg-base-300/20">
                      <p class="text-xs text-base-content/40 font-medium uppercase tracking-wider">
                        Price
                      </p>
                      <p class="text-sm font-semibold mt-1">
                        {format_price(sub.subscription_plan.price_in_paise)}
                      </p>
                    </div>
                    <div class="p-3 rounded-lg bg-base-300/20">
                      <p class="text-xs text-base-content/40 font-medium uppercase tracking-wider">
                        Payment
                      </p>
                      <span class={"badge badge-sm mt-1 #{payment_status_class(sub.payment_status)}"}>
                        {format_status(sub.payment_status)}
                      </span>
                    </div>
                  </div>

                  <%!-- Dates --%>
                  <div class="mt-4 flex items-center gap-4 text-sm text-base-content/60">
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
              </div>
            </div>
          <% end %>
        <% end %>
      </div>
    </Layouts.app>
    """
  end
end
