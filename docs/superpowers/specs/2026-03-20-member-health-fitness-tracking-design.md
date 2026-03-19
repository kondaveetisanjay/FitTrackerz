# Member Health & Fitness Tracking — Design Spec

## Overview

Add health metrics logging, food/calorie tracking, workout completion logging with PR detection and streak tracking, and a progress dashboard with Chart.js charts to the FitTrackerz member portal.

## Decisions

- **Food logging**: Manual entry for now (food name + calories + macros). Data model supports future AI auto-calculation from ingredients.
- **Workout logging**: Per-exercise detail logging (actual sets, reps, weight) against the trainer's assigned plan.
- **Charts**: Chart.js rendered via LiveView JS hooks.
- **Architecture**: New `Health` domain for health/food resources. Extend existing `Training` domain for workout log resources.
- **Streaks & PRs**: Computed at query time, not stored.

## Data Model

### New Domain: `FitTrackerz.Health`

#### HealthMetric

Tracks member weight, BMI, and body composition over time. One entry per member per day.

| Field | Type | Notes |
|---|---|---|
| id | uuid | PK |
| member_id | uuid FK → GymMember | required |
| gym_id | uuid FK → Gym | required |
| recorded_on | :date | required, unique per member |
| weight_kg | :decimal | required |
| height_cm | :decimal | optional, carried forward from last entry |
| bmi | :decimal | auto-calculated: weight_kg / (height_cm/100)² |
| body_fat_pct | :decimal | optional |
| notes | :string | optional, max 500 chars |
| timestamps | | inserted_at, updated_at |

Identity: unique on `[member_id, recorded_on]`.

#### FoodLog

Tracks individual food items consumed. Multiple entries per day, one per food item.

| Field | Type | Notes |
|---|---|---|
| id | uuid | PK |
| member_id | uuid FK → GymMember | required |
| gym_id | uuid FK → Gym | required |
| logged_on | :date | required |
| meal_type | :atom | breakfast, lunch, dinner, snack |
| food_name | :string | required, max 255 chars |
| calories | :integer | required, > 0 |
| protein_g | :decimal | optional |
| carbs_g | :decimal | optional |
| fat_g | :decimal | optional |
| timestamps | | inserted_at, updated_at |

### Extended Domain: `FitTrackerz.Training`

#### WorkoutLog

One entry per completed workout session.

| Field | Type | Notes |
|---|---|---|
| id | uuid | PK |
| member_id | uuid FK → GymMember | required |
| gym_id | uuid FK → Gym | required |
| workout_plan_id | uuid FK → WorkoutPlan | optional (links to trainer's plan) |
| completed_on | :date | required |
| duration_minutes | :integer | optional |
| notes | :string | optional, max 500 chars |
| timestamps | | inserted_at, updated_at |

#### WorkoutLogEntry

Per-exercise details within a workout session.

| Field | Type | Notes |
|---|---|---|
| id | uuid | PK |
| workout_log_id | uuid FK → WorkoutLog | required |
| exercise_name | :string | required, copied from plan |
| planned_sets | :integer | from plan |
| planned_reps | :integer | from plan |
| actual_sets | :integer | what member did, required |
| actual_reps | :integer | what member did, required |
| weight_kg | :decimal | weight used, optional |
| order | :integer | required |
| timestamps | | inserted_at, updated_at |

## Pages

### 1. Health Log — `/member/health`

**What the member sees:**
- Form to log today's entry: date, weight (kg), height (cm, set once), body fat %, auto-calculated BMI
- History table showing past entries with date, weight, BMI, body fat, and weight change indicator (↓/↑)
- Height is carried forward from the most recent entry so the member only sets it once

### 2. Food Log — `/member/food`

**What the member sees:**
- Daily calorie summary bar: consumed vs target (from diet plan's calorie_target)
- Macro summary cards: total protein, carbs, fat for the day
- Add food form: meal type dropdown (breakfast/lunch/dinner/snack), food name, calories, protein, carbs, fat
- Today's food entries listed and grouped by meal type badge
- Date picker to view past days

### 3. Workout Completion — `/member/workout` (enhanced)

**What the member sees:**
- Current streak and best streak counters at the top
- "Log Today's Workout" section with a table pre-filled from the trainer's assigned workout plan
- Each exercise row shows: exercise name, planned sets×reps, input fields for actual sets, actual reps, weight (kg)
- Duration and notes fields
- "Complete Workout" button saves the log
- PR alert shown after saving if any exercise's weight_kg exceeds previous best
- Workout history below showing past completed sessions

### 4. Progress Dashboard — `/member/progress`

**What the member sees:**
- 4 summary stat cards: weight change (30 days), current BMI with range label, current workout streak, average daily calories vs target
- Weight trend line chart (Chart.js) — last 30 days
- Weekly calorie bar chart (Chart.js) — current week, consumed vs target line
- Recent personal records section showing exercise name, weight, and improvement amount

## Routing

New routes under the existing authenticated `/member` scope:

```
/member/health     → FitTrackerzWeb.Member.HealthLive
/member/food       → FitTrackerzWeb.Member.FoodLive
/member/progress   → FitTrackerzWeb.Member.ProgressLive
/member/workout    → FitTrackerzWeb.Member.WorkoutLive (rewrite)
```

## Authorization Policies

| Action | member | trainer | gym_operator | platform_admin |
|---|---|---|---|---|
| Create own health/food/workout logs | Yes | — | — | Yes |
| Read own logs | Yes | — | — | Yes |
| Read member's logs (their gym's members) | — | Yes | Yes | Yes |
| Update/delete own logs | Yes | — | — | Yes |

Members create and manage their own data. Trainers and gym operators get read-only access to logs belonging to their gym's members.

## Dashboard Integration

The existing member dashboard (`/member/dashboard`) stat grid gets 2 new cards:
- **Current Streak** (workout streak in days) — links to `/member/workout`
- **Today's Calories** (consumed / target) — links to `/member/food`

## Chart.js Integration

- Add `chart.js` as npm dependency in `assets/`
- Create a `ChartHook` LiveView JS hook:
  - Receives chart config (type, labels, datasets) via `data-chart` attribute or `phx-hook` dataset
  - Renders on `mounted()`, re-renders on `updated()`
- Used on the Progress Dashboard for:
  - Weight trend line chart (last 30 days of HealthMetric data)
  - Weekly calorie bar chart (FoodLog daily totals for current week)

## Streak Calculation

Computed at query time from `WorkoutLog.completed_on` dates for a member:
1. Get all distinct `completed_on` dates, sorted descending
2. Walk backwards from today counting consecutive days
3. Best streak: find longest consecutive run in the full history

## Known Limitations

- **Exercise name matching for PRs**: PR detection matches on `exercise_name` strings. If a trainer renames an exercise in a plan, historical PR comparisons for that exercise name won't carry over. Acceptable for now; a canonical exercise catalog could solve this later.
- **Calorie target may be nil**: The food log page shows consumed vs target from `DietPlan.calorie_target`, but that field is optional and the member may not have a diet plan. The UI must handle both cases gracefully (show "No target set" when nil).
- **Multiple workouts per day**: `WorkoutLog` allows multiple entries per day (morning + evening sessions). Streak calculation counts distinct `completed_on` dates, so this works correctly.

## PR Detection

After saving a WorkoutLog with entries:
1. For each exercise in the new log, query max `weight_kg` from all previous `WorkoutLogEntry` records with the same `exercise_name` for this member
2. If current `weight_kg` exceeds the previous max, flag as a new PR
3. Show PR alerts in the UI after save

## Files to Create/Modify

### New Files
| File | Purpose |
|---|---|
| `lib/fit_trackerz/health.ex` | Health Ash domain |
| `lib/fit_trackerz/health/health_metric.ex` | HealthMetric resource |
| `lib/fit_trackerz/health/food_log.ex` | FoodLog resource |
| `lib/fit_trackerz/training/workout_log.ex` | WorkoutLog resource |
| `lib/fit_trackerz/training/workout_log_entry.ex` | WorkoutLogEntry resource |
| `lib/fit_trackerz_web/live/member/health_live.ex` | Health Log page |
| `lib/fit_trackerz_web/live/member/food_live.ex` | Food Log page |
| `lib/fit_trackerz_web/live/member/progress_live.ex` | Progress Dashboard page |
| `assets/js/chart_hook.js` | Chart.js LiveView hook |
| `priv/repo/migrations/*_add_health_and_workout_tracking.exs` | Migration for all 4 tables |

### Modified Files
| File | Change |
|---|---|
| `lib/fit_trackerz/training.ex` | Register WorkoutLog and WorkoutLogEntry resources |
| `lib/fit_trackerz_web/router.ex` | Add 3 new member routes |
| `lib/fit_trackerz_web/live/member/workout_live.ex` | Rewrite with workout logging, streaks, PRs |
| `lib/fit_trackerz_web/live/member/dashboard_live.ex` | Add streak and calorie stat cards |
| `assets/js/app.js` | Register ChartHook |
| `assets/package.json` | Add chart.js dependency |
