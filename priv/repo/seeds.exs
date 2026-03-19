# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# This script wipes all data and creates 3 users connected together.

alias FitTrackerz.Accounts.User
alias FitTrackerz.Gym.{Gym, GymBranch, GymMember, Contest}
alias FitTrackerz.Billing.{SubscriptionPlan, MemberSubscription}

require Ash.Query

IO.puts("\n--- Wiping all existing data ---")

# Use system actor to bypass authorization during seeding
system_actor = FitTrackerz.Accounts.SystemActor.system_actor()
seed_opts = [actor: system_actor, authorize?: false]

# Delete in dependency order to avoid FK violations
FitTrackerz.Billing.MemberSubscription |> Ash.read!(seed_opts) |> Enum.each(&Ash.destroy!(&1, seed_opts))
FitTrackerz.Billing.SubscriptionPlan |> Ash.read!(seed_opts) |> Enum.each(&Ash.destroy!(&1, seed_opts))
FitTrackerz.Gym.Contest |> Ash.read!(seed_opts) |> Enum.each(&Ash.destroy!(&1, seed_opts))
FitTrackerz.Training.AttendanceRecord |> Ash.read!(seed_opts) |> Enum.each(&Ash.destroy!(&1, seed_opts))
FitTrackerz.Scheduling.ClassBooking |> Ash.read!(seed_opts) |> Enum.each(&Ash.destroy!(&1, seed_opts))
FitTrackerz.Scheduling.ScheduledClass |> Ash.read!(seed_opts) |> Enum.each(&Ash.destroy!(&1, seed_opts))
FitTrackerz.Scheduling.ClassDefinition |> Ash.read!(seed_opts) |> Enum.each(&Ash.destroy!(&1, seed_opts))
FitTrackerz.Training.WorkoutPlan |> Ash.read!(seed_opts) |> Enum.each(&Ash.destroy!(&1, seed_opts))
FitTrackerz.Training.DietPlan |> Ash.read!(seed_opts) |> Enum.each(&Ash.destroy!(&1, seed_opts))
FitTrackerz.Training.WorkoutPlanTemplate |> Ash.read!(seed_opts) |> Enum.each(&Ash.destroy!(&1, seed_opts))
FitTrackerz.Training.DietPlanTemplate |> Ash.read!(seed_opts) |> Enum.each(&Ash.destroy!(&1, seed_opts))
FitTrackerz.Gym.MemberInvitation |> Ash.read!(seed_opts) |> Enum.each(&Ash.destroy!(&1, seed_opts))
FitTrackerz.Gym.GymMember |> Ash.read!(seed_opts) |> Enum.each(&Ash.destroy!(&1, seed_opts))
FitTrackerz.Gym.GymBranch |> Ash.read!(seed_opts) |> Enum.each(&Ash.destroy!(&1, seed_opts))
FitTrackerz.Gym.Gym |> Ash.read!(seed_opts) |> Enum.each(&Ash.destroy!(&1, seed_opts))
FitTrackerz.Accounts.Token |> Ash.read!(seed_opts) |> Enum.each(&Ash.destroy!(&1, seed_opts))
FitTrackerz.Accounts.User |> Ash.read!(seed_opts) |> Enum.each(&Ash.destroy!(&1, seed_opts))

IO.puts("All data wiped.\n")

# --- Helper ---
defmodule SeedHelper do
  @system_actor FitTrackerz.Accounts.SystemActor.system_actor()

  def create_user(email, password, name) do
    {:ok, user} =
      FitTrackerz.Accounts.User
      |> Ash.Changeset.for_create(:register_with_password, %{
        email: email,
        password: password,
        password_confirmation: password,
        name: name
      })
      |> Ash.create(actor: @system_actor, authorize?: false)

    user
  end

  def set_role(user, role) do
    {:ok, user} =
      user
      |> Ash.Changeset.for_update(:update, %{role: role})
      |> Ash.update(actor: @system_actor, authorize?: false)

    user
  end
end

# ============================
# 1. Create the 4 users
# ============================
IO.puts("--- Creating users ---")

admin = SeedHelper.create_user("admin@fittrackerz.com", "Password123!", "Admin User")
admin = SeedHelper.set_role(admin, :platform_admin)
IO.puts("  Created: admin@fittrackerz.com (platform_admin)")

operator = SeedHelper.create_user("operator@fittrackerz.com", "Password123!", "Gym Operator")
operator = SeedHelper.set_role(operator, :gym_operator)
IO.puts("  Created: operator@fittrackerz.com (gym_operator)")

member = SeedHelper.create_user("member@fittrackerz.com", "Password123!", "Jane Member")
member = SeedHelper.set_role(member, :member)
IO.puts("  Created: member@fittrackerz.com (member)")

# ============================
# 2. Create Gym (owned by operator)
# ============================
IO.puts("\n--- Creating gym ---")

{:ok, gym} =
  Gym
  |> Ash.Changeset.for_create(:create, %{
    name: "FitZone Gym",
    slug: "fitzone-gym",
    description: "A premium fitness center with state-of-the-art equipment.",
    owner_id: operator.id
  }, seed_opts)
  |> Ash.create(seed_opts)

# Verify the gym (admin would do this)
{:ok, gym} =
  gym
  |> Ash.Changeset.for_update(:update, %{status: :verified}, seed_opts)
  |> Ash.update(seed_opts)

IO.puts("  Created gym: FitZone Gym (verified)")

# ============================
# 3. Create a branch
# ============================
IO.puts("\n--- Creating branch ---")

{:ok, _branch} =
  GymBranch
  |> Ash.Changeset.for_create(:create, %{
    address: "123 Fitness Street, Downtown",
    city: "Mumbai",
    state: "Maharashtra",
    postal_code: "400001",
    gym_id: gym.id
  }, seed_opts)
  |> Ash.create(seed_opts)

IO.puts("  Created branch: Mumbai, Maharashtra")

# ============================
# 4. Add member to gym
# ============================
IO.puts("\n--- Adding member to gym ---")

{:ok, gym_member} =
  GymMember
  |> Ash.Changeset.for_create(:create, %{
    user_id: member.id,
    gym_id: gym.id
  }, seed_opts)
  |> Ash.create(seed_opts)

IO.puts("  Added Jane Member to FitZone Gym")

# ============================
# 6. Create a subscription plan
# ============================
IO.puts("\n--- Creating subscription plan ---")

{:ok, plan} =
  SubscriptionPlan
  |> Ash.Changeset.for_create(:create, %{
    name: "Premium Monthly",
    plan_type: :general,
    duration: :monthly,
    price_in_paise: 299_900,
    gym_id: gym.id
  }, seed_opts)
  |> Ash.create(seed_opts)

IO.puts("  Created plan: Premium Monthly (Rs 2,999/month)")

# ============================
# 7. Subscribe the member
# ============================
IO.puts("\n--- Creating member subscription ---")

now = DateTime.utc_now()
ends_at = DateTime.add(now, 30 * 24 * 3600, :second)

{:ok, _subscription} =
  MemberSubscription
  |> Ash.Changeset.for_create(:create, %{
    member_id: gym_member.id,
    subscription_plan_id: plan.id,
    gym_id: gym.id,
    starts_at: now,
    ends_at: ends_at,
    payment_status: :paid
  }, seed_opts)
  |> Ash.create(seed_opts)

IO.puts("  Subscribed Jane Member to Premium Monthly plan")

# ============================
# 8. Create contests
# ============================
IO.puts("\n--- Creating contests ---")

{:ok, _contest1} =
  Contest
  |> Ash.Changeset.for_create(:create, %{
    title: "30-Day Weight Loss Challenge",
    description: "Lose the most body fat percentage in 30 days. Weekly weigh-ins required. Top 3 winners get prizes!",
    contest_type: :challenge,
    status: :active,
    starts_at: DateTime.add(now, -5 * 24 * 3600, :second),
    ends_at: DateTime.add(now, 25 * 24 * 3600, :second),
    max_participants: 50,
    prize_description: "1st: 3 months free membership, 2nd: 1 month free, 3rd: FitZone merchandise",
    gym_id: gym.id
  }, seed_opts)
  |> Ash.create(seed_opts)

IO.puts("  Created contest: 30-Day Weight Loss Challenge (active)")

{:ok, _contest2} =
  Contest
  |> Ash.Changeset.for_create(:create, %{
    title: "Deadlift Championship 2026",
    description: "Annual deadlift competition. Weight classes: Lightweight (<70kg), Middleweight (70-90kg), Heavyweight (>90kg).",
    contest_type: :competition,
    status: :upcoming,
    starts_at: DateTime.add(now, 14 * 24 * 3600, :second),
    ends_at: DateTime.add(now, 14 * 24 * 3600 + 8 * 3600, :second),
    max_participants: 30,
    prize_description: "Trophies + cash prizes for each weight class",
    gym_id: gym.id
  }, seed_opts)
  |> Ash.create(seed_opts)

IO.puts("  Created contest: Deadlift Championship 2026 (upcoming)")

{:ok, _contest3} =
  Contest
  |> Ash.Changeset.for_create(:create, %{
    title: "FitZone Marathon Prep Camp",
    description: "8-week running preparation camp for the upcoming Mumbai Marathon. Includes 3 sessions per week with certified running coaches.",
    contest_type: :event,
    status: :upcoming,
    starts_at: DateTime.add(now, 30 * 24 * 3600, :second),
    ends_at: DateTime.add(now, 86 * 24 * 3600, :second),
    prize_description: "Completion certificates and finisher medals",
    gym_id: gym.id
  }, seed_opts)
  |> Ash.create(seed_opts)

IO.puts("  Created contest: FitZone Marathon Prep Camp (upcoming)")

# ============================
# Summary
# ============================
IO.puts("""

========================================
  SEED COMPLETE
========================================

Login credentials (password for all: Password123!):

  Admin:        admin@fittrackerz.com
  Gym Operator: operator@fittrackerz.com
  Member:       member@fittrackerz.com

Connections:
  - FitZone Gym owned by Gym Operator (verified)
  - Branch: Mumbai, Maharashtra
  - Jane Member -> FitZone Gym
  - Premium Monthly plan (Rs 2,999/month)
  - Jane Member subscribed (active, paid)
  - 3 Contests: Weight Loss Challenge (active), Deadlift Championship (upcoming), Marathon Prep (upcoming)

========================================
""")
