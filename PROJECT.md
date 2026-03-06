# Fit Trackerz - Fitness Platform

## Overview

Fit Trackerz is a comprehensive fitness management platform built with **Elixir**, **Phoenix Framework 1.8**, and **Ash Framework 3.0**. It connects gyms, trainers, and members through a single unified platform for managing memberships, scheduling classes, tracking workouts, creating diet plans, and handling billing.

---

## Technology Stack

| Layer            | Technology                                      |
| ---------------- | ----------------------------------------------- |
| Language         | Elixir 1.15+                                    |
| Web Framework    | Phoenix 1.8.3                                   |
| Domain Framework | Ash Framework 3.0                               |
| Database         | PostgreSQL 16+ with PostGIS                     |
| Real-time UI     | Phoenix LiveView 1.1.0                          |
| Authentication   | AshAuthentication 4.0 + bcrypt                  |
| CSS Framework    | Tailwind CSS 4.1 + DaisyUI                      |
| JS Bundler       | esbuild 0.25.4                                  |
| Email            | Swoosh 1.16                                     |
| Icons            | Heroicons                                       |

---

## Architecture

### Domain-Driven Design (Ash Framework)

The application is organized into **5 bounded contexts (domains)**, each encapsulating related business logic:

```
FitTrackerz
  |-- Accounts     (Users, Tokens, Authentication)
  |-- Gym          (Gyms, Branches, Members, Trainers, Invitations)
  |-- Billing      (Subscription Plans, Member Subscriptions)
  |-- Scheduling   (Class Definitions, Scheduled Classes, Bookings)
  |-- Training     (Workout Plans, Diet Plans, Templates, Attendance)
```

### Directory Structure

```
fit_trackerz/
  lib/
    fit_trackerz/                        # Backend (Business Logic)
      accounts/                       # User management & auth
        user.ex                       # User resource
        token.ex                      # JWT token resource
      accounts.ex                     # Accounts domain
      gym/                            # Gym operations
        gym.ex                        # Gym resource
        gym_branch.ex                 # Branch locations
        gym_member.ex                 # Member-gym link
        gym_trainer.ex                # Trainer-gym link
        member_invitation.ex          # Member invites
        trainer_invitation.ex         # Trainer invites
        changes/                      # Custom Ash changes
          create_gym_member_on_accept.ex
          create_gym_trainer_on_accept.ex
      gym.ex                          # Gym domain
      billing/                        # Payment & subscriptions
        subscription_plan.ex          # Plan definitions
        member_subscription.ex        # Active subscriptions
      billing.ex                      # Billing domain
      scheduling/                     # Class scheduling
        class_definition.ex           # Class types
        scheduled_class.ex            # Scheduled sessions
        class_booking.ex              # Member bookings
      scheduling.ex                   # Scheduling domain
      training/                       # Fitness plans
        exercise.ex                   # Exercise (embedded)
        meal.ex                       # Meal (embedded)
        workout_plan.ex               # Member workout plans
        workout_plan_template.ex      # Reusable workout templates
        diet_plan.ex                  # Member diet plans
        diet_plan_template.ex         # Reusable diet templates
        attendance_record.ex          # Gym attendance
        changes/
          copy_from_workout_template.ex
          copy_from_diet_template.ex
      training.ex                     # Training domain
      application.ex                  # OTP application
      repo.ex                         # Ecto repository
      mailer.ex                       # Email service
    fit_trackerz_web/                    # Frontend (Web Interface)
      controllers/
        page_controller.ex            # Landing page
        auth_controller.ex            # Auth callbacks
        page_html/
          home.html.heex              # Landing page template
        error_html.ex
        error_json.ex
      live/
        dashboard_live/index.ex       # Role-based redirect
        choose_role_live.ex           # Role selection
        admin/dashboard_live.ex       # Admin dashboard
        gym_operator/dashboard_live.ex # Gym operator dashboard
        trainer/dashboard_live.ex     # Trainer dashboard
        member/dashboard_live.ex      # Member dashboard
      components/
        core_components.ex            # Reusable UI components
        layouts.ex                    # App layout with navigation
        layouts/root.html.heex        # HTML root template
      router.ex                       # Route definitions
      endpoint.ex                     # Phoenix endpoint
      live_user_auth.ex               # LiveView auth hooks
      auth_overrides.ex               # Auth UI customization
  assets/
    css/app.css                       # Tailwind + DaisyUI styles
    js/app.js                         # LiveView + topbar JS
    vendor/                           # Third-party assets
  config/
    config.exs                        # Main config
    dev.exs                           # Development
    prod.exs                          # Production
    test.exs                          # Test
    runtime.exs                       # Runtime config
  priv/
    repo/migrations/                  # Database migrations
    resource_snapshots/               # Ash snapshots
    static/                           # Compiled assets
  test/                               # Test suite
```

---

## User Roles

| Role             | Description                              | Access Level |
| ---------------- | ---------------------------------------- | ------------ |
| `platform_admin` | System administrator                     | Full access  |
| `gym_operator`   | Gym owner/manager                        | Gym-scoped   |
| `trainer`        | Fitness trainer                          | Gym-scoped   |
| `member`         | Gym member (default for new signups)     | Self-scoped  |

### Role Hierarchy (Authorization)

- **Admin** routes: `platform_admin` only
- **Gym Operator** routes: `platform_admin`, `gym_operator`
- **Trainer** routes: `platform_admin`, `gym_operator`, `trainer`
- **Member** routes: All authenticated users

---

## Domain Resources

### 1. Accounts Domain

#### User

| Attribute         | Type       | Required | Default    | Notes                     |
| ----------------- | ---------- | -------- | ---------- | ------------------------- |
| `id`              | UUID       | auto     | generated  | Primary key               |
| `email`           | ci_string  | yes      | -          | Unique, case-insensitive  |
| `name`            | string     | yes      | "User"     |                           |
| `phone`           | string     | no       | -          |                           |
| `role`            | atom       | yes      | `:member`  | One of: `platform_admin`, `gym_operator`, `trainer`, `member` |
| `is_active`       | boolean    | yes      | `true`     |                           |
| `hashed_password` | string     | -        | -          | Sensitive, auto-managed   |

**Actions:** `:read`, `:create`, `:update`, `:destroy`

#### Token

JWT token storage managed by AshAuthentication. Stores session tokens with JTI-based primary keys.

---

### 2. Gym Domain

#### Gym

| Attribute     | Type       | Required | Default                 |
| ------------- | ---------- | -------- | ----------------------- |
| `id`          | UUID       | auto     | generated               |
| `name`        | string     | yes      | -                       |
| `slug`        | ci_string  | yes      | - (unique)              |
| `description` | string     | no       | -                       |
| `status`      | atom       | yes      | `:pending_verification` |
| `is_promoted` | boolean    | yes      | `false`                 |

**Status values:** `pending_verification`, `verified`, `suspended`
**Relationships:** `owner` (User), `branches`, `gym_members`, `gym_trainers`, `member_invitations`, `trainer_invitations`
**Actions:** `:read`, `:create`, `:update`, `:destroy`

#### GymBranch

| Attribute     | Type    | Required | Default |
| ------------- | ------- | -------- | ------- |
| `id`          | UUID    | auto     | -       |
| `address`     | string  | yes      | -       |
| `city`        | string  | yes      | -       |
| `state`       | string  | yes      | -       |
| `postal_code` | string  | yes      | -       |
| `latitude`    | float   | no       | -       |
| `longitude`   | float   | no       | -       |
| `is_primary`  | boolean | yes      | `false` |

**Belongs to:** Gym
**Actions:** `:read`, `:create`, `:update`, `:destroy`

#### GymMember

| Attribute            | Type    | Required | Default |
| -------------------- | ------- | -------- | ------- |
| `id`                 | UUID    | auto     | -       |
| `is_active`          | boolean | yes      | `true`  |

**Belongs to:** User, Gym, AssignedTrainer (optional User)
**Identity:** Unique per `user_id` + `gym_id`
**Actions:** `:read`, `:create`, `:update`, `:destroy`

#### GymTrainer

| Attribute        | Type           | Required | Default |
| ---------------- | -------------- | -------- | ------- |
| `id`             | UUID           | auto     | -       |
| `specializations`| string array   | no       | `[]`   |
| `is_active`      | boolean        | yes      | `true`  |

**Belongs to:** User, Gym
**Identity:** Unique per `user_id` + `gym_id`
**Actions:** `:read`, `:create`, `:update`, `:destroy`

#### MemberInvitation

| Attribute       | Type      | Required | Default    |
| --------------- | --------- | -------- | ---------- |
| `id`            | UUID      | auto     | -          |
| `invited_email` | ci_string | yes      | -          |
| `status`        | atom      | yes      | `:pending` |

**Status values:** `pending`, `accepted`, `rejected`, `expired`
**Custom Actions:**
- `:accept` - Sets status to `:accepted`, triggers `CreateGymMemberOnAccept` change
- `:reject` - Sets status to `:rejected`
- `:expire` - Sets status to `:expired`

#### TrainerInvitation

Same structure as MemberInvitation. On `:accept`, triggers `CreateGymTrainerOnAccept` change.

---

### 3. Billing Domain

#### SubscriptionPlan

| Attribute        | Type    | Required |
| ---------------- | ------- | -------- |
| `id`             | UUID    | auto     |
| `name`           | string  | yes      |
| `plan_type`      | atom    | yes      |
| `duration`       | atom    | yes      |
| `price_in_paise` | integer | yes      |

**Plan types:** `general`, `personal_training`
**Durations:** `day_pass`, `monthly`, `quarterly`, `half_yearly`, `annual`, `two_year`
**Belongs to:** Gym

#### MemberSubscription

| Attribute        | Type     | Required | Default    |
| ---------------- | -------- | -------- | ---------- |
| `id`             | UUID     | auto     | -          |
| `status`         | atom     | yes      | `:active`  |
| `starts_at`      | datetime | yes      | -          |
| `ends_at`        | datetime | yes      | -          |
| `payment_status` | atom     | yes      | `:pending` |

**Status values:** `active`, `cancelled`, `expired`
**Payment status:** `pending`, `paid`, `failed`, `refunded`
**Custom Actions:** `:cancel` - Sets status to `:cancelled`

---

### 4. Scheduling Domain

#### ClassDefinition

| Attribute                 | Type    | Required |
| ------------------------- | ------- | -------- |
| `id`                      | UUID    | auto     |
| `name`                    | string  | yes      |
| `class_type`              | string  | yes      |
| `default_duration_minutes`| integer | yes      |
| `max_participants`        | integer | no       |

**Belongs to:** Gym

#### ScheduledClass

| Attribute          | Type     | Required | Default      |
| ------------------ | -------- | -------- | ------------ |
| `id`               | UUID     | auto     | -            |
| `scheduled_at`     | datetime | yes      | -            |
| `duration_minutes` | integer  | yes      | -            |
| `status`           | atom     | yes      | `:scheduled` |

**Status values:** `scheduled`, `completed`, `cancelled`
**Custom Actions:** `:complete`, `:cancel`
**Belongs to:** ClassDefinition, Branch (GymBranch), Trainer (User, optional)

#### ClassBooking

| Attribute | Type | Required | Default    |
| --------- | ---- | -------- | ---------- |
| `id`      | UUID | auto     | -          |
| `status`  | atom | yes      | `:pending` |

**Status values:** `pending`, `confirmed`, `declined`, `cancelled`
**Custom Actions:** `:confirm`, `:decline`, `:cancel`
**Identity:** Unique per `scheduled_class_id` + `member_id`

---

### 5. Training Domain

#### Exercise (Embedded Resource)

| Attribute          | Type    | Required |
| ------------------ | ------- | -------- |
| `name`             | string  | yes      |
| `sets`             | integer | no       |
| `reps`             | integer | no       |
| `duration_seconds` | integer | no       |
| `rest_seconds`     | integer | no       |
| `order`            | integer | yes      |

Used as embedded array in WorkoutPlan and WorkoutPlanTemplate.

#### Meal (Embedded Resource)

| Attribute     | Type          | Required |
| ------------- | ------------- | -------- |
| `name`        | string        | yes      |
| `time_of_day` | string        | yes      |
| `items`       | string array  | no       |
| `calories`    | integer       | no       |
| `protein`     | float         | no       |
| `carbs`       | float         | no       |
| `fat`         | float         | no       |
| `order`       | integer       | yes      |

Used as embedded array in DietPlan and DietPlanTemplate.

#### WorkoutPlan

| Attribute   | Type            | Required | Default |
| ----------- | --------------- | -------- | ------- |
| `id`        | UUID            | auto     | -       |
| `name`      | string          | yes      | -       |
| `exercises` | Exercise array  | no       | `[]`    |

**Belongs to:** Member (GymMember), Gym, Trainer (User, optional), Template (optional)
**Custom Actions:** `:create_from_template` - Copies exercises from a WorkoutPlanTemplate

#### WorkoutPlanTemplate

| Attribute         | Type           | Required | Default |
| ----------------- | -------------- | -------- | ------- |
| `id`              | UUID           | auto     | -       |
| `name`            | string         | yes      | -       |
| `exercises`       | Exercise array | no       | `[]`    |
| `difficulty_level`| atom           | no       | -       |

**Difficulty levels:** `beginner`, `intermediate`, `advanced`

#### DietPlan

| Attribute        | Type       | Required | Default |
| ---------------- | ---------- | -------- | ------- |
| `id`             | UUID       | auto     | -       |
| `name`           | string     | yes      | -       |
| `meals`          | Meal array | no       | `[]`    |
| `calorie_target` | integer    | no       | -       |
| `dietary_type`   | atom       | no       | -       |

**Dietary types:** `vegetarian`, `non_vegetarian`, `vegan`, `eggetarian`
**Custom Actions:** `:create_from_template`

#### DietPlanTemplate

Same structure as DietPlan (without member/trainer relationships). Created by trainers or gym operators.

#### AttendanceRecord

| Attribute     | Type     | Required |
| ------------- | -------- | -------- |
| `id`          | UUID     | auto     |
| `attended_at` | datetime | yes      |
| `notes`       | string   | no       |

**Belongs to:** Member (GymMember), Gym, MarkedBy (User, optional)

---

## Authentication Flow

1. **Registration** (`/register`): User creates account with email/password. Default role is `member`.
2. **Role Selection** (`/choose-role`): New users choose their role (Member, Trainer, Gym Operator).
3. **Sign In** (`/sign-in`): Existing users authenticate with email/password.
4. **Session Management**: JWT tokens stored in database via AshAuthentication.TokenResource.
5. **Dashboard Redirect** (`/dashboard`): Authenticated users are redirected to their role-specific dashboard.

### Route Structure

| Path                | Access           | Description              |
| ------------------- | ---------------- | ------------------------ |
| `/`                 | Public           | Landing page             |
| `/sign-in`          | Public           | Sign in form             |
| `/register`         | Public           | Registration form        |
| `/sign-out`         | Authenticated    | Sign out                 |
| `/dashboard`        | Authenticated    | Role-based redirect      |
| `/choose-role`      | Authenticated    | Role selection           |
| `/admin/dashboard`  | Admin only       | Admin dashboard          |
| `/gym/dashboard`    | Gym operators    | Gym operator dashboard   |
| `/trainer/dashboard`| Trainers         | Trainer dashboard        |
| `/member/dashboard` | All members      | Member dashboard         |

---

## Database

### PostgreSQL Extensions

- **uuid-ossp**: UUID generation for primary keys
- **citext**: Case-insensitive text columns
- **postgis**: Geospatial queries for gym branch locations

### Tables

| Table                    | Domain     | Description                    |
| ------------------------ | ---------- | ------------------------------ |
| `users`                  | Accounts   | User accounts                  |
| `tokens`                 | Accounts   | JWT authentication tokens      |
| `gyms`                   | Gym        | Gym entities                   |
| `gym_branches`           | Gym        | Physical locations             |
| `gym_members`            | Gym        | User-gym memberships           |
| `gym_trainers`           | Gym        | Trainer-gym associations       |
| `member_invitations`     | Gym        | Pending member invites         |
| `trainer_invitations`    | Gym        | Pending trainer invites        |
| `subscription_plans`     | Billing    | Available subscription tiers   |
| `member_subscriptions`   | Billing    | Active member subscriptions    |
| `class_definitions`      | Scheduling | Class type definitions         |
| `scheduled_classes`      | Scheduling | Individual class sessions      |
| `class_bookings`         | Scheduling | Member class reservations      |
| `workout_plans`          | Training   | Member workout plans (JSON)    |
| `workout_plan_templates` | Training   | Reusable workout templates     |
| `diet_plans`             | Training   | Member nutrition plans (JSON)  |
| `diet_plan_templates`    | Training   | Reusable diet templates        |
| `attendance_records`     | Training   | Gym check-in records           |

---

## Setup & Development

### Prerequisites

- Elixir 1.15+
- Erlang/OTP 26+
- PostgreSQL 16+ with PostGIS extension
- Node.js (for asset compilation)

### Getting Started

```bash
# Install dependencies
mix deps.get

# Create and migrate database
mix ash.setup

# Start development server
mix phx.server
```

The application will be available at `http://localhost:4000`.

### Useful Commands

```bash
# Run tests
mix test

# Pre-commit checks (format, compile, credo)
mix precommit

# Generate a new migration
mix ash.codegen migration_name

# Reset database
mix ash.reset

# Interactive console
iex -S mix
```

---

## Frontend Architecture

### Layout System

- **Root Layout** (`root.html.heex`): HTML skeleton with theme switching (light/dark/system)
- **App Layout** (`layouts.ex:app/1`): Authenticated layout with sidebar navigation
- **Core Components** (`core_components.ex`): Reusable UI primitives (buttons, inputs, tables, flash messages, icons)

### Theming

- DaisyUI themes with custom color palettes
- Light and dark mode with system preference detection
- Theme toggle persisted in localStorage

### LiveView Pages

Each role has a dedicated dashboard LiveView:
- `FitTrackerzWeb.Admin.DashboardLive` - Platform statistics and management
- `FitTrackerzWeb.GymOperator.DashboardLive` - Gym management hub
- `FitTrackerzWeb.Trainer.DashboardLive` - Client and class management
- `FitTrackerzWeb.Member.DashboardLive` - Personal fitness dashboard

---

## Key Design Decisions

1. **Ash Framework**: Provides declarative resource definitions, built-in CRUD, and domain separation
2. **Embedded Resources**: Exercises and Meals stored as JSON arrays for flexibility
3. **Invitation System**: Separate invitation resources with custom accept changes that auto-create memberships
4. **Price in Paise**: Currency stored as integers (smallest unit) to avoid floating-point issues
5. **CI Strings**: Case-insensitive emails and slugs via PostgreSQL citext extension
6. **PostGIS**: Geospatial support for gym branch locations and proximity searches
7. **Template System**: Workout and diet plan templates that can be copied to create member-specific plans
