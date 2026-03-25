# Admin Platform Dashboards & Reports Design

**Date:** 2026-03-23
**Status:** Approved

## Overview

Add dashboards and reports for the platform admin (FitTrackerz Control Panel). All queries are platform-wide (no gym_id scoping). Follows the exact same patterns as gym operator dashboards and reports.

## Admin Dashboard

### Route: `/admin/dashboards`
### Module: `FitTrackerzWeb.Admin.DashboardsLive`

### Summary Cards (4)

| Card | Value | Subtitle |
|------|-------|----------|
| Total Gyms | Count of all gyms | Verified: X, Pending: Y, Suspended: Z |
| Total Members | Count across all gyms | Active: X, Inactive: Y |
| Total Trainers | Count across all gyms | Active trainers |
| Platform Revenue | Sum of paid subscriptions (₹) | In selected period |

### Charts (6) with Visualization Dropdown

| Chart | Type | Viz Options | Data |
|-------|------|-------------|------|
| Gym Registrations | Line | Line/Bar/Table | New gyms per day in period |
| Member Growth | Line | Line/Bar/Table | New members per day across platform |
| Revenue Trend | Bar | Line/Bar/Table | Daily revenue across platform |
| Gym Status | Doughnut | Doughnut/Bar/Table | Verified/Pending/Suspended counts |
| Subscription Status | Doughnut | Doughnut/Bar/Table | Active/Expired/Cancelled platform-wide |
| Top Gyms by Members | Horizontal Bar | Doughnut/Bar/Table | Top 10 gyms by member count |

Date range controls: presets (7d, 30d, 90d, This Year) + custom date picker.

### Analytics Context Functions (added to FitTrackerz.Analytics)

- `total_gyms_count()` — count of all gyms
- `gyms_by_status()` — map of status string => count
- `total_members_count()` — count of all gym_members where is_active = true
- `total_trainers_count()` — count of all gym_trainers where is_active = true
- `platform_revenue(start_date, end_date)` — total + daily breakdown of paid subscriptions
- `platform_new_gyms(start_date, end_date)` — total + daily breakdown of new gym registrations
- `platform_member_growth(start_date, end_date)` — total + daily breakdown of new members
- `platform_subscription_breakdown()` — map of status string => count across all gyms
- `top_gyms_by_members(limit \\ 10)` — list of %{gym_name, member_count} ordered desc

All use the same schemaless Ecto query pattern with `uuid()` macro. No gym_id filter.

## Admin Reports

### Routes

| Route | Module | Purpose |
|-------|--------|---------|
| `/admin/reports` | `FitTrackerzWeb.Admin.ReportsLive` | Report list page |
| `/admin/reports/:report_type` | `FitTrackerzWeb.Admin.ReportDetailLive` | Single report view |

### 6 Predefined Reports

#### 1. gyms
- **Summary:** Verified: X, Pending: Y, Suspended: Z, Total: N
- **Columns:** S.No, Gym Name, Owner Name, Owner Email, Status, Members Count, Trainers Count, Revenue (₹), Created Date

#### 2. members
- **Summary:** Total: X, Active: Y, Inactive: Z
- **Columns:** S.No, Member Name, Email, Phone, Gym Name, Status, Subscription Status, Joined Date

#### 3. revenue
- **Summary:** Gym-wise rows: Gym Name → Total Amount (₹), Grand Total row
- **Columns:** S.No, Gym Name, Member Name, Plan Name, Amount (₹), Payment Status, Date

#### 4. subscriptions
- **Summary:** Active: X, Expired: Y, Cancelled: Z, Total: N
- **Columns:** S.No, Member Name, Gym Name, Plan Name, Status, Payment Status, Starts, Expires

#### 5. trainers
- **Summary:** Total: X, Active: Y
- **Columns:** S.No, Trainer Name, Email, Gym Name, Specializations, Active Clients, Classes Taught

#### 6. attendance
- **Summary:** Total check-ins: X, Top gym rows: Gym Name → Check-ins
- **Columns:** S.No, Gym Name, Member Name, Check-in Date, Time

### Reports Context Functions (added to FitTrackerz.Reports)

Each returns `%{summary, rows, total_count, columns}` with pagination support.

- `admin_gyms_report(start_date, end_date, opts)` + `admin_gyms_csv(...)`
- `admin_members_report(start_date, end_date, opts)` + `admin_members_csv(...)`
- `admin_revenue_report(start_date, end_date, opts)` + `admin_revenue_csv(...)`
- `admin_subscriptions_report(start_date, end_date, opts)` + `admin_subscriptions_csv(...)`
- `admin_trainers_report(start_date, end_date, opts)` + `admin_trainers_csv(...)`
- `admin_attendance_report(start_date, end_date, opts)` + `admin_attendance_csv(...)`

No gym_id parameter — all queries are platform-wide. Paginated via opts[:page] and opts[:per_page].

## File Changes

### New Files

| File | Responsibility |
|------|---------------|
| `lib/fit_trackerz_web/live/admin/dashboards_live.ex` | Admin dashboard with charts + viz dropdown |
| `lib/fit_trackerz_web/live/admin/reports_live.ex` | Admin report list page |
| `lib/fit_trackerz_web/live/admin/report_detail_live.ex` | Admin report detail with pagination + CSV |

### Modified Files

| File | Change |
|------|--------|
| `lib/fit_trackerz/analytics.ex` | Add 9 admin platform-wide query functions |
| `lib/fit_trackerz/reports.ex` | Add 6 admin report functions + 6 CSV variants |
| `lib/fit_trackerz_web/router.ex` | Add admin dashboard and report routes |
| `lib/fit_trackerz_web/components/layouts.ex` | Add Dashboards + Reports in admin sidebar |

### No New Database Tables

All queries use existing tables unscoped: `gyms`, `gym_members`, `gym_trainers`, `member_subscriptions`, `subscription_plans`, `attendance_records`, `users`, `scheduled_classes`, `class_bookings`.

## Sidebar Navigation (Admin)

Add after existing admin nav links:

```
<.nav_link href="/admin/dashboards" icon="hero-chart-bar-square-solid" label="Dashboards" />
<.nav_link href="/admin/reports" icon="hero-document-chart-bar-solid" label="Reports" />
```

## Implementation Order

1. Admin analytics context functions
2. Admin dashboard page
3. Admin report context functions
4. Admin report list + detail pages
5. Routes + sidebar nav
