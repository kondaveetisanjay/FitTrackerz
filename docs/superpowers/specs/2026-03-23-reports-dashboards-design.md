# Reports & Dashboard Enhancements Design

**Date:** 2026-03-23
**Status:** Approved

## Overview

Three sub-projects: (A) Rename Analytics to Dashboards with visualization type dropdown, (B) Gym Operator Reports page with 12 predefined reports, (C) Trainer Reports page with 6 self-reports. All reports feature summary tables, paginated detail tables, and CSV export.

## Sub-project A: Rename Analytics → Dashboards + Visualization Dropdown

### Rename

| From | To |
|------|----|
| Route `/gym/analytics` | `/gym/dashboards` |
| File `analytics_live.ex` | `dashboards_live.ex` |
| Module `AnalyticsLive` | `DashboardsLive` |
| Sidebar label "Analytics" | "Dashboards" |
| Page title "Analytics" | "Dashboards" |
| Router reference | Updated |

### Visualization Dropdown

Each chart card gets a small dropdown (right-aligned in card header) to switch visualization type.

**Time-series charts** (new members, revenue, attendance, retention):
- Options: Line, Bar, Table
- Default: current type (Line or Bar)

**Categorical charts** (subscription breakdown, payment collection, class utilization):
- Options: Doughnut, Bar, Table
- Default: current type (Doughnut or Bar)

**"Table" view** replaces the canvas with a data table inside the same card. Selection stored in socket assigns per chart, only that card re-renders.

## Sub-project B: Gym Operator Reports

### Routes

| Route | Module | Purpose |
|-------|--------|---------|
| `/gym/reports` | `FitTrackerzWeb.GymOperator.ReportsLive` | Report list page |
| `/gym/reports/:report_type` | `FitTrackerzWeb.GymOperator.ReportDetailLive` | Single report view |

### Sidebar Navigation

Add "Reports" link in gym operator sidebar:
```
<.nav_link href="/gym/reports" icon="hero-document-chart-bar-solid" label="Reports" />
```

### Report List Page

Grid of cards, one per predefined report. Each card shows: report name, brief description, icon. Click navigates to `/gym/reports/:report_type`.

### Report Detail Page Layout

1. **Header** — Report name, description, "Back to Reports" link
2. **Date range controls** — Preset buttons (7d, 30d, 90d, This Year) + custom date picker + Apply
3. **Export button** — "Export CSV" downloads summary + all detail rows
4. **Summary table** — Aggregated numbers in rows with labels and totals
5. **Detail table** — Paginated member/detail list:
   - Header: "Showing X to Y of Z records"
   - Table with S.No + report-specific columns + status badges
   - Footer: Rows per page selector (10/25/50) + Previous/Next pagination + page indicator

### Member Reports (8)

#### 1. active_members
- **Summary:** Active: X, Inactive: Y, Total: Z
- **Columns:** S.No, Name, Email, Phone, Status, Joined Date, Assigned Trainer

#### 2. new_members
- **Summary:** Total new in period: X
- **Columns:** S.No, Name, Email, Phone, Joined Date

#### 3. revenue
- **Summary:** Plan-wise rows: Plan Name → Amount (₹), Grand Total row
- **Columns:** S.No, Member Name, Plan Name, Amount (₹), Payment Status, Date

#### 4. attendance
- **Summary:** Total check-ins: X, Avg daily: Y
- **Columns:** S.No, Member Name, Email, Check-in Date, Time, Marked By

#### 5. subscription_status
- **Summary:** Active: X, Expired: Y, Cancelled: Z
- **Columns:** S.No, Member Name, Email, Plan, Status, Starts, Expires, Payment Status

#### 6. class_utilization
- **Summary:** Per class rows: Class Name → Bookings / Capacity
- **Columns:** S.No, Class Name, Member Name, Booking Status, Scheduled Date

#### 7. payment_collection
- **Summary:** Paid: X (₹Y), Pending: X, Failed: X, Refunded: X
- **Columns:** S.No, Member Name, Plan, Amount (₹), Payment Status, Date

#### 8. member_retention
- **Summary:** Active: X, Churned: Y, Retention Rate: Z%
- **Columns:** S.No, Name, Email, Phone, Status, Joined Date, Last Attendance

### Trainer Performance Reports (4)

#### 9. trainer_overview
- **Summary:** Per trainer rows: Trainer Name → Clients, Classes Taught, Attendance Marked
- **Columns:** S.No, Trainer Name, Email, Specializations, Active Clients, Classes Taught, Attendance Marked

#### 10. trainer_client_load
- **Summary:** Per trainer rows: Trainer Name → Active / Inactive clients
- **Columns:** S.No, Trainer Name, Client Name, Client Status, Subscription Status, Joined Date

#### 11. trainer_class_performance
- **Summary:** Per trainer rows: Trainer Name → Classes, Bookings, Avg Utilization %
- **Columns:** S.No, Trainer Name, Class Name, Date, Bookings, Capacity, Utilization %

#### 12. trainer_attendance
- **Summary:** Per trainer rows: Trainer Name → Client Check-ins, Avg per Client
- **Columns:** S.No, Trainer Name, Client Name, Check-ins in Period, Last Check-in Date

## Sub-project C: Trainer Reports

### Routes

| Route | Module | Purpose |
|-------|--------|---------|
| `/trainer/reports` | `FitTrackerzWeb.Trainer.ReportsLive` | Report list page |
| `/trainer/reports/:report_type` | `FitTrackerzWeb.Trainer.ReportDetailLive` | Single report view |

### Sidebar Navigation

Add "Reports" link in trainer sidebar under Communication section:
```
<.nav_link href="/trainer/reports" icon="hero-document-chart-bar-solid" label="Reports" />
```

### Trainer Reports (6)

All scoped to the trainer's assigned clients only.

#### 1. my_clients
- **Summary:** Active: X, Inactive: Y, Total: Z
- **Columns:** S.No, Client Name, Email, Phone, Status, Subscription, Joined Date

#### 2. client_attendance
- **Summary:** Total check-ins: X, Avg daily: Y
- **Columns:** S.No, Client Name, Check-in Date, Time, Notes

#### 3. client_subscriptions
- **Summary:** Active: X, Expired: Y, Cancelled: Z
- **Columns:** S.No, Client Name, Plan, Status, Payment, Starts, Expires

#### 4. workout_plans
- **Summary:** Total plans: X, Active: Y
- **Columns:** S.No, Client Name, Plan Name, Created Date, Exercises Count

#### 5. diet_plans
- **Summary:** Total plans: X, By type: Veg/Non-veg/Vegan counts
- **Columns:** S.No, Client Name, Plan Name, Dietary Type, Calorie Target, Created Date

#### 6. my_classes
- **Summary:** Total classes: X, Completed: Y, Total Bookings: Z
- **Columns:** S.No, Class Name, Date, Status, Bookings, Capacity

## Reports Context Module

### `FitTrackerz.Reports`

Plain Elixir module at `lib/fit_trackerz/reports.ex`. Uses Ecto queries against existing tables. Separate from the existing `FitTrackerz.Analytics` module (Analytics handles dashboard chart data, Reports handles tabular report data with pagination).

### Function Pattern

Every report function follows this interface:

```
report_name(gym_id, start_date, end_date, opts \\ [])

opts:
  - page: integer (default 1)
  - per_page: integer (default 10)
  - trainer_id: uuid (for trainer-scoped reports)

Returns:
  %{
    summary: [%{label: string, value: string | integer}],
    rows: [map],       # paginated detail rows
    total_count: integer,
    columns: [%{key: atom, label: string}]  # column definitions for rendering
  }
```

### CSV Export

Each report function also has a `report_name_csv(gym_id, start_date, end_date, opts)` variant that returns all rows (unpaginated) formatted for CSV.

CSV format:
- Summary rows at top (label, value)
- Blank separator row
- Column headers
- All detail rows

Delivered via a `CsvDownload` JS hook that receives the CSV string via `push_event` and triggers a browser download.

## File Structure

### New Files

| File | Responsibility |
|------|---------------|
| `lib/fit_trackerz/reports.ex` | Report query functions for operator + trainer |
| `lib/fit_trackerz_web/live/gym_operator/reports_live.ex` | Operator report list page |
| `lib/fit_trackerz_web/live/gym_operator/report_detail_live.ex` | Operator single report view |
| `lib/fit_trackerz_web/live/trainer/reports_live.ex` | Trainer report list page |
| `lib/fit_trackerz_web/live/trainer/report_detail_live.ex` | Trainer single report view |

### Modified Files

| File | Change |
|------|--------|
| `lib/fit_trackerz_web/live/gym_operator/analytics_live.ex` | Rename to `dashboards_live.ex`, add viz dropdown |
| `lib/fit_trackerz_web/router.ex` | Rename dashboards route, add report routes |
| `lib/fit_trackerz_web/components/layouts.ex` | Rename nav label, add Reports links |
| `assets/js/app.js` | Add CsvDownload hook |

### No New Database Tables

All queries use existing tables.

## Pagination

- Default: 10 rows per page
- Options: 10 / 25 / 50 (dropdown selector)
- Display: "Showing X to Y of Z records"
- Navigation: Previous / Next buttons + current page indicator
- Page state stored in socket assigns, changes trigger re-query with offset/limit

## Implementation Order

1. Sub-project A: Rename + visualization dropdown
2. Sub-project B: Operator Reports (context + list page + detail page + CSV)
3. Sub-project C: Trainer Reports (reuses patterns from B)
