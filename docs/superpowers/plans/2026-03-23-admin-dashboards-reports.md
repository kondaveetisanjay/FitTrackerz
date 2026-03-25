# Admin Platform Dashboards & Reports Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add platform-wide dashboards (4 summary cards + 6 charts with viz dropdown) and reports (6 predefined reports with paginated tables + CSV export) for the FitTrackerz admin panel.

**Architecture:** Extend existing `FitTrackerz.Analytics` and `FitTrackerz.Reports` modules with admin-specific platform-wide queries (no gym_id scoping). New admin LiveViews follow identical patterns to gym operator dashboards/reports.

**Tech Stack:** Ecto queries, Phoenix LiveView, Chart.js (existing ChartHook), DaisyUI/Tailwind CSS

---

## File Structure

### New Files

| File | Responsibility |
|------|---------------|
| `lib/fit_trackerz_web/live/admin/dashboards_live.ex` | Admin dashboard with 4 summary cards + 6 charts + viz dropdown |
| `lib/fit_trackerz_web/live/admin/reports_live.ex` | Admin report list page (6 cards) |
| `lib/fit_trackerz_web/live/admin/report_detail_live.ex` | Admin report detail with pagination + CSV |

### Modified Files

| File | Change |
|------|--------|
| `lib/fit_trackerz/analytics.ex` | Add 9 admin platform-wide query functions |
| `lib/fit_trackerz/reports.ex` | Add 6 admin report functions + 6 CSV variants |
| `lib/fit_trackerz_web/router.ex` | Add admin dashboards and report routes |
| `lib/fit_trackerz_web/components/layouts.ex` | Add Dashboards + Reports in admin sidebar |

---

### Task 1: Admin Analytics Functions

**Files:**
- Modify: `lib/fit_trackerz/analytics.ex`

- [ ] **Step 1: Add 9 admin query functions to the Analytics module**

Add these functions (platform-wide, no gym_id filter). Use the existing `uuid()` macro and schemaless query patterns. Place them after the existing gym-scoped functions.

```elixir
  # ===========================================================================
  # Admin / Platform-wide analytics
  # ===========================================================================

  def total_gyms_count do
    from(g in "gyms", select: count(g.id)) |> Repo.one()
  end

  def gyms_by_status do
    from(g in "gyms", group_by: g.status, select: {g.status, count(g.id)})
    |> Repo.all()
    |> Map.new()
  end

  def total_members_count do
    from(m in "gym_members", where: m.is_active == true, select: count(m.id)) |> Repo.one()
  end

  def total_trainers_count do
    from(t in "gym_trainers", where: t.is_active == true, select: count(t.id)) |> Repo.one()
  end

  def platform_revenue(start_date, end_date) do
    start_dt = to_start_datetime(start_date)
    end_dt = to_end_datetime(end_date)

    daily_data =
      from(ms in "member_subscriptions",
        join: sp in "subscription_plans", on: ms.subscription_plan_id == sp.id,
        where: ms.payment_status == ^"paid" and ms.inserted_at >= ^start_dt and ms.inserted_at <= ^end_dt,
        group_by: fragment("?::date", ms.inserted_at),
        select: {fragment("?::date", ms.inserted_at), coalesce(sum(sp.price_in_paise), 0)}
      )
      |> Repo.all()
      |> Map.new()

    daily = fill_missing_dates(daily_data, start_date, end_date)
    total = Enum.reduce(daily, 0, fn %{value: v}, acc -> acc + v end)
    %{total: total, daily: daily}
  end

  def platform_new_gyms(start_date, end_date) do
    daily_data =
      from(g in "gyms",
        where: fragment("?::date", g.inserted_at) >= ^start_date and fragment("?::date", g.inserted_at) <= ^end_date,
        group_by: fragment("?::date", g.inserted_at),
        select: {fragment("?::date", g.inserted_at), count(g.id)}
      )
      |> Repo.all()
      |> Map.new()

    daily = fill_missing_dates(daily_data, start_date, end_date)
    total = Enum.reduce(daily, 0, fn %{value: v}, acc -> acc + v end)
    %{total: total, daily: daily}
  end

  def platform_member_growth(start_date, end_date) do
    daily_data =
      from(m in "gym_members",
        where: m.joined_at >= ^start_date and m.joined_at <= ^end_date,
        group_by: m.joined_at,
        select: {m.joined_at, count(m.id)}
      )
      |> Repo.all()
      |> Map.new()

    daily = fill_missing_dates(daily_data, start_date, end_date)
    total = Enum.reduce(daily, 0, fn %{value: v}, acc -> acc + v end)
    %{total: total, daily: daily}
  end

  def platform_subscription_breakdown do
    from(ms in "member_subscriptions", group_by: ms.status, select: {ms.status, count(ms.id)})
    |> Repo.all()
    |> Map.new()
  end

  def top_gyms_by_members(limit \\ 10) do
    from(gm in "gym_members",
      join: g in "gyms", on: gm.gym_id == g.id,
      where: gm.is_active == true,
      group_by: [g.id, g.name],
      select: %{gym_name: g.name, member_count: count(gm.id)},
      order_by: [desc: count(gm.id)],
      limit: ^limit
    )
    |> Repo.all()
  end
```

Note: `platform_revenue` returns Decimal from `sum()` — the existing `to_integer` helper in `fill_missing_dates` already handles this.

- [ ] **Step 2: Verify compilation**

```bash
mix compile --warnings-as-errors
```

---

### Task 2: Admin Dashboard LiveView

**Files:**
- Create: `lib/fit_trackerz_web/live/admin/dashboards_live.ex`

- [ ] **Step 1: Create the admin dashboards page**

Module: `FitTrackerzWeb.Admin.DashboardsLive`

Follow the exact same pattern as `FitTrackerzWeb.GymOperator.DashboardsLive` (read that file first). Key differences:

**Mount:**
- No gym loading needed — admin sees platform-wide data
- Assign: page_title "Platform Dashboards", preset "30d", start/end dates, custom_start/end, viz_types

**viz_types map:**
```elixir
%{
  "gym-registrations-chart" => "line",
  "member-growth-chart" => "line",
  "revenue-chart" => "bar",
  "gym-status-chart" => "doughnut",
  "subscription-chart" => "doughnut",
  "top-gyms-chart" => "bar"
}
```

**load_all_metrics/1:**
```elixir
total_gyms = Analytics.total_gyms_count()
gyms_by_status = Analytics.gyms_by_status()
total_members = Analytics.total_members_count()
total_trainers = Analytics.total_trainers_count()
revenue = Analytics.platform_revenue(start_date, end_date)
new_gyms = Analytics.platform_new_gyms(start_date, end_date)
member_growth = Analytics.platform_member_growth(start_date, end_date)
sub_breakdown = Analytics.platform_subscription_breakdown()
top_gyms = Analytics.top_gyms_by_members(10)
```

**Summary cards (4):**
- Total Gyms: `total_gyms` + subtitle "Verified: X, Pending: Y, Suspended: Z" from gyms_by_status
- Total Members: `total_members` + "across all gyms"
- Total Trainers: `total_trainers` + "active trainers"
- Platform Revenue: `₹{format_currency(revenue.total)}` + "in selected period"

**Charts (6):**
1. `gym-registrations-chart` — "Gym Registrations" — line from new_gyms.daily — viz: line/bar/table
2. `member-growth-chart` — "Member Growth" — line from member_growth.daily — viz: line/bar/table
3. `revenue-chart` — "Revenue" — bar from revenue.daily (÷100 for rupees) — viz: line/bar/table
4. `gym-status-chart` — "Gym Status" — doughnut from gyms_by_status — viz: doughnut/bar/table
5. `subscription-chart` — "Subscriptions" — doughnut from sub_breakdown — viz: doughnut/bar/table
6. `top-gyms-chart` — "Top Gyms by Members" — horizontal bar from top_gyms — viz: doughnut/bar/table

**Events:** Same as operator: `select_preset`, `update_custom`, `apply_custom_range`, `change_viz`

**Render:** Same layout as operator dashboards: header (back button + "Platform Dashboards"), date range card, 4 summary cards in grid, 6 chart cards in 2-col grid. Use the same `chart_card` component pattern with viz dropdown.

**chart_card component:** Copy the same component (with viz_options, current_viz attrs, table/chart conditional rendering).

**Helpers:** Same: format_date, format_currency, preset_label, viz_label.

- [ ] **Step 2: Verify compilation**

```bash
mix compile --warnings-as-errors
```

---

### Task 3: Admin Report Functions

**Files:**
- Modify: `lib/fit_trackerz/reports.ex`

- [ ] **Step 1: Add 6 admin report functions + 6 CSV variants**

Add to the end of the Reports module (before private helpers). No gym_id parameter — all platform-wide. Follow the same `%{summary, rows, total_count, columns}` return pattern.

**Key query patterns (all schemaless, use uuid() macro where needed):**

1. `admin_gyms_report(start_date, end_date, opts)` — Query `gyms` JOIN `users` (owner). Left join subqueries for member_count, trainer_count, revenue. Columns: gym_name, owner_name, owner_email, status, members_count, trainers_count, revenue, created_date.

2. `admin_members_report(start_date, end_date, opts)` — Query `gym_members` JOIN `users` JOIN `gyms`. Left join latest subscription for subscription_status. Columns: member_name, email, phone, gym_name, status, subscription_status, joined_at.

3. `admin_revenue_report(start_date, end_date, opts)` — Query `member_subscriptions` JOIN `subscription_plans` JOIN `gym_members` JOIN `users` JOIN `gyms`. Filter: payment_status = "paid", inserted_at in range. Summary: gym-wise totals + grand total. Columns: gym_name, member_name, plan_name, amount, payment_status, date.

4. `admin_subscriptions_report(start_date, end_date, opts)` — Query `member_subscriptions` JOIN `gym_members` JOIN `users` JOIN `gyms` JOIN `subscription_plans`. Columns: member_name, gym_name, plan_name, status, payment_status, starts_at, ends_at.

5. `admin_trainers_report(start_date, end_date, opts)` — Query `gym_trainers` JOIN `users` JOIN `gyms`. Subquery counts for active_clients and classes_taught. Columns: trainer_name, email, gym_name, specializations, active_clients, classes_taught.

6. `admin_attendance_report(start_date, end_date, opts)` — Query `attendance_records` JOIN `gym_members` JOIN `users` JOIN `gyms`. Filter: attended_at in range. Summary: total + gym-wise breakdown. Columns: gym_name, member_name, attended_date, attended_time.

Each has a `*_csv` variant that returns unpaginated CSV string using the existing `to_csv/3` helper.

- [ ] **Step 2: Verify compilation**

```bash
mix compile --warnings-as-errors
```

---

### Task 4: Admin Report List Page

**Files:**
- Create: `lib/fit_trackerz_web/live/admin/reports_live.ex`

- [ ] **Step 1: Create the admin report list page**

Module: `FitTrackerzWeb.Admin.ReportsLive`

Same pattern as operator `ReportsLive`. Single section with 6 report cards.

```elixir
@reports [
  %{type: "gyms", name: "Gyms", desc: "All registered gyms with status and metrics", icon: "hero-building-office-2-solid"},
  %{type: "members", name: "Members", desc: "All members across the platform", icon: "hero-user-group-solid"},
  %{type: "revenue", name: "Revenue", desc: "Platform-wide revenue by gym", icon: "hero-currency-rupee-solid"},
  %{type: "subscriptions", name: "Subscriptions", desc: "All subscriptions platform-wide", icon: "hero-credit-card-solid"},
  %{type: "trainers", name: "Trainers", desc: "All trainers across the platform", icon: "hero-academic-cap-solid"},
  %{type: "attendance", name: "Attendance", desc: "Platform-wide attendance records", icon: "hero-clipboard-document-check-solid"}
]
```

Cards link to `/admin/reports/:type`. Grid layout: 3 cols desktop, 2 tablet, 1 mobile.

Read the operator `reports_live.ex` first and follow the same pattern exactly.

- [ ] **Step 2: Verify compilation**

```bash
mix compile --warnings-as-errors
```

---

### Task 5: Admin Report Detail Page

**Files:**
- Create: `lib/fit_trackerz_web/live/admin/report_detail_live.ex`

- [ ] **Step 1: Create the admin report detail page**

Module: `FitTrackerzWeb.Admin.ReportDetailLive`

Same pattern as operator `ReportDetailLive`. Key differences:
- No gym loading — admin sees everything
- Report dispatcher calls `FitTrackerz.Reports.admin_*` functions (no gym_id param):

```elixir
defp fetch_report("gyms", s, e, opts), do: FitTrackerz.Reports.admin_gyms_report(s, e, opts)
defp fetch_report("members", s, e, opts), do: FitTrackerz.Reports.admin_members_report(s, e, opts)
defp fetch_report("revenue", s, e, opts), do: FitTrackerz.Reports.admin_revenue_report(s, e, opts)
defp fetch_report("subscriptions", s, e, opts), do: FitTrackerz.Reports.admin_subscriptions_report(s, e, opts)
defp fetch_report("trainers", s, e, opts), do: FitTrackerz.Reports.admin_trainers_report(s, e, opts)
defp fetch_report("attendance", s, e, opts), do: FitTrackerz.Reports.admin_attendance_report(s, e, opts)

defp fetch_csv("gyms", s, e, opts), do: FitTrackerz.Reports.admin_gyms_csv(s, e, opts)
# ... etc for all 6
```

```elixir
@report_names %{
  "gyms" => "Gyms",
  "members" => "Members",
  "revenue" => "Revenue",
  "subscriptions" => "Subscriptions",
  "trainers" => "Trainers",
  "attendance" => "Attendance"
}
```

- `load_report_data/1` — no gym_id, passes start_date, end_date, page, per_page directly
- Back link goes to `/admin/reports`
- Same render template: summary table + paginated detail table + CSV export + status badges

Read the operator `report_detail_live.ex` first and follow the pattern.

- [ ] **Step 2: Verify compilation**

```bash
mix compile --warnings-as-errors
```

---

### Task 6: Routes + Sidebar Navigation

**Files:**
- Modify: `lib/fit_trackerz_web/router.ex`
- Modify: `lib/fit_trackerz_web/components/layouts.ex`

- [ ] **Step 1: Add routes**

In the admin scope (after `live "/gyms", GymsLive`), add:
```elixir
live "/dashboards", DashboardsLive
live "/reports", ReportsLive
live "/reports/:report_type", ReportDetailLive
```

- [ ] **Step 2: Add sidebar nav links**

In `layouts.ex`, admin sidebar (`sidebar_nav(%{role: :platform_admin})`), add after the Gyms link:

```html
<div class="divider my-3"></div>
<p class="px-3 text-xs font-semibold text-base-content/40 uppercase tracking-wider mb-2">
  Analytics
</p>
<.nav_link href="/admin/dashboards" icon="hero-chart-bar-square-solid" label="Dashboards" />
<.nav_link href="/admin/reports" icon="hero-document-chart-bar-solid" label="Reports" />
```

- [ ] **Step 3: Verify compilation**

```bash
mix compile --warnings-as-errors
```

---

### Task 7: Full Compilation + Smoke Test

- [ ] **Step 1: Full compilation**

```bash
mix compile --warnings-as-errors
```

- [ ] **Step 2: Smoke test**

1. Sign in as admin (admin@fittrackerz.com)
2. Verify sidebar shows "Dashboards" and "Reports" links
3. Navigate to `/admin/dashboards` — verify 4 summary cards + 6 charts
4. Test viz dropdown (switch chart types)
5. Test date range presets and custom range
6. Navigate to `/admin/reports` — verify 6 report cards
7. Click "Gyms" report — verify summary + paginated table
8. Test pagination (change page, change per_page)
9. Test CSV export
