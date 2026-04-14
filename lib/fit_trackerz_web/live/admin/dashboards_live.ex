defmodule FitTrackerzWeb.Admin.DashboardsLive do
  use FitTrackerzWeb, :live_view

  alias FitTrackerz.Analytics

  @impl true
  def mount(_params, _session, socket) do
    today = Date.utc_today()
    start_date = Date.add(today, -30)

    socket =
      socket
      |> assign(
        page_title: "Platform Dashboards",
        preset: "30d",
        start_date: start_date,
        end_date: today,
        custom_start: "",
        custom_end: "",
        viz_types: %{
          "gym-registrations-chart" => "line",
          "member-growth-chart" => "line",
          "revenue-chart" => "bar",
          "gym-status-chart" => "doughnut",
          "subscription-chart" => "doughnut",
          "top-gyms-chart" => "bar"
        }
      )
      |> load_all_metrics()

    {:ok, socket}
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
    start_date = socket.assigns.start_date
    end_date = socket.assigns.end_date
    viz_types = socket.assigns.viz_types

    total_gyms = Analytics.total_gyms_count()
    gyms_by_status = Analytics.gyms_by_status()
    total_members = Analytics.total_members_count()
    total_trainers = Analytics.total_trainers_count()
    revenue = Analytics.platform_revenue(start_date, end_date)
    new_gyms = Analytics.platform_new_gyms(start_date, end_date)
    member_growth = Analytics.platform_member_growth(start_date, end_date)
    sub_breakdown = Analytics.platform_subscription_breakdown()
    top_gyms = Analytics.top_gyms_by_members(10)

    socket
    |> assign(
      total_gyms: total_gyms,
      gyms_by_status: gyms_by_status,
      total_members: total_members,
      total_trainers: total_trainers,
      revenue_total: revenue.total,
      gym_registrations_chart: build_gym_registrations_chart(new_gyms.daily, viz_types["gym-registrations-chart"]),
      member_growth_chart: build_member_growth_chart(member_growth.daily, viz_types["member-growth-chart"]),
      revenue_chart: build_revenue_chart(revenue.daily, viz_types["revenue-chart"]),
      gym_status_chart: build_gym_status_chart(gyms_by_status, viz_types["gym-status-chart"]),
      subscription_chart: build_subscription_chart(sub_breakdown, viz_types["subscription-chart"]),
      top_gyms_chart: build_top_gyms_chart(top_gyms, viz_types["top-gyms-chart"])
    )
  end

  # ---------------------------------------------------------------------------
  # Chart builders
  # ---------------------------------------------------------------------------

  defp build_gym_registrations_chart(daily, "table") do
    %{type: "table", data: %{
      headers: ["Date", "New Gyms"],
      rows: Enum.map(daily, fn d -> [format_date(d.date), d.value] end)
    }}
  end

  defp build_gym_registrations_chart(daily, viz_type) do
    %{
      type: viz_type,
      data: %{
        labels: Enum.map(daily, &format_date(&1.date)),
        datasets: [
          %{
            label: "New Gyms",
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

  defp build_member_growth_chart(daily, "table") do
    %{type: "table", data: %{
      headers: ["Date", "Members"],
      rows: Enum.map(daily, fn d -> [format_date(d.date), d.value] end)
    }}
  end

  defp build_member_growth_chart(daily, viz_type) do
    %{
      type: viz_type,
      data: %{
        labels: Enum.map(daily, &format_date(&1.date)),
        datasets: [
          %{
            label: "Members",
            data: Enum.map(daily, & &1.value),
            borderColor: "rgb(34, 197, 94)",
            backgroundColor: "rgba(34, 197, 94, 0.1)",
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

  defp build_gym_status_chart(gyms_by_status, "table") do
    labels = ["Verified", "Pending", "Suspended"]
    keys = ["verified", "pending_verification", "suspended"]
    data = Enum.map(keys, fn k -> Map.get(gyms_by_status, k, 0) end)
    %{type: "table", data: %{
      headers: ["Status", "Count"],
      rows: Enum.zip(labels, data) |> Enum.map(fn {l, d} -> [l, d] end)
    }}
  end

  defp build_gym_status_chart(gyms_by_status, "bar") do
    labels = ["Verified", "Pending", "Suspended"]
    keys = ["verified", "pending_verification", "suspended"]
    data = Enum.map(keys, fn k -> Map.get(gyms_by_status, k, 0) end)

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

  defp build_gym_status_chart(gyms_by_status, _viz_type) do
    labels = ["Verified", "Pending", "Suspended"]
    keys = ["verified", "pending_verification", "suspended"]
    data = Enum.map(keys, fn k -> Map.get(gyms_by_status, k, 0) end)

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

  defp build_subscription_chart(sub_breakdown, "table") do
    labels = ["Active", "Cancelled", "Expired"]
    keys = ["active", "cancelled", "expired"]
    data = Enum.map(keys, fn k -> Map.get(sub_breakdown, k, 0) end)
    %{type: "table", data: %{
      headers: ["Status", "Count"],
      rows: Enum.zip(labels, data) |> Enum.map(fn {l, d} -> [l, d] end)
    }}
  end

  defp build_subscription_chart(sub_breakdown, "bar") do
    labels = ["Active", "Cancelled", "Expired"]
    keys = ["active", "cancelled", "expired"]
    data = Enum.map(keys, fn k -> Map.get(sub_breakdown, k, 0) end)

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

  defp build_subscription_chart(sub_breakdown, _viz_type) do
    labels = ["Active", "Cancelled", "Expired"]
    keys = ["active", "cancelled", "expired"]
    data = Enum.map(keys, fn k -> Map.get(sub_breakdown, k, 0) end)

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

  defp build_top_gyms_chart(top_gyms, "table") do
    %{type: "table", data: %{
      headers: ["Gym", "Members"],
      rows: Enum.map(top_gyms, fn g -> [g.gym_name, g.member_count] end)
    }}
  end

  defp build_top_gyms_chart(top_gyms, "doughnut") do
    labels = Enum.map(top_gyms, & &1.gym_name)
    data = Enum.map(top_gyms, & &1.member_count)

    %{
      type: "doughnut",
      data: %{
        labels: labels,
        datasets: [
          %{
            data: data,
            backgroundColor: [
              "rgb(99, 102, 241)",
              "rgb(34, 197, 94)",
              "rgb(245, 158, 11)",
              "rgb(239, 68, 68)",
              "rgb(156, 163, 175)",
              "rgb(168, 85, 247)",
              "rgb(236, 72, 153)",
              "rgb(14, 165, 233)",
              "rgb(20, 184, 166)",
              "rgb(251, 146, 60)"
            ]
          }
        ]
      },
      options: %{
        plugins: %{legend: %{display: true, position: "bottom"}}
      }
    }
  end

  defp build_top_gyms_chart(top_gyms, _viz_type) do
    labels = Enum.map(top_gyms, & &1.gym_name)
    data = Enum.map(top_gyms, & &1.member_count)

    %{
      type: "bar",
      data: %{
        labels: labels,
        datasets: [
          %{
            label: "Members",
            data: data,
            backgroundColor: "rgba(99, 102, 241, 0.7)",
            borderColor: "rgb(99, 102, 241)",
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
    <div class="card bg-base-200/50 border border-base-300/50">
      <div class="card-body p-4">
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
      </div>
    </div>
    """
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <.page_header title="Platform Dashboards" subtitle="Platform-wide performance metrics" back_path="/admin/dashboard" />

      <%!-- Date Range Controls --%>
      <.section>
        <.card padded={false}>
          <div class="p-4">
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
                <.button type="submit" variant="primary" size="sm">Apply</.button>
              </form>
            </div>
          </div>
        </.card>
      </.section>

      <%!-- Summary Stat Cards --%>
      <div class="grid grid-cols-2 lg:grid-cols-4 gap-4 sm:gap-6 mb-8">
        <.stat_card label="Total Gyms" value={@total_gyms} icon="hero-building-office-2-solid" color="primary" />
        <.stat_card label="Total Members" value={@total_members} icon="hero-user-group-solid" color="secondary" />
        <.stat_card label="Total Trainers" value={@total_trainers} icon="hero-academic-cap-solid" color="accent" />
        <.stat_card label={"Revenue (\u20B9)"} value={format_currency(@revenue_total)} icon="hero-currency-rupee-solid" color="success" />
      </div>

      <%!-- Charts Grid --%>
      <.section title="Analytics">
        <div class="grid grid-cols-1 lg:grid-cols-2 gap-4">
          <.chart_card id="gym-registrations-chart" title="Gym Registrations" chart_data={@gym_registrations_chart}
            viz_options={["line", "bar", "table"]} current_viz={@viz_types["gym-registrations-chart"]} />
          <.chart_card id="member-growth-chart" title="Member Growth" chart_data={@member_growth_chart}
            viz_options={["line", "bar", "table"]} current_viz={@viz_types["member-growth-chart"]} />
          <.chart_card id="revenue-chart" title="Revenue" chart_data={@revenue_chart}
            viz_options={["line", "bar", "table"]} current_viz={@viz_types["revenue-chart"]} />
          <.chart_card id="gym-status-chart" title="Gym Status" chart_data={@gym_status_chart}
            viz_options={["doughnut", "bar", "table"]} current_viz={@viz_types["gym-status-chart"]} />
          <.chart_card id="subscription-chart" title="Subscriptions" chart_data={@subscription_chart}
            viz_options={["doughnut", "bar", "table"]} current_viz={@viz_types["subscription-chart"]} />
          <.chart_card id="top-gyms-chart" title="Top Gyms by Members" chart_data={@top_gyms_chart}
            viz_options={["bar", "doughnut", "table"]} current_viz={@viz_types["top-gyms-chart"]} />
        </div>
      </.section>
    </Layouts.app>
    """
  end
end
