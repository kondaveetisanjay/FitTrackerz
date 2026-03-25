# Gym Operator Analytics Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `/gym/analytics` page with 8 key metrics, interactive Chart.js charts, and date range filtering for gym operators.

**Architecture:** A plain Elixir `FitTrackerz.Analytics` context module with Ecto queries against existing tables (no new tables). One `AnalyticsLive` LiveView renders summary cards and Chart.js charts via the existing `ChartHook`. Date range selection triggers re-queries.

**Tech Stack:** Ecto queries, Phoenix LiveView, Chart.js (already installed), ChartHook (already exists at `assets/js/chart_hook.js`), DaisyUI/Tailwind CSS

---

## File Structure

### New Files

| File | Responsibility |
|------|---------------|
| `lib/fit_trackerz/analytics.ex` | Analytics context — 8 Ecto query functions for gym metrics |
| `lib/fit_trackerz_web/live/gym_operator/analytics_live.ex` | Analytics page LiveView with charts and date controls |

### Modified Files

| File | Change |
|------|--------|
| `lib/fit_trackerz_web/router.ex` | Add `/gym/analytics` route |
| `lib/fit_trackerz_web/components/layouts.ex` | Add Analytics nav link in gym operator sidebar |

### Already Exists (no changes needed)

| File | What it provides |
|------|-----------------|
| `assets/js/chart_hook.js` | ChartHook — reads `data-chart` JSON, renders Chart.js |
| `assets/package.json` | chart.js ^4.5.1 already installed |

---

### Task 1: Analytics Context — Member Queries

**Files:**
- Create: `lib/fit_trackerz/analytics.ex`

- [ ] **Step 1: Create analytics module with active_members_count**

```elixir
# lib/fit_trackerz/analytics.ex
defmodule FitTrackerz.Analytics do
  import Ecto.Query

  alias FitTrackerz.Repo

  def active_members_count(gym_id) do
    from(gm in "gym_members",
      where: gm.gym_id == ^gym_id and gm.is_active == true,
      select: count(gm.id)
    )
    |> Repo.one()
  end

  def active_members_count_as_of(gym_id, date) do
    from(gm in "gym_members",
      where: gm.gym_id == ^gym_id and gm.joined_at <= ^date and gm.is_active == true,
      select: count(gm.id)
    )
    |> Repo.one()
  end

  def new_members(gym_id, start_date, end_date) do
    total =
      from(gm in "gym_members",
        where: gm.gym_id == ^gym_id and gm.joined_at >= ^start_date and gm.joined_at <= ^end_date,
        select: count(gm.id)
      )
      |> Repo.one()

    daily =
      from(gm in "gym_members",
        where: gm.gym_id == ^gym_id and gm.joined_at >= ^start_date and gm.joined_at <= ^end_date,
        group_by: gm.joined_at,
        select: {gm.joined_at, count(gm.id)},
        order_by: gm.joined_at
      )
      |> Repo.all()
      |> Enum.map(fn {date, count} -> %{date: date, value: count} end)

    %{total: total, daily: fill_missing_dates(daily, start_date, end_date)}
  end

  def member_retention(gym_id, start_date, end_date) do
    # New joins per day
    joins =
      from(gm in "gym_members",
        where: gm.gym_id == ^gym_id and gm.joined_at >= ^start_date and gm.joined_at <= ^end_date,
        group_by: gm.joined_at,
        select: {gm.joined_at, count(gm.id)},
        order_by: gm.joined_at
      )
      |> Repo.all()
      |> Map.new()

    # Total active and inactive counts as of each date in range
    dates = date_range(start_date, end_date)

    base_active =
      from(gm in "gym_members",
        where: gm.gym_id == ^gym_id and gm.joined_at < ^start_date and gm.is_active == true,
        select: count(gm.id)
      )
      |> Repo.one()

    base_inactive =
      from(gm in "gym_members",
        where: gm.gym_id == ^gym_id and gm.joined_at < ^start_date and gm.is_active == false,
        select: count(gm.id)
      )
      |> Repo.one()

    {result, _, _} =
      Enum.reduce(dates, {[], base_active, base_inactive}, fn date, {acc, active, inactive} ->
        new_joins = Map.get(joins, date, 0)
        new_active = active + new_joins
        {acc ++ [%{date: date, active: new_active, inactive: inactive}], new_active, inactive}
      end)

    result
  end

  # Date utility helpers

  defp fill_missing_dates(data, start_date, end_date) do
    data_map = Map.new(data, fn %{date: d, value: v} -> {d, v} end)

    date_range(start_date, end_date)
    |> Enum.map(fn date -> %{date: date, value: Map.get(data_map, date, 0)} end)
  end

  defp date_range(start_date, end_date) do
    Date.range(start_date, end_date) |> Enum.to_list()
  end
end
```

- [ ] **Step 2: Verify compilation**

```bash
mix compile --warnings-as-errors
```

---

### Task 2: Analytics Context — Revenue & Payment Queries

**Files:**
- Modify: `lib/fit_trackerz/analytics.ex`

- [ ] **Step 1: Add revenue and payment_collection functions**

Append to the `FitTrackerz.Analytics` module (before the private helpers):

```elixir
  def revenue(gym_id, start_date, end_date) do
    start_dt = to_start_datetime(start_date)
    end_dt = to_end_datetime(end_date)

    total =
      from(ms in "member_subscriptions",
        join: sp in "subscription_plans", on: ms.subscription_plan_id == sp.id,
        where: ms.gym_id == ^gym_id and ms.payment_status == ^"paid" and
               ms.inserted_at >= ^start_dt and ms.inserted_at <= ^end_dt,
        select: coalesce(sum(sp.price_in_paise), 0)
      )
      |> Repo.one()

    daily =
      from(ms in "member_subscriptions",
        join: sp in "subscription_plans", on: ms.subscription_plan_id == sp.id,
        where: ms.gym_id == ^gym_id and ms.payment_status == ^"paid" and
               ms.inserted_at >= ^start_dt and ms.inserted_at <= ^end_dt,
        group_by: fragment("?::date", ms.inserted_at),
        select: {fragment("?::date", ms.inserted_at), coalesce(sum(sp.price_in_paise), 0)},
        order_by: fragment("?::date", ms.inserted_at)
      )
      |> Repo.all()
      |> Enum.map(fn {date, amount} -> %{date: date, value: amount} end)

    %{total: total, daily: fill_missing_dates(daily, start_date, end_date)}
  end

  def payment_collection(gym_id, start_date, end_date) do
    start_dt = to_start_datetime(start_date)
    end_dt = to_end_datetime(end_date)

    from(ms in "member_subscriptions",
      where: ms.gym_id == ^gym_id and ms.inserted_at >= ^start_dt and ms.inserted_at <= ^end_dt,
      group_by: ms.payment_status,
      select: {ms.payment_status, count(ms.id)}
    )
    |> Repo.all()
    |> Map.new()
  end

  def subscription_breakdown(gym_id) do
    from(ms in "member_subscriptions",
      where: ms.gym_id == ^gym_id,
      group_by: ms.status,
      select: {ms.status, count(ms.id)}
    )
    |> Repo.all()
    |> Map.new()
  end

  defp to_start_datetime(date) do
    DateTime.new!(date, ~T[00:00:00], "Etc/UTC")
  end

  defp to_end_datetime(date) do
    DateTime.new!(date, ~T[23:59:59], "Etc/UTC")
  end
```

- [ ] **Step 2: Verify compilation**

```bash
mix compile --warnings-as-errors
```

---

### Task 3: Analytics Context — Attendance & Class Queries

**Files:**
- Modify: `lib/fit_trackerz/analytics.ex`

- [ ] **Step 1: Add attendance_trend and class_utilization functions**

Append to the module (before private helpers):

```elixir
  def attendance_trend(gym_id, start_date, end_date) do
    start_dt = to_start_datetime(start_date)
    end_dt = to_end_datetime(end_date)

    daily =
      from(ar in "attendance_records",
        where: ar.gym_id == ^gym_id and ar.attended_at >= ^start_dt and ar.attended_at <= ^end_dt,
        group_by: fragment("?::date", ar.attended_at),
        select: {fragment("?::date", ar.attended_at), count(ar.id)},
        order_by: fragment("?::date", ar.attended_at)
      )
      |> Repo.all()
      |> Enum.map(fn {date, count} -> %{date: date, value: count} end)

    total = Enum.reduce(daily, 0, fn %{value: v}, acc -> acc + v end)
    days = max(Date.diff(end_date, start_date) + 1, 1)
    avg_daily = Float.round(total / days, 1)

    %{total: total, avg_daily: avg_daily, daily: fill_missing_dates(daily, start_date, end_date)}
  end

  def class_utilization(gym_id, start_date, end_date) do
    start_dt = to_start_datetime(start_date)
    end_dt = to_end_datetime(end_date)

    from(sc in "scheduled_classes",
      join: cd in "class_definitions", on: sc.class_definition_id == cd.id,
      join: b in "gym_branches", on: sc.branch_id == b.id,
      left_join: cb in "class_bookings",
        on: cb.scheduled_class_id == sc.id and cb.status in [^"pending", ^"confirmed"],
      where: b.gym_id == ^gym_id and sc.scheduled_at >= ^start_dt and sc.scheduled_at <= ^end_dt,
      group_by: [cd.name, cd.max_participants],
      select: %{
        class_name: cd.name,
        bookings: count(cb.id),
        capacity: coalesce(cd.max_participants, 0)
      },
      order_by: [desc: count(cb.id)]
    )
    |> Repo.all()
  end
```

- [ ] **Step 2: Verify compilation**

```bash
mix compile --warnings-as-errors
```

---

### Task 4: Route + Sidebar Navigation

**Files:**
- Modify: `lib/fit_trackerz_web/router.ex`
- Modify: `lib/fit_trackerz_web/components/layouts.ex`

- [ ] **Step 1: Add route**

In the gym operator scope in `router.ex`, after the messages route, add:

```elixir
live "/analytics", AnalyticsLive
```

- [ ] **Step 2: Add sidebar nav link**

In `layouts.ex` gym operator sidebar, in the Operations section (after the Messages link), add:

```html
<.nav_link href="/gym/analytics" icon="hero-chart-bar-square-solid" label="Analytics" />
```

- [ ] **Step 3: Verify compilation**

```bash
mix compile
```

(Will have a warning about AnalyticsLive not existing yet — that's expected.)

---

### Task 5: AnalyticsLive — Mount, Date Range, Data Loading

**Files:**
- Create: `lib/fit_trackerz_web/live/gym_operator/analytics_live.ex`

- [ ] **Step 1: Create the AnalyticsLive module**

```elixir
# lib/fit_trackerz_web/live/gym_operator/analytics_live.ex
defmodule FitTrackerzWeb.GymOperator.AnalyticsLive do
  use FitTrackerzWeb, :live_view

  alias FitTrackerz.Analytics

  @presets %{
    "7d" => 7,
    "30d" => 30,
    "90d" => 90
  }

  @impl true
  def mount(_params, _session, socket) do
    actor = socket.assigns.current_user

    gym =
      case FitTrackerz.Gym.list_gyms_by_owner(actor.id, actor: actor) do
        {:ok, [gym | _]} -> gym
        _ -> nil
      end

    end_date = Date.utc_today()
    start_date = Date.add(end_date, -30)

    {:ok,
     socket
     |> assign(
       page_title: "Analytics",
       gym: gym,
       preset: "30d",
       start_date: start_date,
       end_date: end_date,
       custom_start: "",
       custom_end: ""
     )
     |> load_all_metrics()}
  end

  @impl true
  def handle_event("select_preset", %{"preset" => preset}, socket) do
    end_date = Date.utc_today()

    start_date =
      case preset do
        "year" -> Date.new!(end_date.year, 1, 1)
        days -> Date.add(end_date, -@presets[days])
      end

    {:noreply,
     socket
     |> assign(preset: preset, start_date: start_date, end_date: end_date)
     |> load_all_metrics()}
  end

  def handle_event("apply_custom_range", %{"start" => start_str, "end" => end_str}, socket) do
    with {:ok, start_date} <- Date.from_iso8601(start_str),
         {:ok, end_date} <- Date.from_iso8601(end_str),
         true <- Date.compare(start_date, end_date) != :gt do
      {:noreply,
       socket
       |> assign(preset: nil, start_date: start_date, end_date: end_date,
                 custom_start: start_str, custom_end: end_str)
       |> load_all_metrics()}
    else
      _ ->
        {:noreply, put_flash(socket, :error, "Invalid date range.")}
    end
  end

  defp load_all_metrics(socket) do
    gym = socket.assigns.gym

    if gym do
      gym_id = gym.id
      start_date = socket.assigns.start_date
      end_date = socket.assigns.end_date

      # Summary cards
      active_count = Analytics.active_members_count(gym_id)
      prev_start = Date.add(start_date, -Date.diff(end_date, start_date) - 1)
      prev_active = Analytics.active_members_count_as_of(gym_id, start_date)
      active_change = if prev_active > 0, do: Float.round((active_count - prev_active) / prev_active * 100, 1), else: 0.0

      new_members_data = Analytics.new_members(gym_id, start_date, end_date)
      revenue_data = Analytics.revenue(gym_id, start_date, end_date)
      attendance_data = Analytics.attendance_trend(gym_id, start_date, end_date)

      # Chart data
      sub_breakdown = Analytics.subscription_breakdown(gym_id)
      payment_data = Analytics.payment_collection(gym_id, start_date, end_date)
      class_data = Analytics.class_utilization(gym_id, start_date, end_date)
      retention_data = Analytics.member_retention(gym_id, start_date, end_date)

      socket
      |> assign(
        active_count: active_count,
        active_change: active_change,
        new_members_total: new_members_data.total,
        revenue_total: revenue_data.total,
        avg_daily_attendance: attendance_data.avg_daily,
        # Chart configs
        new_members_chart: new_members_chart(new_members_data.daily),
        revenue_chart: revenue_chart(revenue_data.daily),
        attendance_chart: attendance_chart(attendance_data.daily),
        subscription_chart: subscription_chart(sub_breakdown),
        payment_chart: payment_chart(payment_data),
        class_chart: class_chart(class_data),
        retention_chart: retention_chart(retention_data)
      )
    else
      socket
      |> assign(
        active_count: 0, active_change: 0.0, new_members_total: 0,
        revenue_total: 0, avg_daily_attendance: 0.0,
        new_members_chart: %{}, revenue_chart: %{}, attendance_chart: %{},
        subscription_chart: %{}, payment_chart: %{}, class_chart: %{},
        retention_chart: %{}
      )
    end
  end

  # Chart configuration builders

  defp new_members_chart(daily) do
    %{
      type: "line",
      data: %{
        labels: Enum.map(daily, &format_date(&1.date)),
        datasets: [%{
          label: "New Members",
          data: Enum.map(daily, & &1.value),
          borderColor: "rgb(99, 102, 241)",
          backgroundColor: "rgba(99, 102, 241, 0.1)",
          fill: true,
          tension: 0.3
        }]
      },
      options: %{scales: %{x: %{}, y: %{beginAtZero: true}}}
    }
  end

  defp revenue_chart(daily) do
    %{
      type: "bar",
      data: %{
        labels: Enum.map(daily, &format_date(&1.date)),
        datasets: [%{
          label: "Revenue (₹)",
          data: Enum.map(daily, &((&1.value || 0) / 100)),
          backgroundColor: "rgba(16, 185, 129, 0.7)",
          borderColor: "rgb(16, 185, 129)",
          borderWidth: 1
        }]
      },
      options: %{scales: %{x: %{}, y: %{beginAtZero: true}}}
    }
  end

  defp attendance_chart(daily) do
    %{
      type: "line",
      data: %{
        labels: Enum.map(daily, &format_date(&1.date)),
        datasets: [%{
          label: "Check-ins",
          data: Enum.map(daily, & &1.value),
          borderColor: "rgb(245, 158, 11)",
          backgroundColor: "rgba(245, 158, 11, 0.1)",
          fill: true,
          tension: 0.3
        }]
      },
      options: %{scales: %{x: %{}, y: %{beginAtZero: true}}}
    }
  end

  defp subscription_chart(breakdown) do
    labels = ["Active", "Cancelled", "Expired"]
    values = [
      Map.get(breakdown, "active", 0),
      Map.get(breakdown, "cancelled", 0),
      Map.get(breakdown, "expired", 0)
    ]

    %{
      type: "doughnut",
      data: %{
        labels: labels,
        datasets: [%{
          data: values,
          backgroundColor: ["rgb(16, 185, 129)", "rgb(245, 158, 11)", "rgb(239, 68, 68)"]
        }]
      },
      options: %{plugins: %{legend: %{display: true, position: "bottom"}}}
    }
  end

  defp payment_chart(data) do
    labels = ["Paid", "Pending", "Failed", "Refunded"]
    values = [
      Map.get(data, "paid", 0),
      Map.get(data, "pending", 0),
      Map.get(data, "failed", 0),
      Map.get(data, "refunded", 0)
    ]

    %{
      type: "doughnut",
      data: %{
        labels: labels,
        datasets: [%{
          data: values,
          backgroundColor: ["rgb(16, 185, 129)", "rgb(245, 158, 11)", "rgb(239, 68, 68)", "rgb(107, 114, 128)"]
        }]
      },
      options: %{plugins: %{legend: %{display: true, position: "bottom"}}}
    }
  end

  defp class_chart(data) do
    %{
      type: "bar",
      data: %{
        labels: Enum.map(data, & &1.class_name),
        datasets: [
          %{
            label: "Bookings",
            data: Enum.map(data, & &1.bookings),
            backgroundColor: "rgba(99, 102, 241, 0.7)"
          },
          %{
            label: "Capacity",
            data: Enum.map(data, & &1.capacity),
            backgroundColor: "rgba(107, 114, 128, 0.3)"
          }
        ]
      },
      options: %{
        indexAxis: "y",
        scales: %{x: %{beginAtZero: true}, y: %{}}
      }
    }
  end

  defp retention_chart(data) do
    %{
      type: "line",
      data: %{
        labels: Enum.map(data, &format_date(&1.date)),
        datasets: [
          %{
            label: "Active",
            data: Enum.map(data, & &1.active),
            borderColor: "rgb(16, 185, 129)",
            tension: 0.3
          },
          %{
            label: "Inactive",
            data: Enum.map(data, & &1.inactive),
            borderColor: "rgb(239, 68, 68)",
            tension: 0.3
          }
        ]
      },
      options: %{
        scales: %{x: %{}, y: %{beginAtZero: true}},
        plugins: %{legend: %{display: true, position: "bottom"}}
      }
    }
  end

  defp format_date(date) do
    Calendar.strftime(date, "%b %d")
  end

  defp format_currency(paise) when is_integer(paise) do
    rupees = div(paise, 100)

    rupees
    |> Integer.to_string()
    |> String.graphemes()
    |> Enum.reverse()
    |> Enum.chunk_every(3)
    |> Enum.join(",")
    |> String.reverse()
  end

  defp format_currency(_), do: "0"

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="space-y-6">
        <%!-- Header --%>
        <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
          <div class="flex items-center gap-3">
            <Layouts.back_button />
            <div>
              <h1 class="text-2xl sm:text-3xl font-brand">Analytics</h1>
              <p class="text-base-content/50 mt-0.5 text-sm">Track your gym's performance.</p>
            </div>
          </div>
        </div>

        <%!-- Date Range Controls --%>
        <div class="card bg-base-200/50 border border-base-300/50">
          <div class="card-body p-4">
            <div class="flex flex-wrap items-center gap-3">
              <span class="text-sm font-medium text-base-content/60">Period:</span>
              <div class="btn-group">
                <button
                  :for={preset <- ["7d", "30d", "90d", "year"]}
                  phx-click="select_preset"
                  phx-value-preset={preset}
                  class={"btn btn-sm #{if @preset == preset, do: "btn-primary", else: "btn-ghost"}"}
                >
                  {preset_label(preset)}
                </button>
              </div>
              <div class="divider divider-horizontal mx-0"></div>
              <form phx-submit="apply_custom_range" class="flex items-center gap-2">
                <input
                  type="date"
                  name="start"
                  value={@custom_start}
                  class="input input-sm input-bordered w-36"
                />
                <span class="text-base-content/40">to</span>
                <input
                  type="date"
                  name="end"
                  value={@custom_end}
                  class="input input-sm input-bordered w-36"
                />
                <button type="submit" class="btn btn-sm btn-outline">Apply</button>
              </form>
            </div>
          </div>
        </div>

        <%!-- Summary Cards --%>
        <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
          <div class="card bg-base-200/50 border border-base-300/50">
            <div class="card-body p-4">
              <p class="text-xs font-semibold text-base-content/40 uppercase">Active Members</p>
              <p class="text-3xl font-bold mt-1">{@active_count}</p>
              <p class={"text-xs mt-1 #{if @active_change >= 0, do: "text-success", else: "text-error"}"}>
                {if @active_change >= 0, do: "+", else: ""}{@active_change}% vs previous period
              </p>
            </div>
          </div>
          <div class="card bg-base-200/50 border border-base-300/50">
            <div class="card-body p-4">
              <p class="text-xs font-semibold text-base-content/40 uppercase">New Members</p>
              <p class="text-3xl font-bold mt-1">{@new_members_total}</p>
              <p class="text-xs mt-1 text-base-content/40">in selected period</p>
            </div>
          </div>
          <div class="card bg-base-200/50 border border-base-300/50">
            <div class="card-body p-4">
              <p class="text-xs font-semibold text-base-content/40 uppercase">Revenue</p>
              <p class="text-3xl font-bold mt-1">₹{format_currency(@revenue_total)}</p>
              <p class="text-xs mt-1 text-base-content/40">paid subscriptions</p>
            </div>
          </div>
          <div class="card bg-base-200/50 border border-base-300/50">
            <div class="card-body p-4">
              <p class="text-xs font-semibold text-base-content/40 uppercase">Avg Daily Attendance</p>
              <p class="text-3xl font-bold mt-1">{@avg_daily_attendance}</p>
              <p class="text-xs mt-1 text-base-content/40">check-ins per day</p>
            </div>
          </div>
        </div>

        <%!-- Charts Grid --%>
        <div class="grid grid-cols-1 lg:grid-cols-2 gap-4">
          <.chart_card title="New Members" chart_data={@new_members_chart} id="new-members-chart" />
          <.chart_card title="Revenue" chart_data={@revenue_chart} id="revenue-chart" />
          <.chart_card title="Attendance" chart_data={@attendance_chart} id="attendance-chart" />
          <.chart_card title="Member Retention" chart_data={@retention_chart} id="retention-chart" />
          <.chart_card title="Subscription Status" chart_data={@subscription_chart} id="subscription-chart" />
          <.chart_card title="Payment Collection" chart_data={@payment_chart} id="payment-chart" />
          <.chart_card title="Class Utilization" chart_data={@class_chart} id="class-chart" />
        </div>
      </div>
    </Layouts.app>
    """
  end

  attr :title, :string, required: true
  attr :chart_data, :map, required: true
  attr :id, :string, required: true

  defp chart_card(assigns) do
    ~H"""
    <div class="card bg-base-200/50 border border-base-300/50">
      <div class="card-body p-4">
        <h3 class="text-sm font-semibold text-base-content/60 mb-3">{@title}</h3>
        <div id={@id} phx-hook="ChartHook" data-chart={Jason.encode!(@chart_data)} phx-update="ignore">
          <canvas class="w-full" style="height: 250px;"></canvas>
        </div>
      </div>
    </div>
    """
  end

  defp preset_label("7d"), do: "7 Days"
  defp preset_label("30d"), do: "30 Days"
  defp preset_label("90d"), do: "90 Days"
  defp preset_label("year"), do: "This Year"
  defp preset_label(p), do: p
end
```

- [ ] **Step 2: Verify compilation**

```bash
mix compile --warnings-as-errors
```

---

### Task 6: Chart Update Fix — phx-update

The `ChartHook` reads `data-chart` from the container div. When LiveView re-renders on date change, we need the hook to re-render. The current implementation uses `phx-update="ignore"` which prevents LiveView from touching the DOM after mount — but we need charts to update when date range changes.

**Files:**
- Modify: `lib/fit_trackerz_web/live/gym_operator/analytics_live.ex`

- [ ] **Step 1: Remove phx-update="ignore" and use push_event instead**

Replace the `chart_card` component to use `phx-hook` with a push_event approach. Instead of relying on `data-chart` updates, push chart data via events.

Update the `chart_card` component:

```elixir
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
```

(Simply remove `phx-update="ignore"` — the existing ChartHook already handles destroy+recreate in its `updated()` callback.)

- [ ] **Step 2: Verify compilation**

```bash
mix compile --warnings-as-errors
```

---

### Task 7: Full Compilation and Smoke Test

- [ ] **Step 1: Full compilation**

```bash
mix compile --warnings-as-errors
```

- [ ] **Step 2: Start server**

```bash
mix phx.server
```

- [ ] **Step 3: Manual smoke test**

1. Sign in as gym operator
2. Navigate to `/gym/analytics`
3. Verify summary cards show data
4. Verify all 7 charts render
5. Click different preset buttons (7d, 30d, 90d, This Year) — charts should update
6. Enter custom date range and click Apply — charts should update
7. Check sidebar has "Analytics" link with chart icon
