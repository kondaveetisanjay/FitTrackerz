# Gym Operator Analytics & Reporting Design

**Date:** 2026-03-23
**Status:** Approved

## Overview

Add a dedicated `/gym/analytics` page for gym operators with 8 key metrics, interactive Chart.js charts, and date range filtering. All data is queried in real-time from existing tables using Ecto.

## Requirements

- Dedicated analytics page (separate from dashboard)
- 8 metrics: active members, new members, revenue, attendance, subscription breakdown, class utilization, payment collection, member retention
- Date range filtering: presets (7d, 30d, 90d, This Year) + custom date picker
- Interactive charts via Chart.js (client-side)
- Real-time Ecto queries against existing tables (no new tables)

## Analytics Context Module

### `FitTrackerz.Analytics`

Plain Elixir module at `lib/fit_trackerz/analytics.ex`. Not an Ash domain — Ecto queries are better suited for aggregation analytics. All functions take `gym_id`, and date range where applicable.

### Query Functions

| Function | Returns | Source Tables |
|----------|---------|---------------|
| `active_members_count(gym_id)` | Integer | `gym_members` where is_active = true |
| `new_members(gym_id, start, end)` | Integer total + list of %{date, value} daily breakdown | `gym_members` where joined_at in range |
| `revenue(gym_id, start, end)` | Total integer (paise) + list of %{date, value} daily breakdown | `member_subscriptions` where payment_status = :paid and inserted_at in range |
| `attendance_trend(gym_id, start, end)` | List of %{date, value} daily check-in counts | `attendance_records` where attended_at in range |
| `subscription_breakdown(gym_id)` | Map of status atom to count | `member_subscriptions` grouped by status |
| `class_utilization(gym_id, start, end)` | List of %{class_name, bookings, capacity} | `scheduled_classes` + `class_bookings` + `class_definitions` |
| `payment_collection(gym_id, start, end)` | Map of payment_status atom to count | `member_subscriptions` grouped by payment_status, filtered by date range |
| `member_retention(gym_id, start, end)` | List of %{date, active, churned} | `gym_members` tracking active vs inactive over time |

Each trend function returns date-keyed data suitable for chart rendering. Missing dates in the range are filled with zero values.

## Chart.js Integration

### Dependency

Install via npm: `chart.js` package in `assets/`.

### ChartHook (LiveView JS Hook)

Single reusable hook in `assets/js/app.js`:
- Reads chart configuration from `data-chart` attribute (JSON string)
- Creates Chart.js instance on `mounted()`
- Destroys and recreates chart on `updated()` when data changes
- Cleans up on `destroyed()`

### Chart Types by Metric

| Metric | Chart Type |
|--------|-----------|
| New members trend | Line chart |
| Revenue trend | Bar chart |
| Attendance trend | Line chart |
| Subscription breakdown | Doughnut chart |
| Class utilization | Horizontal bar chart |
| Payment collection | Doughnut chart |
| Member retention | Line chart (dual series: active vs churned) |

### Data Flow

1. User selects date range (preset or custom)
2. LiveView handle_event triggers analytics context queries
3. Results assigned as JSON-serializable maps
4. Template renders `<canvas phx-hook="ChartHook" data-chart={Jason.encode!(config)}>` elements
5. Hook creates/updates Chart.js instances

## AnalyticsLive Page

### Route

`/gym/analytics` — added to gym operator scope in router.

### Module

`FitTrackerzWeb.GymOperator.AnalyticsLive`

### Page Layout

**Top section:**
- Page title "Analytics" with back button
- Date range controls: preset buttons (7 Days, 30 Days, 90 Days, This Year) + custom start/end date inputs
- Active preset highlighted

**Summary cards row (4 cards):**
- Total Active Members — current count with percentage change vs previous equivalent period
- New Members — count in selected period
- Revenue — formatted in rupees (price_in_paise / 100)
- Avg Daily Attendance — average check-ins per day in period

**Charts grid (2 columns desktop, 1 column mobile):**

| Left Column | Right Column |
|------------|-------------|
| New Members Trend (line) | Revenue Trend (bar) |
| Attendance Trend (line) | Member Retention (line, dual) |
| Subscription Breakdown (doughnut) | Payment Collection (doughnut) |
| Class Utilization (horizontal bar) | |

Each chart in a DaisyUI card with title header.

### Mount Behavior

- Load gym via `list_gyms_by_owner`
- Default to 30-day range
- Query all 8 metrics
- Assign chart data

### Events

- `select_preset` — switch to preset range (7d/30d/90d/year), re-query all metrics
- `apply_custom_range` — apply custom start/end dates, re-query all metrics

## File Changes

### New Files

| File | Purpose |
|------|---------|
| `lib/fit_trackerz/analytics.ex` | Analytics context with 8 Ecto query functions |
| `lib/fit_trackerz_web/live/gym_operator/analytics_live.ex` | Analytics page LiveView |

### Modified Files

| File | Change |
|------|--------|
| `assets/js/app.js` | Add ChartHook |
| `assets/package.json` | Add chart.js dependency |
| `lib/fit_trackerz_web/router.ex` | Add `/gym/analytics` route in gym operator scope |
| `lib/fit_trackerz_web/components/layouts.ex` | Add Analytics nav link in gym operator sidebar |

### No New Database Tables

All queries use existing tables: `gym_members`, `member_subscriptions`, `attendance_records`, `scheduled_classes`, `class_bookings`, `class_definitions`.

## Sidebar Navigation

Add in gym operator sidebar under Operations section:
```
<.nav_link href="/gym/analytics" icon="hero-chart-bar-square-solid" label="Analytics" />
```

## Future Considerations (Not in scope)

- Platform admin analytics dashboard
- Export to CSV/PDF
- Pre-computed daily snapshots for performance at scale
- Comparison periods (this month vs last month overlay)
- Branch-level filtering
