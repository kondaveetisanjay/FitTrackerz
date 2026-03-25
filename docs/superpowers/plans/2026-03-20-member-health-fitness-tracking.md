# Member Health & Fitness Tracking Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add health metrics logging, food/calorie tracking, workout completion logging with streak/PR tracking, and a progress dashboard with Chart.js charts to the member portal.

**Architecture:** New `Health` Ash domain with `HealthMetric` and `FoodLog` resources. Extend existing `Training` domain with `WorkoutLog` and `WorkoutLogEntry` resources. Four new/enhanced LiveView pages. Chart.js via LiveView JS hook.

**Tech Stack:** Elixir/Phoenix, Ash Framework, PostgreSQL, LiveView, DaisyUI/Tailwind, Chart.js

**Spec:** `docs/superpowers/specs/2026-03-20-member-health-fitness-tracking-design.md`

---

## File Structure

### New Files

| File | Responsibility |
|---|---|
| `lib/fit_trackerz/health.ex` | Health Ash domain definition |
| `lib/fit_trackerz/health/health_metric.ex` | HealthMetric resource (weight, BMI, body fat) |
| `lib/fit_trackerz/health/food_log.ex` | FoodLog resource (meal entries, calories, macros) |
| `lib/fit_trackerz/training/workout_log.ex` | WorkoutLog resource (completed workout sessions) |
| `lib/fit_trackerz/training/workout_log_entry.ex` | WorkoutLogEntry resource (per-exercise details) |
| `lib/fit_trackerz_web/live/member/health_live.ex` | Health Log page |
| `lib/fit_trackerz_web/live/member/food_live.ex` | Food Log page |
| `lib/fit_trackerz_web/live/member/progress_live.ex` | Progress Dashboard page |
| `assets/js/chart_hook.js` | Chart.js LiveView hook |
| `priv/repo/migrations/*_add_health_and_workout_tracking.exs` | Migration for 4 new tables |

### Modified Files

| File | Change |
|---|---|
| `config/config.exs` | Add `FitTrackerz.Health` to `ash_domains` |
| `lib/fit_trackerz/training.ex` | Register WorkoutLog and WorkoutLogEntry |
| `lib/fit_trackerz_web/router.ex` | Add `/member/health`, `/member/food`, `/member/progress` routes |
| `lib/fit_trackerz_web/live/member/workout_live.ex` | Rewrite with workout logging, streaks, PRs |
| `lib/fit_trackerz_web/live/member/dashboard_live.ex` | Add streak and calorie stat cards |
| `assets/js/app.js` | Import and register ChartHook |

---

### Task 1: Health Domain & HealthMetric Resource

**Files:**
- Create: `lib/fit_trackerz/health.ex`
- Create: `lib/fit_trackerz/health/health_metric.ex`
- Modify: `config/config.exs`

- [ ] **Step 1: Create the HealthMetric resource**

Create `lib/fit_trackerz/health/health_metric.ex`:

```elixir
defmodule FitTrackerz.Health.HealthMetric do
  use Ash.Resource,
    domain: FitTrackerz.Health,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("health_metrics")
    repo(FitTrackerz.Repo)

    references do
      reference :member, on_delete: :delete
      reference :gym, on_delete: :delete
    end

    custom_indexes do
      index([:member_id])
      index([:gym_id])
      index([:member_id, :recorded_on], unique: true)
    end
  end

  policies do
    bypass actor_attribute_equals(:is_system_actor, true) do
      authorize_if always()
    end

    bypass actor_attribute_equals(:role, :platform_admin) do
      authorize_if always()
    end

    policy action_type(:read) do
      authorize_if always()
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if actor_attribute_equals(:role, :member)
    end
  end

  actions do
    defaults([:read, :destroy])

    read :list_by_member do
      argument :member_ids, {:array, :uuid}, allow_nil?: false
      filter expr(member_id in ^arg(:member_ids))
      prepare build(sort: [recorded_on: :desc])
    end

    read :latest_by_member do
      argument :member_ids, {:array, :uuid}, allow_nil?: false
      filter expr(member_id in ^arg(:member_ids))
      prepare build(sort: [recorded_on: :desc], limit: 1)
    end

    create :create do
      accept([:member_id, :gym_id, :recorded_on, :weight_kg, :height_cm, :body_fat_pct, :notes])

      change fn changeset, _context ->
        weight = Ash.Changeset.get_attribute(changeset, :weight_kg)
        height = Ash.Changeset.get_attribute(changeset, :height_cm)

        if weight && height && height > 0 do
          bmi = Decimal.round(Decimal.div(weight, Decimal.mult(Decimal.div(height, 100), Decimal.div(height, 100))), 1)
          Ash.Changeset.force_change_attribute(changeset, :bmi, bmi)
        else
          changeset
        end
      end
    end

    update :update do
      accept([:weight_kg, :height_cm, :body_fat_pct, :notes])

      change fn changeset, _context ->
        weight = Ash.Changeset.get_attribute(changeset, :weight_kg)
        height = Ash.Changeset.get_attribute(changeset, :height_cm)

        if weight && height && height > 0 do
          bmi = Decimal.round(Decimal.div(weight, Decimal.mult(Decimal.div(height, 100), Decimal.div(height, 100))), 1)
          Ash.Changeset.force_change_attribute(changeset, :bmi, bmi)
        else
          changeset
        end
      end
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute :recorded_on, :date do
      allow_nil?(false)
    end

    attribute :weight_kg, :decimal do
      allow_nil?(false)
      constraints(min: 1)
    end

    attribute :height_cm, :decimal do
      constraints(min: 50, max: 300)
    end

    attribute :bmi, :decimal

    attribute :body_fat_pct, :decimal do
      constraints(min: 1, max: 70)
    end

    attribute :notes, :string do
      constraints(max_length: 500)
    end

    timestamps()
  end

  relationships do
    belongs_to :member, FitTrackerz.Gym.GymMember do
      allow_nil?(false)
    end

    belongs_to :gym, FitTrackerz.Gym.Gym do
      allow_nil?(false)
    end
  end

  identities do
    identity(:unique_daily_metric, [:member_id, :recorded_on])
  end
end
```

- [ ] **Step 2: Create the Health domain**

Create `lib/fit_trackerz/health.ex`:

```elixir
defmodule FitTrackerz.Health do
  use Ash.Domain

  authorization do
    authorize :by_default
    require_actor? true
  end

  resources do
    resource FitTrackerz.Health.HealthMetric do
      define :list_health_metrics, args: [:member_ids], action: :list_by_member
      define :get_latest_health_metric, args: [:member_ids], action: :latest_by_member
      define :create_health_metric, action: :create
      define :update_health_metric, action: :update
      define :destroy_health_metric, action: :destroy
    end
  end
end
```

- [ ] **Step 3: Register domain in config**

In `config/config.exs`, add `FitTrackerz.Health` to the `ash_domains` list:

```elixir
  ash_domains: [
    FitTrackerz.Accounts,
    FitTrackerz.Gym,
    FitTrackerz.Billing,
    FitTrackerz.Training,
    FitTrackerz.Scheduling,
    FitTrackerz.Health
  ]
```

- [ ] **Step 4: Compile and verify**

Run: `mix compile`
Expected: No errors

- [ ] **Step 5: Commit**

```bash
git add lib/fit_trackerz/health.ex lib/fit_trackerz/health/health_metric.ex config/config.exs
git commit -m "feat: add Health domain with HealthMetric resource"
```

---

### Task 2: FoodLog Resource

**Files:**
- Create: `lib/fit_trackerz/health/food_log.ex`
- Modify: `lib/fit_trackerz/health.ex`

- [ ] **Step 1: Create the FoodLog resource**

Create `lib/fit_trackerz/health/food_log.ex`:

```elixir
defmodule FitTrackerz.Health.FoodLog do
  use Ash.Resource,
    domain: FitTrackerz.Health,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("food_logs")
    repo(FitTrackerz.Repo)

    references do
      reference :member, on_delete: :delete
      reference :gym, on_delete: :delete
    end

    custom_indexes do
      index([:member_id])
      index([:gym_id])
      index([:member_id, :logged_on])
    end
  end

  policies do
    bypass actor_attribute_equals(:is_system_actor, true) do
      authorize_if always()
    end

    bypass actor_attribute_equals(:role, :platform_admin) do
      authorize_if always()
    end

    policy action_type(:read) do
      authorize_if always()
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if actor_attribute_equals(:role, :member)
    end
  end

  actions do
    defaults([:read, :destroy])

    read :list_by_member_and_date do
      argument :member_ids, {:array, :uuid}, allow_nil?: false
      argument :date, :date, allow_nil?: false
      filter expr(member_id in ^arg(:member_ids) and logged_on == ^arg(:date))
      prepare build(sort: [inserted_at: :asc])
    end

    read :list_by_member do
      argument :member_ids, {:array, :uuid}, allow_nil?: false
      filter expr(member_id in ^arg(:member_ids))
      prepare build(sort: [logged_on: :desc, inserted_at: :asc])
    end

    read :list_by_member_date_range do
      argument :member_ids, {:array, :uuid}, allow_nil?: false
      argument :start_date, :date, allow_nil?: false
      argument :end_date, :date, allow_nil?: false
      filter expr(member_id in ^arg(:member_ids) and logged_on >= ^arg(:start_date) and logged_on <= ^arg(:end_date))
      prepare build(sort: [logged_on: :asc])
    end

    create :create do
      accept([:member_id, :gym_id, :logged_on, :meal_type, :food_name, :calories, :protein_g, :carbs_g, :fat_g])

      validate string_length(:food_name, min: 1, max: 255)
      validate numericality(:calories, greater_than: 0)
    end

    update :update do
      accept([:meal_type, :food_name, :calories, :protein_g, :carbs_g, :fat_g])

      validate string_length(:food_name, min: 1, max: 255)
      validate numericality(:calories, greater_than: 0)
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute :logged_on, :date do
      allow_nil?(false)
    end

    attribute :meal_type, :atom do
      constraints(one_of: [:breakfast, :lunch, :dinner, :snack])
      allow_nil?(false)
    end

    attribute :food_name, :string do
      allow_nil?(false)
      constraints(max_length: 255)
    end

    attribute :calories, :integer do
      allow_nil?(false)
    end

    attribute :protein_g, :decimal
    attribute :carbs_g, :decimal
    attribute :fat_g, :decimal

    timestamps()
  end

  relationships do
    belongs_to :member, FitTrackerz.Gym.GymMember do
      allow_nil?(false)
    end

    belongs_to :gym, FitTrackerz.Gym.Gym do
      allow_nil?(false)
    end
  end
end
```

- [ ] **Step 2: Register FoodLog in Health domain**

Update `lib/fit_trackerz/health.ex` to add after the HealthMetric resource block:

```elixir
    resource FitTrackerz.Health.FoodLog do
      define :list_food_logs_by_date, args: [:member_ids, :date], action: :list_by_member_and_date
      define :list_food_logs, args: [:member_ids], action: :list_by_member
      define :list_food_logs_by_range, args: [:member_ids, :start_date, :end_date], action: :list_by_member_date_range
      define :create_food_log, action: :create
      define :update_food_log, action: :update
      define :destroy_food_log, action: :destroy
    end
```

- [ ] **Step 3: Compile and verify**

Run: `mix compile`
Expected: No errors

- [ ] **Step 4: Commit**

```bash
git add lib/fit_trackerz/health/food_log.ex lib/fit_trackerz/health.ex
git commit -m "feat: add FoodLog resource to Health domain"
```

---

### Task 3: WorkoutLog & WorkoutLogEntry Resources

**Files:**
- Create: `lib/fit_trackerz/training/workout_log.ex`
- Create: `lib/fit_trackerz/training/workout_log_entry.ex`
- Modify: `lib/fit_trackerz/training.ex`

- [ ] **Step 1: Create WorkoutLogEntry resource**

Create `lib/fit_trackerz/training/workout_log_entry.ex`:

```elixir
defmodule FitTrackerz.Training.WorkoutLogEntry do
  use Ash.Resource,
    domain: FitTrackerz.Training,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("workout_log_entries")
    repo(FitTrackerz.Repo)

    references do
      reference :workout_log, on_delete: :delete
    end

    custom_indexes do
      index([:workout_log_id])
    end
  end

  policies do
    bypass actor_attribute_equals(:is_system_actor, true) do
      authorize_if always()
    end

    bypass actor_attribute_equals(:role, :platform_admin) do
      authorize_if always()
    end

    policy action_type(:read) do
      authorize_if always()
    end

    policy action_type([:create, :destroy]) do
      authorize_if actor_attribute_equals(:role, :member)
    end
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      accept([:workout_log_id, :exercise_name, :planned_sets, :planned_reps, :actual_sets, :actual_reps, :weight_kg, :order])
    end

    read :list_by_workout_log do
      argument :workout_log_id, :uuid, allow_nil?: false
      filter expr(workout_log_id == ^arg(:workout_log_id))
      prepare build(sort: [order: :asc])
    end

    read :list_by_member_exercise do
      argument :member_id, :uuid, allow_nil?: false
      argument :exercise_name, :string, allow_nil?: false
      filter expr(workout_log.member_id == ^arg(:member_id) and exercise_name == ^arg(:exercise_name) and not is_nil(weight_kg))
      prepare build(sort: [weight_kg: :desc], limit: 1)
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute :exercise_name, :string do
      allow_nil?(false)
      constraints(max_length: 255)
    end

    attribute :planned_sets, :integer
    attribute :planned_reps, :integer

    attribute :actual_sets, :integer do
      allow_nil?(false)
      constraints(min: 0)
    end

    attribute :actual_reps, :integer do
      allow_nil?(false)
      constraints(min: 0)
    end

    attribute :weight_kg, :decimal do
      constraints(min: 0)
    end

    attribute :order, :integer do
      allow_nil?(false)
      constraints(min: 0)
    end

    timestamps()
  end

  relationships do
    belongs_to :workout_log, FitTrackerz.Training.WorkoutLog do
      allow_nil?(false)
    end
  end
end
```

- [ ] **Step 2: Create WorkoutLog resource**

Create `lib/fit_trackerz/training/workout_log.ex`:

```elixir
defmodule FitTrackerz.Training.WorkoutLog do
  use Ash.Resource,
    domain: FitTrackerz.Training,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("workout_logs")
    repo(FitTrackerz.Repo)

    references do
      reference :member, on_delete: :delete
      reference :gym, on_delete: :delete
      reference :workout_plan, on_delete: :nilify
    end

    custom_indexes do
      index([:member_id])
      index([:gym_id])
      index([:member_id, :completed_on])
    end
  end

  policies do
    bypass actor_attribute_equals(:is_system_actor, true) do
      authorize_if always()
    end

    bypass actor_attribute_equals(:role, :platform_admin) do
      authorize_if always()
    end

    policy action_type(:read) do
      authorize_if always()
    end

    policy action_type([:create, :destroy]) do
      authorize_if actor_attribute_equals(:role, :member)
    end
  end

  actions do
    defaults([:read, :destroy])

    read :list_by_member do
      argument :member_ids, {:array, :uuid}, allow_nil?: false
      filter expr(member_id in ^arg(:member_ids))
      prepare build(sort: [completed_on: :desc], load: [:entries, :workout_plan])
    end

    read :list_dates_by_member do
      argument :member_ids, {:array, :uuid}, allow_nil?: false
      filter expr(member_id in ^arg(:member_ids))
      prepare build(sort: [completed_on: :desc])
    end

    create :create do
      accept([:member_id, :gym_id, :workout_plan_id, :completed_on, :duration_minutes, :notes])

      validate string_length(:notes, max: 500)
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute :completed_on, :date do
      allow_nil?(false)
    end

    attribute :duration_minutes, :integer do
      constraints(min: 1)
    end

    attribute :notes, :string do
      constraints(max_length: 500)
    end

    timestamps()
  end

  relationships do
    belongs_to :member, FitTrackerz.Gym.GymMember do
      allow_nil?(false)
    end

    belongs_to :gym, FitTrackerz.Gym.Gym do
      allow_nil?(false)
    end

    belongs_to :workout_plan, FitTrackerz.Training.WorkoutPlan

    has_many :entries, FitTrackerz.Training.WorkoutLogEntry
  end
end
```

- [ ] **Step 3: Register in Training domain**

Add to `lib/fit_trackerz/training.ex` after the DietPlan resource block:

```elixir
    resource FitTrackerz.Training.WorkoutLog do
      define :list_workout_logs, args: [:member_ids], action: :list_by_member
      define :list_workout_log_dates, args: [:member_ids], action: :list_dates_by_member
      define :create_workout_log, action: :create
      define :destroy_workout_log, action: :destroy
    end

    resource FitTrackerz.Training.WorkoutLogEntry do
      define :list_workout_log_entries, args: [:workout_log_id], action: :list_by_workout_log
      define :get_exercise_pr, args: [:member_id, :exercise_name], action: :list_by_member_exercise
      define :create_workout_log_entry, action: :create
    end
```

- [ ] **Step 4: Compile and verify**

Run: `mix compile`
Expected: No errors

- [ ] **Step 5: Commit**

```bash
git add lib/fit_trackerz/training/workout_log.ex lib/fit_trackerz/training/workout_log_entry.ex lib/fit_trackerz/training.ex
git commit -m "feat: add WorkoutLog and WorkoutLogEntry resources to Training domain"
```

---

### Task 4: Database Migration

**Files:**
- Create: `priv/repo/migrations/*_add_health_and_workout_tracking.exs`

- [ ] **Step 1: Generate and write the migration**

Run: `mix ash.codegen add_health_and_workout_tracking`

This generates migrations for all 4 new tables. If `ash.codegen` doesn't produce the expected migration, create it manually:

```bash
mix ecto.gen.migration add_health_and_workout_tracking
```

Then write the migration content:

```elixir
defmodule FitTrackerz.Repo.Migrations.AddHealthAndWorkoutTracking do
  use Ecto.Migration

  def up do
    # Health Metrics
    create table(:health_metrics, primary_key: false) do
      add :id, :uuid, null: false, primary_key: true
      add :recorded_on, :date, null: false
      add :weight_kg, :decimal, null: false
      add :height_cm, :decimal
      add :bmi, :decimal
      add :body_fat_pct, :decimal
      add :notes, :text
      add :member_id, references(:gym_members, type: :uuid, on_delete: :delete_all), null: false
      add :gym_id, references(:gyms, type: :uuid, on_delete: :delete_all), null: false
      timestamps(type: :utc_datetime)
    end

    create index(:health_metrics, [:member_id])
    create index(:health_metrics, [:gym_id])
    create unique_index(:health_metrics, [:member_id, :recorded_on])

    # Food Logs
    create table(:food_logs, primary_key: false) do
      add :id, :uuid, null: false, primary_key: true
      add :logged_on, :date, null: false
      add :meal_type, :text, null: false
      add :food_name, :text, null: false
      add :calories, :integer, null: false
      add :protein_g, :decimal
      add :carbs_g, :decimal
      add :fat_g, :decimal
      add :member_id, references(:gym_members, type: :uuid, on_delete: :delete_all), null: false
      add :gym_id, references(:gyms, type: :uuid, on_delete: :delete_all), null: false
      timestamps(type: :utc_datetime)
    end

    create index(:food_logs, [:member_id])
    create index(:food_logs, [:gym_id])
    create index(:food_logs, [:member_id, :logged_on])

    # Workout Logs
    create table(:workout_logs, primary_key: false) do
      add :id, :uuid, null: false, primary_key: true
      add :completed_on, :date, null: false
      add :duration_minutes, :integer
      add :notes, :text
      add :member_id, references(:gym_members, type: :uuid, on_delete: :delete_all), null: false
      add :gym_id, references(:gyms, type: :uuid, on_delete: :delete_all), null: false
      add :workout_plan_id, references(:workout_plans, type: :uuid, on_delete: :nilify_all)
      timestamps(type: :utc_datetime)
    end

    create index(:workout_logs, [:member_id])
    create index(:workout_logs, [:gym_id])
    create index(:workout_logs, [:member_id, :completed_on])

    # Workout Log Entries
    create table(:workout_log_entries, primary_key: false) do
      add :id, :uuid, null: false, primary_key: true
      add :exercise_name, :text, null: false
      add :planned_sets, :integer
      add :planned_reps, :integer
      add :actual_sets, :integer, null: false
      add :actual_reps, :integer, null: false
      add :weight_kg, :decimal
      add :order, :integer, null: false
      add :workout_log_id, references(:workout_logs, type: :uuid, on_delete: :delete_all), null: false
      timestamps(type: :utc_datetime)
    end

    create index(:workout_log_entries, [:workout_log_id])
  end

  def down do
    drop table(:workout_log_entries)
    drop table(:workout_logs)
    drop table(:food_logs)
    drop table(:health_metrics)
  end
end
```

- [ ] **Step 2: Run the migration**

Run: `mix ecto.migrate`
Expected: Migration runs successfully, 4 tables created

- [ ] **Step 3: Commit**

```bash
git add priv/repo/migrations/
git commit -m "feat: add migration for health_metrics, food_logs, workout_logs, workout_log_entries tables"
```

---

### Task 5: Chart.js Hook Setup

**Files:**
- Create: `assets/js/chart_hook.js`
- Modify: `assets/js/app.js`

- [ ] **Step 1: Install Chart.js**

Run: `npm install chart.js --prefix assets`
Expected: chart.js added to `assets/node_modules/`

- [ ] **Step 2: Create the Chart hook**

Create `assets/js/chart_hook.js`:

```javascript
import Chart from "chart.js/auto"

const ChartHook = {
  mounted() {
    this.chart = null
    this.renderChart()
  },

  updated() {
    this.renderChart()
  },

  destroyed() {
    if (this.chart) {
      this.chart.destroy()
    }
  },

  renderChart() {
    const canvas = this.el.querySelector("canvas")
    if (!canvas) return

    const config = JSON.parse(this.el.dataset.chart)

    if (this.chart) {
      this.chart.destroy()
    }

    // Apply dark theme defaults
    config.options = config.options || {}
    config.options.responsive = true
    config.options.maintainAspectRatio = false
    config.options.plugins = config.options.plugins || {}
    config.options.plugins.legend = config.options.plugins.legend || { display: false }
    config.options.scales = config.options.scales || {}

    if (config.options.scales.x) {
      config.options.scales.x.ticks = config.options.scales.x.ticks || {}
      config.options.scales.x.ticks.color = "rgba(255,255,255,0.4)"
      config.options.scales.x.grid = { color: "rgba(255,255,255,0.05)" }
    }

    if (config.options.scales.y) {
      config.options.scales.y.ticks = config.options.scales.y.ticks || {}
      config.options.scales.y.ticks.color = "rgba(255,255,255,0.4)"
      config.options.scales.y.grid = { color: "rgba(255,255,255,0.05)" }
    }

    this.chart = new Chart(canvas, config)
  }
}

export default ChartHook
```

- [ ] **Step 3: Register hook in app.js**

In `assets/js/app.js`, add the import after the existing imports (around line 25):

```javascript
import ChartHook from "./chart_hook"
```

Then update the hooks object in the LiveSocket initialization (line 278):

```javascript
  hooks: {Geolocation, BranchGeolocation, PlacesAutocomplete, ExplorePlacesAutocomplete, PasswordVisibilityToggle, ChartHook},
```

- [ ] **Step 4: Verify assets compile**

Run: `cd assets && npx esbuild js/app.js --bundle --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* 2>&1 | head -5`
Expected: No errors

- [ ] **Step 5: Commit**

```bash
git add assets/js/chart_hook.js assets/js/app.js assets/package-lock.json
git commit -m "feat: add Chart.js hook for LiveView charts"
```

---

### Task 6: Routes

**Files:**
- Modify: `lib/fit_trackerz_web/router.ex`

- [ ] **Step 1: Add new member routes**

In `lib/fit_trackerz_web/router.ex`, inside the `:member` live session scope (around line 156, after the existing `live "/attendance", AttendanceLive` line), add:

```elixir
      live "/health", HealthLive
      live "/food", FoodLive
      live "/progress", ProgressLive
```

- [ ] **Step 2: Compile and verify**

Run: `mix compile`
Expected: Warnings about missing modules (HealthLive, FoodLive, ProgressLive) — expected since pages aren't created yet

- [ ] **Step 3: Commit**

```bash
git add lib/fit_trackerz_web/router.ex
git commit -m "feat: add routes for health, food, and progress pages"
```

---

### Task 7: Health Log Page

**Files:**
- Create: `lib/fit_trackerz_web/live/member/health_live.ex`

- [ ] **Step 1: Create the Health Log LiveView**

Create `lib/fit_trackerz_web/live/member/health_live.ex`:

```elixir
defmodule FitTrackerzWeb.Member.HealthLive do
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
        {:ok, assign(socket, page_title: "Health Log", no_gym: true, metrics: [], form: nil, last_height: nil)}

      memberships ->
        member_ids = Enum.map(memberships, & &1.id)
        membership = List.first(memberships)

        metrics = case FitTrackerz.Health.list_health_metrics(member_ids, actor: actor) do
          {:ok, metrics} -> metrics
          _ -> []
        end

        last_height = case metrics do
          [latest | _] -> latest.height_cm
          [] -> nil
        end

        form = to_form(%{
          "recorded_on" => Date.to_iso8601(Date.utc_today()),
          "weight_kg" => "",
          "height_cm" => if(last_height, do: Decimal.to_string(last_height), else: ""),
          "body_fat_pct" => "",
          "notes" => ""
        }, as: "metric")

        {:ok,
         assign(socket,
           page_title: "Health Log",
           no_gym: false,
           membership: membership,
           metrics: metrics,
           form: form,
           last_height: last_height
         )}
    end
  end

  @impl true
  def handle_event("validate", %{"metric" => params}, socket) do
    form = to_form(params, as: "metric")
    {:noreply, assign(socket, form: form)}
  end

  def handle_event("save", %{"metric" => params}, socket) do
    actor = socket.assigns.current_user
    membership = socket.assigns.membership

    height = parse_decimal(params["height_cm"])
    height = height || socket.assigns.last_height

    attrs = %{
      member_id: membership.id,
      gym_id: membership.gym_id,
      recorded_on: params["recorded_on"],
      weight_kg: parse_decimal(params["weight_kg"]),
      height_cm: height,
      body_fat_pct: parse_decimal(params["body_fat_pct"]),
      notes: params["notes"]
    }

    case FitTrackerz.Health.create_health_metric(attrs, actor: actor) do
      {:ok, _metric} ->
        member_ids = [membership.id]
        metrics = case FitTrackerz.Health.list_health_metrics(member_ids, actor: actor) do
          {:ok, m} -> m
          _ -> []
        end

        last_height = case metrics do
          [latest | _] -> latest.height_cm
          [] -> nil
        end

        form = to_form(%{
          "recorded_on" => Date.to_iso8601(Date.utc_today()),
          "weight_kg" => "",
          "height_cm" => if(last_height, do: Decimal.to_string(last_height), else: ""),
          "body_fat_pct" => "",
          "notes" => ""
        }, as: "metric")

        {:noreply,
         socket
         |> put_flash(:info, "Health entry saved!")
         |> assign(metrics: metrics, form: form, last_height: last_height)}

      {:error, error} ->
        {:noreply, put_flash(socket, :error, FitTrackerzWeb.AshErrorHelpers.user_friendly_message(error))}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    actor = socket.assigns.current_user
    membership = socket.assigns.membership

    metric = Enum.find(socket.assigns.metrics, &(&1.id == id))

    if metric do
      case FitTrackerz.Health.destroy_health_metric(metric, actor: actor) do
        :ok ->
          metrics = case FitTrackerz.Health.list_health_metrics([membership.id], actor: actor) do
            {:ok, m} -> m
            _ -> []
          end

          {:noreply,
           socket
           |> put_flash(:info, "Entry deleted.")
           |> assign(metrics: metrics)}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to delete entry.")}
      end
    else
      {:noreply, put_flash(socket, :error, "Entry not found.")}
    end
  end

  defp parse_decimal(""), do: nil
  defp parse_decimal(nil), do: nil
  defp parse_decimal(val) when is_binary(val) do
    case Decimal.parse(val) do
      {d, _} -> d
      :error -> nil
    end
  end
  defp parse_decimal(%Decimal{} = d), do: d

  defp format_decimal(nil), do: "--"
  defp format_decimal(%Decimal{} = d), do: Decimal.to_string(d, :normal)
  defp format_decimal(val), do: to_string(val)

  defp weight_change(metrics, index) do
    current = Enum.at(metrics, index)
    previous = Enum.at(metrics, index + 1)

    if current && previous do
      diff = Decimal.sub(current.weight_kg, previous.weight_kg)
      {Decimal.to_float(diff), Decimal.to_string(Decimal.abs(diff), :normal)}
    else
      nil
    end
  end

  defp bmi_category(nil), do: ""
  defp bmi_category(bmi) do
    val = Decimal.to_float(bmi)
    cond do
      val < 18.5 -> "Underweight"
      val < 25.0 -> "Normal"
      val < 30.0 -> "Overweight"
      true -> "Obese"
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="space-y-8">
        <div class="flex items-center gap-3">
          <Layouts.back_button />
          <div>
            <h1 class="text-2xl sm:text-3xl font-brand">Health Log</h1>
            <p class="text-base-content/50 mt-1">Track your weight, BMI, and body composition.</p>
          </div>
        </div>

        <%= if @no_gym do %>
          <div class="card bg-base-200/50 border border-base-300/50" id="no-gym-card">
            <div class="card-body items-center text-center p-8">
              <div class="w-16 h-16 rounded-2xl bg-warning/10 flex items-center justify-center mb-4">
                <.icon name="hero-building-office-2" class="size-8 text-warning" />
              </div>
              <h2 class="text-lg font-bold">No Gym Membership</h2>
              <p class="text-sm text-base-content/50 max-w-md mt-2">
                You need a gym membership to track your health metrics.
              </p>
            </div>
          </div>
        <% else %>
          <%!-- Log Form --%>
          <div class="card bg-base-200/50 border border-base-300/50" id="health-form-card">
            <div class="card-body p-6">
              <h2 class="text-lg font-bold flex items-center gap-2 mb-4">
                <.icon name="hero-plus-circle-solid" class="size-5 text-success" /> Log Entry
              </h2>
              <.form for={@form} id="health-form" phx-change="validate" phx-submit="save">
                <div class="flex flex-wrap gap-4 items-end">
                  <div>
                    <.input field={@form[:recorded_on]} type="date" label="Date" required />
                  </div>
                  <div>
                    <.input field={@form[:weight_kg]} type="number" label="Weight (kg)" step="0.1" required />
                  </div>
                  <div>
                    <.input field={@form[:height_cm]} type="number" label="Height (cm)" step="0.1" />
                  </div>
                  <div>
                    <.input field={@form[:body_fat_pct]} type="number" label="Body Fat %" step="0.1" />
                  </div>
                  <div>
                    <.input field={@form[:notes]} type="text" label="Notes" placeholder="Optional" />
                  </div>
                  <div class="mb-2">
                    <button type="submit" class="btn btn-success btn-sm gap-2" id="save-health-btn">
                      <.icon name="hero-check-mini" class="size-4" /> Save
                    </button>
                  </div>
                </div>
              </.form>
            </div>
          </div>

          <%!-- History --%>
          <div class="card bg-base-200/50 border border-base-300/50" id="health-history-card">
            <div class="card-body p-6">
              <h2 class="text-lg font-bold flex items-center gap-2 mb-4">
                <.icon name="hero-chart-bar-solid" class="size-5 text-primary" /> History
                <span class="badge badge-neutral badge-sm">{length(@metrics)}</span>
              </h2>
              <%= if @metrics == [] do %>
                <div class="flex items-center gap-3 p-4 rounded-lg bg-base-300/20">
                  <p class="text-sm text-base-content/50">No entries yet. Log your first measurement above!</p>
                </div>
              <% else %>
                <div class="overflow-x-auto">
                  <table class="table table-sm" id="health-table">
                    <thead>
                      <tr class="text-base-content/40">
                        <th>Date</th>
                        <th>Weight</th>
                        <th>BMI</th>
                        <th>Body Fat</th>
                        <th>Change</th>
                        <th>Actions</th>
                      </tr>
                    </thead>
                    <tbody>
                      <%= for {metric, idx} <- Enum.with_index(@metrics) do %>
                        <tr id={"metric-#{metric.id}"}>
                          <td class="font-medium">{Calendar.strftime(metric.recorded_on, "%b %d, %Y")}</td>
                          <td>{format_decimal(metric.weight_kg)} kg</td>
                          <td>
                            {format_decimal(metric.bmi)}
                            <span class="text-xs text-base-content/40 ml-1">{bmi_category(metric.bmi)}</span>
                          </td>
                          <td>
                            <%= if metric.body_fat_pct do %>
                              {format_decimal(metric.body_fat_pct)}%
                            <% else %>
                              <span class="text-base-content/30">--</span>
                            <% end %>
                          </td>
                          <td>
                            <% change = weight_change(@metrics, idx) %>
                            <%= if change do %>
                              <% {diff, abs_str} = change %>
                              <%= if diff < 0 do %>
                                <span class="text-success font-medium">↓ {abs_str} kg</span>
                              <% else %>
                                <span class="text-warning font-medium">↑ {abs_str} kg</span>
                              <% end %>
                            <% else %>
                              <span class="text-base-content/30">—</span>
                            <% end %>
                          </td>
                          <td>
                            <button
                              phx-click="delete"
                              phx-value-id={metric.id}
                              data-confirm="Delete this entry?"
                              class="btn btn-ghost btn-xs text-error"
                              id={"delete-metric-#{metric.id}"}
                            >
                              <.icon name="hero-trash-mini" class="size-3.5" />
                            </button>
                          </td>
                        </tr>
                      <% end %>
                    </tbody>
                  </table>
                </div>
              <% end %>
            </div>
          </div>
        <% end %>
      </div>
    </Layouts.app>
    """
  end
end
```

- [ ] **Step 2: Compile and verify**

Run: `mix compile`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add lib/fit_trackerz_web/live/member/health_live.ex
git commit -m "feat: add Health Log page for members"
```

---

### Task 8: Food Log Page

**Files:**
- Create: `lib/fit_trackerz_web/live/member/food_live.ex`

- [ ] **Step 1: Create the Food Log LiveView**

Create `lib/fit_trackerz_web/live/member/food_live.ex`. This is a large file — key functionality:

- Date picker (defaults to today) to view/add entries for any day
- Calorie summary bar (consumed vs diet plan target)
- Macro totals (protein, carbs, fat)
- Add food form with meal type dropdown
- Today's food entries listed by meal type
- Delete individual entries

```elixir
defmodule FitTrackerzWeb.Member.FoodLive do
  use FitTrackerzWeb, :live_view

  @meal_types [{:breakfast, "Breakfast"}, {:lunch, "Lunch"}, {:dinner, "Dinner"}, {:snack, "Snack"}]

  @impl true
  def mount(_params, _session, socket) do
    actor = socket.assigns.current_user

    memberships = case FitTrackerz.Gym.list_active_memberships(actor.id, actor: actor, load: [:gym]) do
      {:ok, memberships} -> memberships
      _ -> []
    end

    case memberships do
      [] ->
        {:ok, assign(socket, page_title: "Food Log", no_gym: true, entries: [], form: nil,
          calorie_target: nil, selected_date: Date.utc_today(), meal_types: @meal_types)}

      memberships ->
        membership = List.first(memberships)
        member_ids = Enum.map(memberships, & &1.id)
        today = Date.utc_today()

        calorie_target = get_calorie_target(member_ids, actor)

        entries = load_entries(member_ids, today, actor)
        form = new_form(today)

        {:ok,
         assign(socket,
           page_title: "Food Log",
           no_gym: false,
           membership: membership,
           member_ids: member_ids,
           entries: entries,
           form: form,
           calorie_target: calorie_target,
           selected_date: today,
           meal_types: @meal_types
         )}
    end
  end

  @impl true
  def handle_event("validate", %{"food" => params}, socket) do
    {:noreply, assign(socket, form: to_form(params, as: "food"))}
  end

  def handle_event("change_date", %{"date" => date_str}, socket) do
    case Date.from_iso8601(date_str) do
      {:ok, date} ->
        entries = load_entries(socket.assigns.member_ids, date, socket.assigns.current_user)
        form = new_form(date)
        {:noreply, assign(socket, selected_date: date, entries: entries, form: form)}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("save", %{"food" => params}, socket) do
    actor = socket.assigns.current_user
    membership = socket.assigns.membership

    attrs = %{
      member_id: membership.id,
      gym_id: membership.gym_id,
      logged_on: socket.assigns.selected_date,
      meal_type: String.to_existing_atom(params["meal_type"]),
      food_name: params["food_name"],
      calories: parse_int(params["calories"]),
      protein_g: parse_decimal(params["protein_g"]),
      carbs_g: parse_decimal(params["carbs_g"]),
      fat_g: parse_decimal(params["fat_g"])
    }

    case FitTrackerz.Health.create_food_log(attrs, actor: actor) do
      {:ok, _entry} ->
        entries = load_entries(socket.assigns.member_ids, socket.assigns.selected_date, actor)
        form = new_form(socket.assigns.selected_date)

        {:noreply,
         socket
         |> put_flash(:info, "Food entry added!")
         |> assign(entries: entries, form: form)}

      {:error, error} ->
        {:noreply, put_flash(socket, :error, FitTrackerzWeb.AshErrorHelpers.user_friendly_message(error))}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    actor = socket.assigns.current_user

    entry = Enum.find(socket.assigns.entries, &(&1.id == id))

    if entry do
      case FitTrackerz.Health.destroy_food_log(entry, actor: actor) do
        :ok ->
          entries = load_entries(socket.assigns.member_ids, socket.assigns.selected_date, actor)
          {:noreply, socket |> put_flash(:info, "Entry deleted.") |> assign(entries: entries)}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to delete.")}
      end
    else
      {:noreply, put_flash(socket, :error, "Entry not found.")}
    end
  end

  defp get_calorie_target(member_ids, actor) do
    case FitTrackerz.Training.list_diets_by_member(member_ids, actor: actor) do
      {:ok, [plan | _]} -> plan.calorie_target
      _ -> nil
    end
  end

  defp load_entries(member_ids, date, actor) do
    case FitTrackerz.Health.list_food_logs_by_date(member_ids, date, actor: actor) do
      {:ok, entries} -> entries
      _ -> []
    end
  end

  defp new_form(date) do
    to_form(%{
      "logged_on" => Date.to_iso8601(date),
      "meal_type" => "breakfast",
      "food_name" => "",
      "calories" => "",
      "protein_g" => "",
      "carbs_g" => "",
      "fat_g" => ""
    }, as: "food")
  end

  defp parse_int(""), do: nil
  defp parse_int(nil), do: nil
  defp parse_int(val) when is_binary(val) do
    case Integer.parse(val) do
      {n, _} -> n
      :error -> nil
    end
  end

  defp parse_decimal(""), do: nil
  defp parse_decimal(nil), do: nil
  defp parse_decimal(val) when is_binary(val) do
    case Decimal.parse(val) do
      {d, _} -> d
      :error -> nil
    end
  end

  defp total_calories(entries), do: Enum.reduce(entries, 0, &(&1.calories + &2))

  defp total_macro(entries, field) do
    entries
    |> Enum.map(&Map.get(&1, field))
    |> Enum.reject(&is_nil/1)
    |> Enum.reduce(Decimal.new(0), &Decimal.add/2)
    |> Decimal.to_string(:normal)
  end

  defp calorie_pct(entries, nil), do: 0
  defp calorie_pct(entries, target) when target > 0, do: min(round(total_calories(entries) / target * 100), 100)
  defp calorie_pct(_, _), do: 0

  defp meal_badge_class(:breakfast), do: "bg-info/15 text-info"
  defp meal_badge_class(:lunch), do: "bg-success/15 text-success"
  defp meal_badge_class(:dinner), do: "bg-warning/15 text-warning"
  defp meal_badge_class(:snack), do: "bg-accent/15 text-accent"
  defp meal_badge_class(_), do: "bg-base-300/30 text-base-content/50"

  defp format_meal_type(type), do: type |> to_string() |> String.capitalize()

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="space-y-8">
        <div class="flex items-center gap-3">
          <Layouts.back_button />
          <div>
            <h1 class="text-2xl sm:text-3xl font-brand">Food Log</h1>
            <p class="text-base-content/50 mt-1">Track your daily meals and calories.</p>
          </div>
        </div>

        <%= if @no_gym do %>
          <div class="card bg-base-200/50 border border-base-300/50" id="no-gym-card">
            <div class="card-body items-center text-center p-8">
              <.icon name="hero-building-office-2" class="size-8 text-warning" />
              <h2 class="text-lg font-bold mt-4">No Gym Membership</h2>
            </div>
          </div>
        <% else %>
          <%!-- Date Picker + Summary --%>
          <div class="flex flex-col sm:flex-row gap-4">
            <%!-- Date --%>
            <div>
              <input
                type="date"
                value={Date.to_iso8601(@selected_date)}
                phx-change="change_date"
                name="date"
                class="input input-bordered input-sm"
                id="food-date-picker"
              />
            </div>

            <%!-- Calorie Summary --%>
            <div class="flex-1 card bg-base-200/50 border border-base-300/50">
              <div class="card-body p-4">
                <div class="flex items-center gap-6 flex-wrap">
                  <div>
                    <div class="text-xs text-base-content/40 uppercase font-medium">Calories</div>
                    <div class="flex items-baseline gap-1 mt-1">
                      <span class="text-2xl font-black text-warning">{total_calories(@entries)}</span>
                      <%= if @calorie_target do %>
                        <span class="text-sm text-base-content/50">/ {@calorie_target} target</span>
                      <% else %>
                        <span class="text-sm text-base-content/30">no target set</span>
                      <% end %>
                    </div>
                    <%= if @calorie_target do %>
                      <div class="w-48 bg-base-300/30 h-2 rounded-full mt-2">
                        <div class="bg-warning h-2 rounded-full transition-all" style={"width: #{calorie_pct(@entries, @calorie_target)}%"}></div>
                      </div>
                    <% end %>
                  </div>
                  <div class="flex gap-4">
                    <div class="text-center">
                      <div class="text-xs text-base-content/40">Protein</div>
                      <div class="font-bold">{total_macro(@entries, :protein_g)}g</div>
                    </div>
                    <div class="text-center">
                      <div class="text-xs text-base-content/40">Carbs</div>
                      <div class="font-bold">{total_macro(@entries, :carbs_g)}g</div>
                    </div>
                    <div class="text-center">
                      <div class="text-xs text-base-content/40">Fat</div>
                      <div class="font-bold">{total_macro(@entries, :fat_g)}g</div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <%!-- Add Food Form --%>
          <div class="card bg-base-200/50 border border-base-300/50" id="food-form-card">
            <div class="card-body p-6">
              <h2 class="text-lg font-bold flex items-center gap-2 mb-4">
                <.icon name="hero-plus-circle-solid" class="size-5 text-warning" /> Add Food
              </h2>
              <.form for={@form} id="food-form" phx-change="validate" phx-submit="save">
                <div class="flex flex-wrap gap-3 items-end">
                  <div>
                    <.input field={@form[:meal_type]} type="select" label="Meal" options={Enum.map(@meal_types, fn {v, l} -> {l, to_string(v)} end)} required />
                  </div>
                  <div class="flex-1 min-w-[150px]">
                    <.input field={@form[:food_name]} type="text" label="Food Name" placeholder="e.g., Chicken Biryani" required />
                  </div>
                  <div>
                    <.input field={@form[:calories]} type="number" label="Calories" required />
                  </div>
                  <div>
                    <.input field={@form[:protein_g]} type="number" label="Protein (g)" step="0.1" />
                  </div>
                  <div>
                    <.input field={@form[:carbs_g]} type="number" label="Carbs (g)" step="0.1" />
                  </div>
                  <div>
                    <.input field={@form[:fat_g]} type="number" label="Fat (g)" step="0.1" />
                  </div>
                  <div class="mb-2">
                    <button type="submit" class="btn btn-warning btn-sm gap-2" id="add-food-btn">
                      <.icon name="hero-plus-mini" class="size-4" /> Add
                    </button>
                  </div>
                </div>
              </.form>
            </div>
          </div>

          <%!-- Today's Entries --%>
          <div class="card bg-base-200/50 border border-base-300/50" id="food-entries-card">
            <div class="card-body p-6">
              <h2 class="text-lg font-bold flex items-center gap-2 mb-4">
                <.icon name="hero-queue-list-solid" class="size-5 text-primary" />
                {Calendar.strftime(@selected_date, "%b %d, %Y")}
                <span class="badge badge-neutral badge-sm">{length(@entries)} items</span>
              </h2>
              <%= if @entries == [] do %>
                <div class="flex items-center gap-3 p-4 rounded-lg bg-base-300/20">
                  <p class="text-sm text-base-content/50">No food logged for this day.</p>
                </div>
              <% else %>
                <div class="space-y-2">
                  <%= for entry <- @entries do %>
                    <div
                      class="flex items-center justify-between p-3 rounded-lg bg-base-300/20"
                      id={"food-#{entry.id}"}
                    >
                      <div class="flex items-center gap-3">
                        <span class={"text-xs px-2 py-0.5 rounded font-medium #{meal_badge_class(entry.meal_type)}"}>
                          {format_meal_type(entry.meal_type)}
                        </span>
                        <span class="font-medium text-sm">{entry.food_name}</span>
                      </div>
                      <div class="flex items-center gap-4">
                        <span class="text-sm text-base-content/60">{entry.calories} kcal</span>
                        <button
                          phx-click="delete"
                          phx-value-id={entry.id}
                          data-confirm="Delete this entry?"
                          class="btn btn-ghost btn-xs text-error"
                          id={"delete-food-#{entry.id}"}
                        >
                          <.icon name="hero-trash-mini" class="size-3.5" />
                        </button>
                      </div>
                    </div>
                  <% end %>
                </div>
              <% end %>
            </div>
          </div>
        <% end %>
      </div>
    </Layouts.app>
    """
  end
end
```

- [ ] **Step 2: Compile and verify**

Run: `mix compile`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add lib/fit_trackerz_web/live/member/food_live.ex
git commit -m "feat: add Food Log page for members"
```

---

### Task 9: Enhanced Workout Page with Logging, Streaks, and PRs

**Files:**
- Modify: `lib/fit_trackerz_web/live/member/workout_live.ex`

- [ ] **Step 1: Rewrite the workout LiveView**

Full rewrite of `lib/fit_trackerz_web/live/member/workout_live.ex`. The implementer should write the complete file with the code provided below. This preserves existing plan viewing but adds workout logging, streaks, and PR detection.

The full code for this file is provided in `docs/superpowers/plans/task9-workout-live.ex.txt` (a reference file created alongside this plan).

Key components of the implementation:

**Mount:** Load memberships, workout plans, workout logs (history), calculate streak.

```elixir
def mount(_params, _session, socket) do
  actor = socket.assigns.current_user
  memberships = load_memberships(actor)

  case memberships do
    [] -> {:ok, assign(socket, no_gym: true, ...defaults...)}
    memberships ->
      member_ids = Enum.map(memberships, & &1.id)
      membership = List.first(memberships)
      workout_plans = load_workout_plans(member_ids, actor)
      workout_logs = load_workout_logs(member_ids, actor)
      {current_streak, best_streak} = calculate_streaks(workout_logs)

      {:ok, assign(socket,
        membership: membership,
        workout_plans: workout_plans,
        workout_logs: workout_logs,
        current_streak: current_streak,
        best_streak: best_streak,
        show_log_form: false,
        log_entries: [],
        log_duration: "",
        log_notes: "",
        new_prs: []
      )}
  end
end
```

**Event: show_log_form** — Pre-fills log entries from the first workout plan's exercises:

```elixir
def handle_event("show_log_form", _params, socket) do
  plan = List.first(socket.assigns.workout_plans)
  log_entries = if plan do
    plan.exercises
    |> Enum.sort_by(& &1.order)
    |> Enum.map(fn ex ->
      %{"name" => ex.name, "planned_sets" => ex.sets, "planned_reps" => ex.reps,
        "actual_sets" => to_string(ex.sets || ""), "actual_reps" => to_string(ex.reps || ""),
        "weight_kg" => "", "order" => ex.order}
    end)
  else
    []
  end
  {:noreply, assign(socket, show_log_form: true, log_entries: log_entries, selected_plan: plan, new_prs: [])}
end
```

**Event: save_workout_log** — Creates WorkoutLog + entries, detects PRs:

```elixir
def handle_event("save_workout_log", _params, socket) do
  actor = socket.assigns.current_user
  membership = socket.assigns.membership
  plan = socket.assigns[:selected_plan]
  today = Date.utc_today()

  case FitTrackerz.Training.create_workout_log(%{
    member_id: membership.id, gym_id: membership.gym_id,
    workout_plan_id: plan && plan.id, completed_on: today,
    duration_minutes: parse_int(socket.assigns.log_duration),
    notes: socket.assigns.log_notes
  }, actor: actor) do
    {:ok, log} ->
      # Create entries and detect PRs
      new_prs = Enum.reduce(socket.assigns.log_entries, [], fn entry, prs ->
        attrs = %{workout_log_id: log.id, exercise_name: entry["name"],
          planned_sets: entry["planned_sets"], planned_reps: entry["planned_reps"],
          actual_sets: parse_int(entry["actual_sets"]),
          actual_reps: parse_int(entry["actual_reps"]),
          weight_kg: parse_decimal(entry["weight_kg"]), order: entry["order"]}

        FitTrackerz.Training.create_workout_log_entry(attrs, actor: actor)

        # Check PR
        weight = parse_decimal(entry["weight_kg"])
        if weight do
          case FitTrackerz.Training.get_exercise_pr(membership.id, entry["name"], actor: actor) do
            {:ok, [prev | _]} ->
              if Decimal.gt?(weight, prev.weight_kg),
                do: [%{name: entry["name"], weight: weight, prev: prev.weight_kg} | prs],
                else: prs
            _ -> prs
          end
        else
          prs
        end
      end)

      # Reload
      workout_logs = load_workout_logs([membership.id], actor)
      {current_streak, best_streak} = calculate_streaks(workout_logs)

      {:noreply, socket
        |> put_flash(:info, "Workout logged!")
        |> assign(workout_logs: workout_logs, current_streak: current_streak,
           best_streak: best_streak, show_log_form: false, new_prs: Enum.reverse(new_prs))}

    {:error, error} ->
      {:noreply, put_flash(socket, :error, FitTrackerzWeb.AshErrorHelpers.user_friendly_message(error))}
  end
end
```

**Streak calculation helpers:**

```elixir
defp calculate_streaks(workout_logs) do
  dates = workout_logs
    |> Enum.map(& &1.completed_on)
    |> Enum.uniq()
    |> Enum.sort(Date)
    |> Enum.reverse()

  current = calculate_current_streak(dates, Date.utc_today())
  best = calculate_best_streak(Enum.reverse(dates))
  {current, best}
end

defp calculate_current_streak([], _today), do: 0
defp calculate_current_streak([latest | rest], today) do
  diff = Date.diff(today, latest)
  if diff > 1, do: 0, else: count_consecutive([latest | rest], 1)
end

defp count_consecutive([_], count), do: count
defp count_consecutive([a, b | rest], count) do
  if Date.diff(a, b) == 1, do: count_consecutive([b | rest], count + 1), else: count
end

defp calculate_best_streak([]), do: 0
defp calculate_best_streak(dates) do
  dates
  |> Enum.chunk_while([], fn date, acc ->
    case acc do
      [] -> {:cont, [date]}
      [prev | _] ->
        if Date.diff(date, prev) == 1, do: {:cont, [date | acc]}, else: {:cont, acc, [date]}
    end
  end, fn acc -> {:cont, acc, []} end)
  |> Enum.map(&length/1)
  |> Enum.max(fn -> 0 end)
end
```

**Render template** includes:
- Streak counters at top (current + best, with fire emoji)
- PR alerts if `@new_prs` is not empty
- "Log Today's Workout" button → reveals form with exercise table
- Exercise table: name, planned sets×reps, input fields for actual_sets, actual_reps, weight_kg
- Duration + notes fields, "Complete Workout" button
- Workout history section (existing plans + completed log history)

The template follows the same DaisyUI patterns as health_live.ex and food_live.ex.

- [ ] **Step 2: Compile and verify**

Run: `mix compile`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add lib/fit_trackerz_web/live/member/workout_live.ex
git commit -m "feat: enhance workout page with logging, streaks, and PR detection"
```

---

### Task 10: Progress Dashboard

**Files:**
- Create: `lib/fit_trackerz_web/live/member/progress_live.ex`

- [ ] **Step 1: Create the Progress Dashboard LiveView**

Create `lib/fit_trackerz_web/live/member/progress_live.ex`:

```elixir
defmodule FitTrackerzWeb.Member.ProgressLive do
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
        {:ok, assign(socket, page_title: "My Progress", no_gym: true)}

      memberships ->
        member_ids = Enum.map(memberships, & &1.id)
        today = Date.utc_today()
        thirty_days_ago = Date.add(today, -30)

        # Health metrics (last 30 days)
        metrics = case FitTrackerz.Health.list_health_metrics(member_ids, actor: actor) do
          {:ok, m} -> m
          _ -> []
        end

        recent_metrics = Enum.filter(metrics, &(Date.compare(&1.recorded_on, thirty_days_ago) != :lt))

        # Weight change
        {weight_change, latest_bmi} = calculate_weight_stats(recent_metrics)

        # Workout logs for streak
        workout_logs = case FitTrackerz.Training.list_workout_log_dates(member_ids, actor: actor) do
          {:ok, logs} -> logs
          _ -> []
        end

        dates = workout_logs |> Enum.map(& &1.completed_on) |> Enum.uniq() |> Enum.sort(Date) |> Enum.reverse()
        current_streak = calculate_current_streak(dates, today)

        # Calorie data (this week)
        week_start = Date.add(today, -Date.day_of_week(today) + 1)
        food_logs = case FitTrackerz.Health.list_food_logs_by_range(member_ids, week_start, today, actor: actor) do
          {:ok, logs} -> logs
          _ -> []
        end

        calorie_target = case FitTrackerz.Training.list_diets_by_member(member_ids, actor: actor) do
          {:ok, [plan | _]} -> plan.calorie_target
          _ -> nil
        end

        daily_calories = food_logs
          |> Enum.group_by(& &1.logged_on)
          |> Enum.map(fn {date, entries} -> {date, Enum.reduce(entries, 0, &(&1.calories + &2))} end)
          |> Map.new()

        avg_calories = if map_size(daily_calories) > 0 do
          total = daily_calories |> Map.values() |> Enum.sum()
          div(total, map_size(daily_calories))
        else
          0
        end

        # Recent PRs (get workout logs with entries, find max per exercise)
        all_logs = case FitTrackerz.Training.list_workout_logs(member_ids, actor: actor) do
          {:ok, logs} -> logs
          _ -> []
        end

        prs = calculate_prs(all_logs)

        # Chart configs
        chart_metrics = recent_metrics |> Enum.sort_by(& &1.recorded_on, Date)
        weight_chart = weight_chart_config(chart_metrics)
        calorie_chart = calorie_chart_config(daily_calories, week_start, today, calorie_target)

        {:ok,
         assign(socket,
           page_title: "My Progress",
           no_gym: false,
           weight_change: weight_change,
           latest_bmi: latest_bmi,
           current_streak: current_streak,
           avg_calories: avg_calories,
           calorie_target: calorie_target,
           weight_chart: Jason.encode!(weight_chart),
           calorie_chart: Jason.encode!(calorie_chart),
           prs: Enum.take(prs, 6),
           has_metrics: chart_metrics != []
         )}
    end
  end

  defp calculate_weight_stats([]), do: {nil, nil}
  defp calculate_weight_stats(metrics) do
    sorted = Enum.sort_by(metrics, & &1.recorded_on, Date)
    first = List.first(sorted)
    last = List.last(sorted)

    change = if first && last && first.id != last.id do
      Decimal.sub(last.weight_kg, first.weight_kg) |> Decimal.to_float() |> Float.round(1)
    else
      nil
    end

    {change, last.bmi}
  end

  defp calculate_current_streak([], _today), do: 0
  defp calculate_current_streak([latest | rest], today) do
    diff = Date.diff(today, latest)
    if diff > 1, do: 0, else: count_consecutive([latest | rest], 1)
  end

  defp count_consecutive([_], count), do: count
  defp count_consecutive([a, b | rest], count) do
    if Date.diff(a, b) == 1, do: count_consecutive([b | rest], count + 1), else: count
  end

  defp calculate_prs(logs) do
    logs
    |> Enum.flat_map(fn log -> log.entries || [] end)
    |> Enum.filter(& &1.weight_kg)
    |> Enum.group_by(& &1.exercise_name)
    |> Enum.map(fn {name, entries} ->
      best = Enum.max_by(entries, &Decimal.to_float(&1.weight_kg))
      %{name: name, weight: Decimal.to_string(best.weight_kg, :normal)}
    end)
    |> Enum.sort_by(& &1.name)
  end

  defp weight_chart_config([]) do
    %{type: "line", data: %{labels: [], datasets: []}, options: %{scales: %{x: %{}, y: %{}}}}
  end

  defp weight_chart_config(metrics) do
    labels = Enum.map(metrics, &Calendar.strftime(&1.recorded_on, "%b %d"))
    data = Enum.map(metrics, &Decimal.to_float(&1.weight_kg))

    %{
      type: "line",
      data: %{
        labels: labels,
        datasets: [%{
          label: "Weight (kg)",
          data: data,
          borderColor: "rgb(34, 197, 94)",
          backgroundColor: "rgba(34, 197, 94, 0.1)",
          fill: true,
          tension: 0.3,
          pointRadius: 4
        }]
      },
      options: %{scales: %{x: %{}, y: %{}}}
    }
  end

  defp calorie_chart_config(daily_calories, week_start, today, calorie_target) do
    days = Enum.map(0..6, fn i -> Date.add(week_start, i) end)
    labels = Enum.map(days, &Calendar.strftime(&1, "%a"))
    data = Enum.map(days, fn d ->
      if Date.compare(d, today) != :gt, do: Map.get(daily_calories, d, 0), else: 0
    end)

    datasets = [%{
      label: "Calories",
      data: data,
      backgroundColor: "rgba(245, 158, 11, 0.5)",
      borderColor: "rgb(245, 158, 11)",
      borderWidth: 1,
      borderRadius: 4
    }]

    datasets = if calorie_target do
      target_line = %{
        label: "Target",
        data: Enum.map(days, fn _ -> calorie_target end),
        type: "line",
        borderColor: "rgba(255, 255, 255, 0.3)",
        borderDash: [5, 5],
        pointRadius: 0,
        fill: false
      }
      datasets ++ [target_line]
    else
      datasets
    end

    %{
      type: "bar",
      data: %{labels: labels, datasets: datasets},
      options: %{scales: %{x: %{}, y: %{beginAtZero: true}}}
    }
  end

  defp bmi_category(nil), do: ""
  defp bmi_category(bmi) do
    val = Decimal.to_float(bmi)
    cond do
      val < 18.5 -> "Underweight"
      val < 25.0 -> "Normal"
      val < 30.0 -> "Overweight"
      true -> "Obese"
    end
  end

  defp format_bmi(nil), do: "--"
  defp format_bmi(bmi), do: Decimal.to_string(bmi, :normal)

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="space-y-8">
        <div class="flex items-center gap-3">
          <Layouts.back_button />
          <div>
            <h1 class="text-2xl sm:text-3xl font-brand">My Progress</h1>
            <p class="text-base-content/50 mt-1">Track your fitness journey over time.</p>
          </div>
        </div>

        <%= if @no_gym do %>
          <div class="card bg-base-200/50 border border-base-300/50" id="no-gym-card">
            <div class="card-body items-center text-center p-8">
              <.icon name="hero-building-office-2" class="size-8 text-warning" />
              <h2 class="text-lg font-bold mt-4">No Gym Membership</h2>
            </div>
          </div>
        <% else %>
          <%!-- Stat Cards --%>
          <div class="grid grid-cols-2 lg:grid-cols-4 gap-4">
            <div class="card bg-base-200/50 border border-base-300/50" id="stat-weight">
              <div class="card-body p-4">
                <p class="text-xs font-semibold text-base-content/40 uppercase tracking-wider">Weight Change</p>
                <p class="text-2xl font-black mt-1">
                  <%= if @weight_change do %>
                    <span class={if @weight_change < 0, do: "text-success", else: "text-warning"}>
                      {if @weight_change < 0, do: "", else: "+"}{@weight_change} kg
                    </span>
                  <% else %>
                    <span class="text-base-content/30">--</span>
                  <% end %>
                </p>
                <p class="text-xs text-base-content/40 mt-1">Last 30 days</p>
              </div>
            </div>
            <div class="card bg-base-200/50 border border-base-300/50" id="stat-bmi">
              <div class="card-body p-4">
                <p class="text-xs font-semibold text-base-content/40 uppercase tracking-wider">Current BMI</p>
                <p class="text-2xl font-black text-info mt-1">{format_bmi(@latest_bmi)}</p>
                <p class="text-xs text-base-content/40 mt-1">{bmi_category(@latest_bmi)}</p>
              </div>
            </div>
            <div class="card bg-base-200/50 border border-base-300/50" id="stat-streak">
              <div class="card-body p-4">
                <p class="text-xs font-semibold text-base-content/40 uppercase tracking-wider">Workout Streak</p>
                <p class="text-2xl font-black text-accent mt-1">{@current_streak} days</p>
                <p class="text-xs text-base-content/40 mt-1">Current streak</p>
              </div>
            </div>
            <div class="card bg-base-200/50 border border-base-300/50" id="stat-calories">
              <div class="card-body p-4">
                <p class="text-xs font-semibold text-base-content/40 uppercase tracking-wider">Avg Calories</p>
                <p class="text-2xl font-black text-warning mt-1">{@avg_calories}</p>
                <p class="text-xs text-base-content/40 mt-1">
                  <%= if @calorie_target do %>
                    / {@calorie_target} target
                  <% else %>
                    no target set
                  <% end %>
                </p>
              </div>
            </div>
          </div>

          <%!-- Charts --%>
          <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
            <div class="card bg-base-200/50 border border-base-300/50" id="weight-chart-card">
              <div class="card-body p-5">
                <h2 class="text-lg font-bold flex items-center gap-2 mb-4">
                  <.icon name="hero-chart-bar-solid" class="size-5 text-success" /> Weight Trend
                </h2>
                <%= if @has_metrics do %>
                  <div id="weight-chart" phx-hook="ChartHook" data-chart={@weight_chart} phx-update="ignore" style="height: 250px;">
                    <canvas></canvas>
                  </div>
                <% else %>
                  <div class="flex items-center justify-center h-[250px]">
                    <p class="text-sm text-base-content/40">No health data yet. Start logging at /member/health</p>
                  </div>
                <% end %>
              </div>
            </div>
            <div class="card bg-base-200/50 border border-base-300/50" id="calorie-chart-card">
              <div class="card-body p-5">
                <h2 class="text-lg font-bold flex items-center gap-2 mb-4">
                  <.icon name="hero-fire-solid" class="size-5 text-warning" /> This Week's Calories
                </h2>
                <div id="calorie-chart" phx-hook="ChartHook" data-chart={@calorie_chart} phx-update="ignore" style="height: 250px;">
                  <canvas></canvas>
                </div>
              </div>
            </div>
          </div>

          <%!-- Recent PRs --%>
          <%= if @prs != [] do %>
            <div class="card bg-base-200/50 border border-base-300/50" id="prs-card">
              <div class="card-body p-5">
                <h2 class="text-lg font-bold flex items-center gap-2 mb-4">
                  <span class="text-xl">🏆</span> Personal Records
                </h2>
                <div class="flex flex-wrap gap-3">
                  <%= for pr <- @prs do %>
                    <div class="px-4 py-2 rounded-lg bg-warning/10 border border-warning/20">
                      <span class="font-bold text-sm">{pr.name}</span>
                      <span class="text-sm text-warning ml-2">{pr.weight} kg</span>
                    </div>
                  <% end %>
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
```

- [ ] **Step 2: Compile and verify**

Run: `mix compile`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add lib/fit_trackerz_web/live/member/progress_live.ex
git commit -m "feat: add Progress Dashboard with Chart.js charts"
```

---

### Task 11: Dashboard Integration

**Files:**
- Modify: `lib/fit_trackerz_web/live/member/dashboard_live.ex`

- [ ] **Step 1: Add streak and calorie stats to member dashboard**

In `lib/fit_trackerz_web/live/member/dashboard_live.ex`:

1. In `load_dashboard/2`, after loading existing data, add:
   - Load workout log dates to calculate current streak
   - Load today's food logs to get daily calorie total

2. Add new assigns: `streak_count`, `today_calories`, `calorie_target`

3. In the render template's stats grid (the 4-card grid), replace or add 2 new stat cards:
   - **Streak** card linking to `/member/workout`
   - **Today's Calories** card linking to `/member/food`

- [ ] **Step 2: Compile and verify**

Run: `mix compile`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add lib/fit_trackerz_web/live/member/dashboard_live.ex
git commit -m "feat: add streak and calorie stats to member dashboard"
```

---

### Task 12: Final Verification

- [ ] **Step 1: Run full compile**

Run: `mix compile`
Expected: No errors, no warnings

- [ ] **Step 2: Verify migration is up to date**

Run: `mix ecto.migrate`
Expected: Migration succeeds

- [ ] **Step 3: Run existing tests**

Run: `mix test`
Expected: All existing tests pass (no regressions)

- [ ] **Step 4: Manual smoke test checklist**

Start server: `mix phx.server`

Test as a member user:
1. `/member/health` — log a weight entry, verify BMI calculates, verify history shows
2. `/member/food` — add a food entry, verify calorie total updates, change date
3. `/member/workout` — log a workout against assigned plan, verify streak counter
4. `/member/progress` — verify charts render, stats show correct data
5. `/member/dashboard` — verify new stat cards appear

- [ ] **Step 5: Final commit**

```bash
git add -A
git commit -m "feat: complete member health & fitness tracking (health log, food log, workout logging, progress dashboard)"
```
