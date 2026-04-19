defmodule FitTrackerzWeb.GymOperator.DashboardsLive do
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
            page_title: "Dashboards",
            gym: gym,
            preset: "30d",
            start_date: start_date,
            end_date: today,
            custom_start: "",
            custom_end: "",
            viz_types: %{
              "new-members-chart" => "line",
              "revenue-chart" => "bar",
              "attendance-chart" => "line",
              "retention-chart" => "line",
              "subscription-chart" => "doughnut",
              "payment-chart" => "doughnut",
              "class-chart" => "bar"
            }
          )
          |> load_all_metrics()

        {:ok, socket}

      _ ->
        {:ok,
         assign(socket,
           page_title: "Dashboards",
           gym: nil,
           viz_types: %{
             "new-members-chart" => "line",
             "revenue-chart" => "bar",
             "attendance-chart" => "line",
             "retention-chart" => "line",
             "subscription-chart" => "doughnut",
             "payment-chart" => "doughnut",
             "class-chart" => "bar"
           }
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

  def handle_event("change_viz", %{"chart_id" => chart_id, "viz_type" => viz_type}, socket) do
    viz_types = Map.put(socket.assigns.viz_types, chart_id, viz_type)
    {:noreply, socket |> assign(viz_types: viz_types) |> load_all_metrics()}
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
      new_members_chart: build_new_members_chart(new_members.daily, socket.assigns.viz_types["new-members-chart"]),
      revenue_chart: build_revenue_chart(revenue.daily, socket.assigns.viz_types["revenue-chart"]),
      attendance_chart: build_attendance_chart(attendance.daily, socket.assigns.viz_types["attendance-chart"]),
      subscription_chart: build_subscription_chart(subscriptions, socket.assigns.viz_types["subscription-chart"]),
      payment_chart: build_payment_chart(payments, socket.assigns.viz_types["payment-chart"]),
      class_chart: build_class_chart(classes, socket.assigns.viz_types["class-chart"]),
      retention_chart: build_retention_chart(retention, socket.assigns.viz_types["retention-chart"])
    )
  end

  # ---------------------------------------------------------------------------
  # Chart builders
  # ---------------------------------------------------------------------------

  defp build_new_members_chart(daily, "table") do
    %{type: "table", data: %{
      headers: ["Date", "New Members"],
      rows: Enum.map(daily, fn d -> [format_date(d.date), d.value] end)
    }}
  end

  defp build_new_members_chart(daily, viz_type) do
    %{
      type: viz_type,
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

  defp build_revenue_chart(daily, "table") do
    %{type: "table", data: %{
      headers: ["Date", "Revenue"],
      rows: Enum.map(daily, fn d -> [format_date(d.date), d.value / 100] end)
    }}
  end

  defp build_revenue_chart(daily, viz_type) do
    %{
      type: viz_type,
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

  defp build_attendance_chart(daily, "table") do
    %{type: "table", data: %{
      headers: ["Date", "Attendance"],
      rows: Enum.map(daily, fn d -> [format_date(d.date), d.value] end)
    }}
  end

  defp build_attendance_chart(daily, viz_type) do
    %{
      type: viz_type,
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

  defp build_subscription_chart(subscriptions, "table") do
    labels = ["Active", "Cancelled", "Expired"]
    keys = ["active", "cancelled", "expired"]
    data = Enum.map(keys, fn k -> Map.get(subscriptions, k, 0) end)
    %{type: "table", data: %{
      headers: ["Status", "Count"],
      rows: Enum.zip(labels, data) |> Enum.map(fn {l, d} -> [l, d] end)
    }}
  end

  defp build_subscription_chart(subscriptions, "bar") do
    labels = ["Active", "Cancelled", "Expired"]
    keys = ["active", "cancelled", "expired"]
    data = Enum.map(keys, fn k -> Map.get(subscriptions, k, 0) end)

    %{
      type: "bar",
      data: %{
        labels: labels,
        datasets: [
          %{
            label: "Count",
            data: data,
            backgroundColor: [
              "rgb(34, 197, 94)",
              "rgb(245, 158, 11)",
              "rgb(239, 68, 68)"
            ]
          }
        ]
      },
      options: %{scales: %{x: %{}, y: %{}}}
    }
  end

  defp build_subscription_chart(subscriptions, _viz_type) do
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

  defp build_payment_chart(payments, "table") do
    labels = ["Paid", "Pending", "Failed", "Refunded"]
    keys = ["paid", "pending", "failed", "refunded"]
    data = Enum.map(keys, fn k -> Map.get(payments, k, 0) end)
    %{type: "table", data: %{
      headers: ["Status", "Count"],
      rows: Enum.zip(labels, data) |> Enum.map(fn {l, d} -> [l, d] end)
    }}
  end

  defp build_payment_chart(payments, "bar") do
    labels = ["Paid", "Pending", "Failed", "Refunded"]
    keys = ["paid", "pending", "failed", "refunded"]
    data = Enum.map(keys, fn k -> Map.get(payments, k, 0) end)

    %{
      type: "bar",
      data: %{
        labels: labels,
        datasets: [
          %{
            label: "Count",
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
      options: %{scales: %{x: %{}, y: %{}}}
    }
  end

  defp build_payment_chart(payments, _viz_type) do
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

  defp build_class_chart(classes, "table") do
    %{type: "table", data: %{
      headers: ["Class", "Bookings", "Capacity"],
      rows: Enum.map(classes, fn c -> [c.class_name, c.bookings, c.capacity] end)
    }}
  end

  defp build_class_chart(classes, viz_type) do
    labels = Enum.map(classes, & &1.class_name)

    %{
      type: viz_type,
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

  defp build_retention_chart(retention, "table") do
    %{type: "table", data: %{
      headers: ["Date", "Active", "Inactive"],
      rows: Enum.map(retention, fn r -> [format_date(r.date), r.active, r.inactive] end)
    }}
  end

  defp build_retention_chart(retention, viz_type) do
    %{
      type: viz_type,
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

  defp viz_label("line"), do: "Line Chart"
  defp viz_label("bar"), do: "Bar Chart"
  defp viz_label("doughnut"), do: "Pie Chart"
  defp viz_label("table"), do: "Table"
  defp viz_label(other), do: other

  # ---------------------------------------------------------------------------
  # Render
  # ---------------------------------------------------------------------------

  attr :id, :string, required: true
  attr :title, :string, required: true
  attr :chart_data, :map, required: true
  attr :viz_options, :list, required: true
  attr :current_viz, :string, required: true

  defp chart_card(assigns) do
    ~H"""
    <.card>
      <div class="flex items-center justify-between mb-3">
        <h3 class="text-sm font-semibold text-base-content/60">{@title}</h3>
        <form phx-change="change_viz" class="inline">
          <input type="hidden" name="chart_id" value={@id} />
          <select name="viz_type" class="select select-xs select-bordered">
            <option :for={opt <- @viz_options} value={opt} selected={opt == @current_viz}>
              {viz_label(opt)}
            </option>
          </select>
        </form>
      </div>
      <%= if @chart_data[:type] == "table" do %>
        <div class="overflow-x-auto" style="max-height: 250px;">
          <table class="table table-sm table-zebra">
            <thead><tr><th :for={h <- @chart_data.data.headers} class="text-xs">{h}</th></tr></thead>
            <tbody><tr :for={row <- @chart_data.data.rows}><td :for={cell <- row} class="text-sm">{cell}</td></tr></tbody>
          </table>
        </div>
      <% else %>
        <div id={@id} phx-hook="ChartHook" data-chart={Jason.encode!(@chart_data)}>
          <canvas class="w-full" style="height: 250px;"></canvas>
        </div>
      <% end %>
    </.card>
    """
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} unread_notification_count={assigns[:unread_notification_count] || 0}>
      <div class="space-y-6">
        <%= if @gym do %>
          <.page_header title="Dashboards" subtitle={"Performance metrics for #{@gym.name}"} back_path="/gym/dashboard" />

          <%!-- Date Range Card --%>
          <.card>
            <div class="flex flex-wrap items-center gap-3">
              <div class="flex gap-1">
                <%= for preset <- ["7d", "30d", "90d", "year"] do %>
                  <.button
                    variant={if(@preset == preset, do: "primary", else: "ghost")}
                    size="sm"
                    phx-click="select_preset"
                    phx-value-preset={preset}
                  >
                    {preset_label(preset)}
                  </.button>
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
                <.button variant="primary" size="sm" type="submit">Apply</.button>
              </form>
            </div>
          </.card>

          <%!-- Summary Cards --%>
          <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
            <.stat_card
              label="Active Members"
              value={@active_count}
              icon="hero-users-solid"
              color="primary"
              change={"#{if @active_change >= 0, do: "+", else: ""}#{@active_change}%"}
            />
            <.stat_card
              label="New Members"
              value={@new_members_total}
              icon="hero-user-plus-solid"
              color="secondary"
            />
            <.stat_card
              label="Revenue"
              value={"₹#{format_currency(@revenue_total)}"}
              icon="hero-currency-rupee-solid"
              color="success"
            />
            <.stat_card
              label="Avg Daily Attendance"
              value={@avg_daily_attendance}
              icon="hero-calendar-days-solid"
              color="warning"
            />
          </div>

          <%!-- Charts Grid --%>
          <div class="grid grid-cols-1 lg:grid-cols-2 gap-4">
            <.chart_card id="new-members-chart" title="New Members" chart_data={@new_members_chart}
              viz_options={["line", "bar", "table"]} current_viz={@viz_types["new-members-chart"]} />
            <.chart_card id="revenue-chart" title="Revenue" chart_data={@revenue_chart}
              viz_options={["line", "bar", "table"]} current_viz={@viz_types["revenue-chart"]} />
            <.chart_card id="attendance-chart" title="Attendance" chart_data={@attendance_chart}
              viz_options={["line", "bar", "table"]} current_viz={@viz_types["attendance-chart"]} />
            <.chart_card id="retention-chart" title="Member Retention" chart_data={@retention_chart}
              viz_options={["line", "bar", "table"]} current_viz={@viz_types["retention-chart"]} />
            <.chart_card
              id="subscription-chart"
              title="Subscription Status"
              chart_data={@subscription_chart}
              viz_options={["doughnut", "bar", "table"]}
              current_viz={@viz_types["subscription-chart"]}
            />
            <.chart_card
              id="payment-chart"
              title="Payment Collection"
              chart_data={@payment_chart}
              viz_options={["doughnut", "bar", "table"]}
              current_viz={@viz_types["payment-chart"]}
            />
            <.chart_card
              id="class-chart"
              title="Class Utilization"
              chart_data={@class_chart}
              viz_options={["bar", "table"]}
              current_viz={@viz_types["class-chart"]}
            />
          </div>
        <% else %>
          <.page_header title="Dashboards" subtitle="Performance metrics" back_path="/gym/dashboard" />
          <.empty_state
            icon="hero-building-office"
            title="No Gym Found"
            subtitle="Please set up your gym first to view dashboards."
          >
            <:action>
              <.button variant="primary" size="sm" navigate="/gym/setup">Set Up Gym</.button>
            </:action>
          </.empty_state>
        <% end %>
      </div>
    </Layouts.app>
    """
  end
end
