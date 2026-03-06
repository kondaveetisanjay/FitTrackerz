# Fit Trackerz

**Fit Trackerz** is a comprehensive gym management and discovery platform built with **Phoenix LiveView** and **Ash Framework 3.0**. It connects gym operators, trainers, and fitness enthusiasts in one unified ecosystem — eliminating the hassle of visiting multiple gyms to compare prices and services.

## 🎯 Features

### 🌍 Public Gym Discovery
- **Browse gyms without signing up** — explore verified gyms, compare prices, and view services
- **Geolocation-based sorting** — find gyms near you with real-time distance calculation
- **Google Maps integration**:
  - Places Autocomplete for easy address entry
  - Reverse geocoding for location detection
  - Direct links to gym locations on Google Maps
- **Advanced filtering** — search by gym name, filter by city, sort by distance
- **Detailed gym pages** — view locations, plans, classes, trainer specializations

### 🏋️ Gym Operator Dashboard
- **Gym setup & management** — create gym profile with description, logo, and verification status
- **Branch management** — add multiple locations with Google Places Autocomplete integration
- **Subscription plans** — create and edit plans (1 Day Pass, 1 Month, 3 Months, 6 Months, 12 Months, 24 Months)
- **Trainer management** — invite trainers with specializations (Yoga, CrossFit, Powerlifting, etc.)
- **Member invitations** — invite members via email with automatic role assignment
- **Class scheduling** — define class types (Yoga, Pilates, HIIT, etc.) with duration and capacity
- **Attendance tracking** — record and monitor member attendance

### 👤 Member Portal
- **Workout plans** — view personalized workout plans assigned by trainers
- **Diet plans** — access custom diet plans with meal breakdowns
- **Class browsing & booking** — discover and book group fitness classes
- **Subscription management** — view active subscription details and pricing
- **Attendance history** — track your gym attendance records

### 🎓 Trainer Portal
- **Client management** — view assigned clients and their progress
- **Workout plan creation** — create custom workout plans from templates
- **Diet plan creation** — design personalized diet plans from templates
- **Template library** — save and reuse workout/diet templates
- **Class schedule** — manage assigned classes and schedules
- **Attendance tracking** — mark client attendance

### 🛡️ Platform Admin
- **User management** — view and manage all users (members, trainers, operators, admins)
- **Gym verification** — review and verify gym registrations
- **System oversight** — monitor platform activity and statistics

## 🛠️ Tech Stack

- **Backend**: Elixir 1.17+ with Phoenix Framework 1.8
- **Frontend**: Phoenix LiveView (real-time SPA-like UX without JavaScript frameworks)
- **Database**: PostgreSQL with PostGIS extension for geospatial queries
- **ORM**: Ash Framework 3.0 (declarative resource modeling with built-in authorization)
- **Authentication**: AshAuthentication with role-based access control
- **UI**: DaisyUI + Tailwind CSS 4 (responsive, themeable components)
- **APIs**: Google Maps JavaScript API (Places, Geocoding)

## 🏗️ Architecture

### Domain Structure
- **Accounts** — User authentication, tokens, role management
- **Gym** — Gyms, branches, members, trainers, invitations, geolocation
- **Billing** — Subscription plans, member subscriptions
- **Scheduling** — Class definitions, scheduled classes, bookings
- **Training** — Workout plans, diet plans, templates, attendance records

### Role-Based Access
- **platform_admin** — Full system access
- **gym_operator** — Manage own gym, branches, members, trainers, plans, classes
- **trainer** — Manage clients, create workout/diet plans, track attendance
- **member** — View plans, book classes, track progress

## 🚀 Getting Started

### Prerequisites
- Elixir 1.17+
- Erlang/OTP 27+
- PostgreSQL 16+ with PostGIS extension
- Node.js 18+ (for asset compilation)
- Google Maps API key (for Places and Geocoding APIs)

### Installation

1. Clone the repository:
```bash
git clone https://github.com/jkreddy020203/fit_trackerz.git
cd fit_trackerz
```

2. Install dependencies:
```bash
mix setup
```

3. Configure environment variables:
```bash
# config/dev.exs or config/runtime.exs
config :fit_trackerz, :google_maps_api_key, "YOUR_GOOGLE_MAPS_API_KEY"
```

4. Create and migrate the database:
```bash
mix ecto.setup
```

5. Start the Phoenix server:
```bash
mix phx.server
```

Visit [`http://localhost:4000`](http://localhost:4000) in your browser.

### Seed Data (Optional)
To populate the database with sample gyms and users:
```bash
mix run priv/repo/seeds.exs
```

## 📦 Key Dependencies

- `phoenix` ~> 1.8 — Web framework
- `phoenix_live_view` ~> 1.0 — Real-time UI
- `ash` ~> 3.0 — Resource modeling and authorization
- `ash_postgres` ~> 2.0 — PostgreSQL data layer for Ash
- `ash_authentication` ~> 4.0 — Authentication & user management
- `ash_authentication_phoenix` ~> 2.0 — LiveView authentication helpers
- `postgrex` ~> 0.19 — PostgreSQL driver
- `geo_postgis` ~> 3.6 — PostGIS geometry types

## 🗂️ Project Structure

```
fit_trackerz/
├── lib/
│   ├── fit_trackerz/              # Business logic domains
│   │   ├── accounts/           # User auth & roles
│   │   ├── gym/                # Gyms, branches, members, trainers
│   │   ├── billing/            # Plans & subscriptions
│   │   ├── scheduling/         # Classes & bookings
│   │   └── training/           # Workout & diet plans
│   └── fit_trackerz_web/          # Web interface
│       ├── live/               # LiveView pages
│       │   ├── admin/          # Admin dashboard
│       │   ├── gym_operator/   # Gym operator portal
│       │   ├── trainer/        # Trainer portal
│       │   ├── member/         # Member portal
│       │   └── explore/        # Public gym discovery
│       ├── components/         # Reusable UI components
│       └── controllers/        # HTTP controllers
├── priv/
│   ├── repo/migrations/        # Database migrations
│   └── static/                 # Static assets
├── assets/                     # Frontend assets (CSS, JS)
└── test/                       # Tests
```

## 🌐 Routes

### Public Routes
- `/` — Landing page
- `/explore` — Browse gyms (no auth required)
- `/explore/:slug` — Gym detail page
- `/sign-in` — Sign in
- `/register` — Sign up
- `/reset-password` — Password reset

### Authenticated Routes
- `/dashboard` — Role-based dashboard redirect
- `/choose-role` — Role selection (if user has no role)

#### Platform Admin
- `/admin/dashboard` — Admin overview
- `/admin/users` — User management
- `/admin/gyms` — Gym verification

#### Gym Operator
- `/gym/dashboard` — Gym operator overview
- `/gym/setup` — Gym profile setup
- `/gym/branches` — Branch management
- `/gym/plans` — Subscription plans
- `/gym/members` — Member management
- `/gym/trainers` — Trainer management
- `/gym/classes` — Class definitions
- `/gym/invitations` — Member/trainer invitations
- `/gym/attendance` — Attendance records

#### Trainer
- `/trainer/dashboard` — Trainer overview
- `/trainer/clients` — Client list
- `/trainer/workouts` — Workout plan management
- `/trainer/diets` — Diet plan management
- `/trainer/templates` — Workout/diet templates
- `/trainer/classes` — Assigned classes
- `/trainer/attendance` — Attendance tracking

#### Member
- `/member/dashboard` — Member overview
- `/member/workout` — View workout plan
- `/member/diet` — View diet plan
- `/member/classes` — Browse classes
- `/member/bookings` — Class bookings
- `/member/subscription` — Subscription details
- `/member/attendance` — Attendance history

## 🔑 Environment Variables

Create a `.env` file or set in `config/runtime.exs`:

```elixir
config :fit_trackerz, :google_maps_api_key, System.get_env("GOOGLE_MAPS_API_KEY")

config :fit_trackerz, FitTrackerz.Repo,
  url: System.get_env("DATABASE_URL"),
  pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10")

config :fit_trackerz, FitTrackerzWeb.Endpoint,
  secret_key_base: System.get_env("SECRET_KEY_BASE")
```

## 🧪 Testing

Run the test suite:
```bash
mix test
```

Run with coverage:
```bash
mix test --cover
```

## 📝 License

This project is private and proprietary.

## 👥 Contributors

- **Karthik Reddy** ([@jkreddy020203](https://github.com/jkreddy020203)) — Developer
- **Claude Sonnet 4.5** — AI Pair Programmer

## 🙏 Acknowledgments

Built with:
- [Phoenix Framework](https://phoenixframework.org/)
- [Ash Framework](https://ash-hq.org/)
- [DaisyUI](https://daisyui.com/)
- [Tailwind CSS](https://tailwindcss.com/)
- [Google Maps Platform](https://developers.google.com/maps)

---

**Fit Trackerz** — Connecting fitness, one gym at a time. 💪
