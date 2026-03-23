defmodule FitTrackerzWeb.GymOperator.AnalyticsLive do
  use FitTrackerzWeb, :live_view

  alias FitTrackerz.Analytics

  @impl true
  def mount(_params, _session, socket) do
    actor = socket.assigns.current_user

    case FitTrackerz.Gym.list_gyms_by_owner(actor.id, actor: actor) do
      {:ok, [gym | _]} ->
        today = Date.utc_today()
        start_date = Date.add(today, -30)

        socket =
          socket
          |> assign(
            page_title: "Analytics",
            gym: gym,
            preset: "30d",
            start_date: start_date,
            end_date: today,
            custom_start: "",
            custom_end: ""
          )
          |> load_all_metrics()

        {:ok, socket}

      _ ->
        {:ok,
         assign(socket,
           page_title: "Analytics",
           gym: nil
         )}
    end
  end

  @impl true
  def handle_event("select_preset", %{"preset" => preset}, socket) do
    today = Date.utc_today()

    start_date =
      case preset do
        "7d" -> Date.add(today, -7)
        "30d" -> Date.add(today, -30)
        "90d" -> Date.add(today, -90)
        "year" -> Date.new!(today.year, 1, 1)
        _ -> Date.add(today, -30)
      end

    socket =
      socket
      |> assign(preset: preset, start_date: start_date, end_date: today)
      |> load_all_metrics()

    {:noreply, socket}
  end

  def handle_event("update_custom", %{"custom_start" => start_str, "custom_end" => end_str}, socket) do
    {:noreply, assign(socket, custom_start: start_str, custom_end: end_str)}
  end

  def handle_event("apply_custom_range", %{"custom_start" => start_str, "custom_end" => end_str}, socket) do
    with {:ok, start_date} <- Date.from_iso8601(start_str),
         {:ok, end_date} <- Date.from_iso8601(end_str),
         true <- Date.compare(start_date, end_date) != :gt do
      socket =
        socket
        |> assign(
          preset: "custom",
          start_date: start_date,
          end_date: end_date,
          custom_start: start_str,
          custom_end: end_str
        )
        |> load_all_metrics()

      {:noreply, socket}
    else
      _ ->
        {:noreply, put_flash(socket, :error, "Invalid date range. Ensure start date is before end date.")}
    end
  end

  defp load_all_metrics(socket) do
    gym_id = socket.assigns.gym.id
    start_date = socket.assigns.start_date
    end_date = socket.assigns.end_date

    active_count = Analytics.active_members_count(gym_id)
    previous_count = Analytics.active_members_count_as_of(gym_id, start_date)
    new_members = Analytics.new_members(gym_id, start_date, end_date)
    revenue = Analytics.revenue(gym_id, start_date, end_date)
    attendance = Analytics.attendance_trend(gym_id, start_date, end_date)
    subscriptions = Analytics.subscription_breakdown(gym_id)
    payments = Analytics.payment_collection(gym_id, start_date, end_date)
    classes = Analytics.class_utilization(gym_id, start_date, end_date)
    retention = Analytics.member_retention(gym_id, start_date, end_date)

    active_change =
      if previous_count > 0 do
        Float.round((active_count - previous_count) / previous_count * 100, 1)
      else
        0.0
      end

    socket
    |> assign(
      active_count: active_count,
      active_change: active_change,
      new_members_total: new_members.total,
      revenue_total: revenue.total,
      avg_daily_attendance: Float.round(attendance.avg_daily, 1),
      new_members_chart: build_new_members_chart(new_members.daily),
      revenue_chart: build_revenue_chart(revenue.daily),
      attendance_chart: build_attendance_chart(attendance.daily),
      subscription_chart: build_subscription_chart(subscriptions),
      payment_chart: build_payment_chart(payments),
      class_chart: build_class_chart(classes),
      retention_chart: build_retention_chart(retention)
    )
  end

  # ---------------------------------------------------------------------------
  # Chart builders
  # ---------------------------------------------------------------------------

  defp build_new_members_chart(daily) do
    %{
      type: "line",
      data: %{
        labels: Enum.map(daily, &format_date(&1.date)),
        datasets: [
          %{
            label: "New Members",
            data: Enum.map(daily, & &1.value),
            borderColor: "rgb(99, 102, 241)",
            backgroundColor: "rgba(99, 102, 241, 0.1)",
            fill: true,
            tension: 0.3
          }
        ]
      },
      options: %{scales: %{x: %{}, y: %{}}}
    }
  end

  defp build_revenue_chart(daily) do
    %{
      type: "bar",
      data: %{
        labels: Enum.map(daily, &format_date(&1.date)),
        datasets: [
          %{
            label: "Revenue",
            data: Enum.map(daily, fn d -> d.value / 100 end),
            backgroundColor: "rgba(34, 197, 94, 0.7)",
            borderColor: "rgb(34, 197, 94)",
            borderWidth: 1
          }
        ]
      },
      options: %{scales: %{x: %{}, y: %{}}}
    }
  end

  defp build_attendance_chart(daily) do
    %{
      type: "line",
      data: %{
        labels: Enum.map(daily, &format_date(&1.date)),
        datasets: [
          %{
            label: "Attendance",
            data: Enum.map(daily, & &1.value),
            borderColor: "rgb(245, 158, 11)",
            backgroundColor: "rgba(245, 158, 11, 0.1)",
            fill: true,
            tension: 0.3
          }
        ]
      },
      options: %{scales: %{x: %{}, y: %{}}}
    }
  end

  defp build_subscription_chart(subscriptions) do
    labels = ["Active", "Cancelled", "Expired"]
    keys = ["active", "cancelled", "expired"]
    data = Enum.map(keys, fn k -> Map.get(subscriptions, k, 0) end)

    %{
      type: "doughnut",
      data: %{
        labels: labels,
        datasets: [
          %{
            data: data,
            backgroundColor: [
              "rgb(34, 197, 94)",
              "rgb(245, 158, 11)",
              "rgb(239, 68, 68)"
            ]
          }
        ]
      },
      options: %{
        plugins: %{legend: %{display: true, position: "bottom"}}
      }
    }
  end

  defp build_payment_chart(payments) do
    labels = ["Paid", "Pending", "Failed", "Refunded"]
    keys = ["paid", "pending", "failed", "refunded"]
    data = Enum.map(keys, fn k -> Map.get(payments, k, 0) end)

    %{
      type: "doughnut",
      data: %{
        labels: labels,
        datasets: [
          %{
            data: data,
            backgroundColor: [
              "rgb(34, 197, 94)",
              "rgb(245, 158, 11)",
              "rgb(239, 68, 68)",
              "rgb(156, 163, 175)"
            ]
          }
        ]
      },
      options: %{
        plugins: %{legend: %{display: true, position: "bottom"}}
      }
    }
  end

  defp build_class_chart(classes) do
    labels = Enum.map(classes, & &1.class_name)

    %{
      type: "bar",
      data: %{
        labels: labels,
        datasets: [
          %{
            label: "Bookings",
            data: Enum.map(classes, & &1.bookings),
            backgroundColor: "rgba(99, 102, 241, 0.7)",
            borderColor: "rgb(99, 102, 241)",
            borderWidth: 1
          },
          %{
            label: "Capacity",
            data: Enum.map(classes, & &1.capacity),
            backgroundColor: "rgba(156, 163, 175, 0.5)",
            borderColor: "rgb(156, 163, 175)",
            borderWidth: 1
          }
        ]
      },
      options: %{
        indexAxis: "y",
        scales: %{x: %{}, y: %{}}
      }
    }
  end

  defp build_retention_chart(retention) do
    %{
      type: "line",
      data: %{
        labels: Enum.map(retention, &format_date(&1.date)),
        datasets: [
          %{
            label: "Active",
            data: Enum.map(retention, & &1.active),
            borderColor: "rgb(34, 197, 94)",
            backgroundColor: "rgba(34, 197, 94, 0.1)",
            tension: 0.3
          },
          %{
            label: "Inactive",
            data: Enum.map(retention, & &1.inactive),
            borderColor: "rgb(239, 68, 68)",
            backgroundColor: "rgba(239, 68, 68, 0.1)",
            tension: 0.3
          }
        ]
      },
      options: %{
        scales: %{x: %{}, y: %{}},
        plugins: %{legend: %{display: true, position: "bottom"}}
      }
    }
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp format_date(%Date{} = date) do
    month =
      case date.month do
        1 -> "Jan"
        2 -> "Feb"
        3 -> "Mar"
        4 -> "Apr"
        5 -> "May"
        6 -> "Jun"
        7 -> "Jul"
        8 -> "Aug"
        9 -> "Sep"
        10 -> "Oct"
        11 -> "Nov"
        12 -> "Dec"
      end

    "#{month} #{date.day}"
  end

  defp format_currency(paise) when is_integer(paise) do
    rupees = div(paise, 100)

    rupees
    |> Integer.to_string()
    |> String.graphemes()
    |> Enum.reverse()
    |> Enum.chunk_every(3)
    |> Enum.map(&Enum.reverse/1)
    |> Enum.reverse()
    |> Enum.map_join(",", &Enum.join/1)
  end

  defp format_currency(_), do: "0"

  defp preset_label("7d"), do: "7 Days"
  defp preset_label("30d"), do: "30 Days"
  defp preset_label("90d"), do: "90 Days"
  defp preset_label("year"), do: "This Year"
  defp preset_label(_), do: "Custom"

  # ---------------------------------------------------------------------------
  # Render
  # ---------------------------------------------------------------------------

  attr :id, :string, required: true
  attr :title, :string, required: true
  attr :chart_data, :map, required: true

  defp chart_card(assigns) do
    ~H"""
    <div class="card bg-base-200/50 border border-base-300/50">
      <div class="card-body p-4">
        <h3 class="text-sm font-semibold text-base-content/60 mb-3">{@title}</h3>
        <div id={@id} phx-hook="ChartHook" data-chart={Jason.encode!(@chart_data)}>
          <canvas class="w-full" style="height: 250px;"></canvas>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="space-y-6">
        <%= if @gym do %>
          <%!-- Header --%>
          <div>
            <div class="flex items-center gap-3 mb-1">
              <.link navigate="/gym" class="btn btn-ghost btn-sm btn-circle">
                <.icon name="hero-arrow-left-mini" class="size-4" />
              </.link>
              <h1 class="text-2xl sm:text-3xl font-brand">Analytics</h1>
            </div>
            <p class="text-base-content/50 ml-12">Performance metrics for {@gym.name}</p>
          </div>

          <%!-- Date Range Card --%>
          <div class="card bg-base-200/50 border border-base-300/50">
            <div class="card-body p-4">
              <div class="flex flex-wrap items-center gap-3">
                <div class="flex gap-1">
                  <%= for preset <- ["7d", "30d", "90d", "year"] do %>
                    <button
                      phx-click="select_preset"
                      phx-value-preset={preset}
                      class={[
                        "btn btn-sm",
                        if(@preset == preset, do: "btn-primary", else: "btn-ghost")
                      ]}
                    >
                      {preset_label(preset)}
                    </button>
                  <% end %>
                </div>

                <form phx-submit="apply_custom_range" phx-change="update_custom" class="flex items-center gap-2 ml-auto">
                  <input
                    type="date"
                    name="custom_start"
                    value={@custom_start}
                    class="input input-sm input-bordered w-36"
                  />
                  <span class="text-base-content/40">to</span>
                  <input
                    type="date"
                    name="custom_end"
                    value={@custom_end}
                    class="input input-sm input-bordered w-36"
                  />
                  <button type="submit" class="btn btn-sm btn-primary">
                    Apply
                  </button>
                </form>
              </div>
            </div>
          </div>

          <%!-- Summary Cards --%>
          <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
            <%!-- Active Members --%>
            <div class="card bg-base-200/50 border border-base-300/50">
              <div class="card-body p-4">
                <p class="text-sm text-base-content/40">Active Members</p>
                <div class="flex items-end gap-2">
                  <span class="text-3xl font-bold">{@active_count}</span>
                  <span class={[
                    "badge badge-sm",
                    if(@active_change >= 0, do: "text-success", else: "text-error")
                  ]}>
                    {if @active_change >= 0, do: "+", else: ""}{@active_change}%
                  </span>
                </div>
              </div>
            </div>

            <%!-- New Members --%>
            <div class="card bg-base-200/50 border border-base-300/50">
              <div class="card-body p-4">
                <p class="text-sm text-base-content/40">New Members</p>
                <span class="text-3xl font-bold">{@new_members_total}</span>
                <p class="text-xs text-base-content/60">in selected period</p>
              </div>
            </div>

            <%!-- Revenue --%>
            <div class="card bg-base-200/50 border border-base-300/50">
              <div class="card-body p-4">
                <p class="text-sm text-base-content/40">Revenue</p>
                <span class="text-3xl font-bold">&#8377;{format_currency(@revenue_total)}</span>
                <p class="text-xs text-base-content/60">paid subscriptions</p>
              </div>
            </div>

            <%!-- Avg Daily Attendance --%>
            <div class="card bg-base-200/50 border border-base-300/50">
              <div class="card-body p-4">
                <p class="text-sm text-base-content/40">Avg Daily Attendance</p>
                <span class="text-3xl font-bold">{@avg_daily_attendance}</span>
                <p class="text-xs text-base-content/60">check-ins per day</p>
              </div>
            </div>
          </div>

          <%!-- Charts Grid --%>
          <div class="grid grid-cols-1 lg:grid-cols-2 gap-4">
            <.chart_card id="new-members-chart" title="New Members" chart_data={@new_members_chart} />
            <.chart_card id="revenue-chart" title="Revenue" chart_data={@revenue_chart} />
            <.chart_card id="attendance-chart" title="Attendance" chart_data={@attendance_chart} />
            <.chart_card id="retention-chart" title="Member Retention" chart_data={@retention_chart} />
            <.chart_card
              id="subscription-chart"
              title="Subscription Status"
              chart_data={@subscription_chart}
            />
            <.chart_card
              id="payment-chart"
              title="Payment Collection"
              chart_data={@payment_chart}
            />
            <.chart_card
              id="class-chart"
              title="Class Utilization"
              chart_data={@class_chart}
            />
          </div>
        <% else %>
          <div class="text-center py-16">
            <p class="text-base-content/50">No gym found. Please set up your gym first.</p>
            <.link navigate="/gym/setup" class="btn btn-primary btn-sm mt-4">
              Set Up Gym
            </.link>
          </div>
        <% end %>
      </div>
    </Layouts.app>
    """
  end
end
