# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# This script wipes all data and creates 4 users connected together.

alias Fitconnex.Accounts.User
alias Fitconnex.Gym.{Gym, GymBranch, GymMember, GymTrainer}
alias Fitconnex.Billing.{SubscriptionPlan, MemberSubscription}

require Ash.Query

IO.puts("\n--- Wiping all existing data ---")

# Delete in dependency order to avoid FK violations
Fitconnex.Billing.MemberSubscription |> Ash.read!() |> Enum.each(&Ash.destroy!/1)
Fitconnex.Billing.SubscriptionPlan |> Ash.read!() |> Enum.each(&Ash.destroy!/1)
Fitconnex.Training.AttendanceRecord |> Ash.read!() |> Enum.each(&Ash.destroy!/1)
Fitconnex.Scheduling.ClassBooking |> Ash.read!() |> Enum.each(&Ash.destroy!/1)
Fitconnex.Scheduling.ScheduledClass |> Ash.read!() |> Enum.each(&Ash.destroy!/1)
Fitconnex.Scheduling.ClassDefinition |> Ash.read!() |> Enum.each(&Ash.destroy!/1)
Fitconnex.Training.WorkoutPlan |> Ash.read!() |> Enum.each(&Ash.destroy!/1)
Fitconnex.Training.DietPlan |> Ash.read!() |> Enum.each(&Ash.destroy!/1)
Fitconnex.Training.WorkoutPlanTemplate |> Ash.read!() |> Enum.each(&Ash.destroy!/1)
Fitconnex.Training.DietPlanTemplate |> Ash.read!() |> Enum.each(&Ash.destroy!/1)
Fitconnex.Gym.MemberInvitation |> Ash.read!() |> Enum.each(&Ash.destroy!/1)
Fitconnex.Gym.TrainerInvitation |> Ash.read!() |> Enum.each(&Ash.destroy!/1)
Fitconnex.Gym.GymMember |> Ash.read!() |> Enum.each(&Ash.destroy!/1)
Fitconnex.Gym.GymTrainer |> Ash.read!() |> Enum.each(&Ash.destroy!/1)
Fitconnex.Gym.GymBranch |> Ash.read!() |> Enum.each(&Ash.destroy!/1)
Fitconnex.Gym.Gym |> Ash.read!() |> Enum.each(&Ash.destroy!/1)
Fitconnex.Accounts.Token |> Ash.read!() |> Enum.each(&Ash.destroy!/1)
Fitconnex.Accounts.User |> Ash.read!() |> Enum.each(&Ash.destroy!/1)

IO.puts("All data wiped.\n")

# --- Helper ---
defmodule SeedHelper do
  def create_user(email, password, name) do
    {:ok, user} =
      Fitconnex.Accounts.User
      |> Ash.Changeset.for_create(:register_with_password, %{
        email: email,
        password: password,
        name: name
      })
      |> Ash.create()

    user
  end

  def set_role(user, role) do
    {:ok, user} =
      user
      |> Ash.Changeset.for_update(:update, %{role: role})
      |> Ash.update()

    user
  end
end

# ============================
# 1. Create the 4 users
# ============================
IO.puts("--- Creating users ---")

admin = SeedHelper.create_user("admin@fitconnex.com", "Password123!", "Admin User")
admin = SeedHelper.set_role(admin, :platform_admin)
IO.puts("  Created: admin@fitconnex.com (platform_admin)")

operator = SeedHelper.create_user("operator@fitconnex.com", "Password123!", "Gym Operator")
operator = SeedHelper.set_role(operator, :gym_operator)
IO.puts("  Created: operator@fitconnex.com (gym_operator)")

trainer = SeedHelper.create_user("trainer@fitconnex.com", "Password123!", "John Trainer")
trainer = SeedHelper.set_role(trainer, :trainer)
IO.puts("  Created: trainer@fitconnex.com (trainer)")

member = SeedHelper.create_user("member@fitconnex.com", "Password123!", "Jane Member")
member = SeedHelper.set_role(member, :member)
IO.puts("  Created: member@fitconnex.com (member)")

# ============================
# 2. Create Gym (owned by operator)
# ============================
IO.puts("\n--- Creating gym ---")

{:ok, gym} =
  Gym
  |> Ash.Changeset.for_create(:create, %{
    name: "FitZone Gym",
    slug: "fitzone-gym",
    description: "A premium fitness center with state-of-the-art equipment and expert trainers.",
    owner_id: operator.id
  })
  |> Ash.create()

# Verify the gym (admin would do this)
{:ok, gym} =
  gym
  |> Ash.Changeset.for_update(:update, %{status: :verified})
  |> Ash.update()

IO.puts("  Created gym: FitZone Gym (verified)")

# ============================
# 3. Create a branch
# ============================
IO.puts("\n--- Creating branch ---")

{:ok, branch} =
  GymBranch
  |> Ash.Changeset.for_create(:create, %{
    address: "123 Fitness Street, Downtown",
    city: "Mumbai",
    state: "Maharashtra",
    postal_code: "400001",
    is_primary: true,
    gym_id: gym.id
  })
  |> Ash.create()

IO.puts("  Created branch: Mumbai, Maharashtra")

# ============================
# 4. Add trainer to gym
# ============================
IO.puts("\n--- Adding trainer to gym ---")

{:ok, gym_trainer} =
  GymTrainer
  |> Ash.Changeset.for_create(:create, %{
    user_id: trainer.id,
    gym_id: gym.id,
    specializations: ["Weight Training", "HIIT", "Yoga"]
  })
  |> Ash.create()

IO.puts("  Added John Trainer to FitZone Gym")

# ============================
# 5. Add member to gym (assigned to trainer)
# ============================
IO.puts("\n--- Adding member to gym ---")

{:ok, gym_member} =
  GymMember
  |> Ash.Changeset.for_create(:create, %{
    user_id: member.id,
    gym_id: gym.id,
    assigned_trainer_id: trainer.id
  })
  |> Ash.create()

IO.puts("  Added Jane Member to FitZone Gym (trainer: John Trainer)")

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
  })
  |> Ash.create()

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
  })
  |> Ash.create()

IO.puts("  Subscribed Jane Member to Premium Monthly plan")

# ============================
# Summary
# ============================
IO.puts("""

========================================
  SEED COMPLETE
========================================

Login credentials (password for all: Password123!):

  Admin:        admin@fitconnex.com
  Gym Operator: operator@fitconnex.com
  Trainer:      trainer@fitconnex.com
  Member:       member@fitconnex.com

Connections:
  - FitZone Gym owned by Gym Operator (verified)
  - Branch: Mumbai, Maharashtra
  - John Trainer -> FitZone Gym (specializations: Weight Training, HIIT, Yoga)
  - Jane Member -> FitZone Gym (assigned to John Trainer)
  - Premium Monthly plan (Rs 2,999/month)
  - Jane Member subscribed (active, paid)

========================================
""")
