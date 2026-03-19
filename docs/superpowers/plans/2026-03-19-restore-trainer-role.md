# Restore Trainer Role Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restore the trainer role and all its functionality that was removed in commit 71475ed, adapted from the old Fitconnex namespace to the current FitTrackerz namespace.

**Architecture:** The trainer is a separate user role (like gym_operator or member). Trainers are linked to gyms via a GymTrainer join resource. Gym operators invite trainers via TrainerInvitation. Members can be assigned to trainers via ClientAssignmentRequest. Trainers get their own dashboard, LiveViews for managing workouts/diets/templates/classes/attendance, and sidebar navigation.

**Tech Stack:** Elixir, Phoenix LiveView, Ash Framework, AshPostgres, AshAuthentication, TailwindCSS + DaisyUI

---

## File Structure

### New Files to Create

| File | Responsibility |
|------|---------------|
| `priv/repo/migrations/YYYYMMDDHHMMSS_restore_trainer_functionality.exs` | DB migration to restore trainer tables and columns |
| `lib/fit_trackerz/gym/gym_trainer.ex` | Ash resource: GymTrainer (links user to gym as trainer) |
| `lib/fit_trackerz/gym/trainer_invitation.ex` | Ash resource: TrainerInvitation (invite trainers by email) |
| `lib/fit_trackerz/gym/client_assignment_request.ex` | Ash resource: ClientAssignmentRequest (assign members to trainers) |
| `lib/fit_trackerz/gym/changes/assign_trainer_on_accept.ex` | Change module: assigns trainer to member on acceptance |
| `lib/fit_trackerz/gym/changes/create_gym_trainer_on_accept.ex` | Change module: creates GymTrainer record when invitation accepted |
| `lib/fit_trackerz_web/live/trainer/dashboard_live.ex` | Trainer dashboard LiveView |
| `lib/fit_trackerz_web/live/trainer/gyms_live.ex` | Trainer: list associated gyms |
| `lib/fit_trackerz_web/live/trainer/gym_detail_live.ex` | Trainer: gym detail view |
| `lib/fit_trackerz_web/live/trainer/clients_live.ex` | Trainer: list assigned clients |
| `lib/fit_trackerz_web/live/trainer/workouts_live.ex` | Trainer: manage workout plans |
| `lib/fit_trackerz_web/live/trainer/diets_live.ex` | Trainer: manage diet plans |
| `lib/fit_trackerz_web/live/trainer/templates_live.ex` | Trainer: manage workout/diet templates |
| `lib/fit_trackerz_web/live/trainer/classes_live.ex` | Trainer: view/manage scheduled classes |
| `lib/fit_trackerz_web/live/trainer/attendance_live.ex` | Trainer: mark/track client attendance |
| `lib/fit_trackerz_web/live/gym_operator/trainers_live.ex` | Gym operator: manage trainers |
| `lib/fit_trackerz_web/live/member/trainer_live.ex` | Member: view assigned trainer |
| `lib/fit_trackerz_web/controllers/page_html/solutions_trainers.html.heex` | Public marketing page for trainers |

### Existing Files to Modify

| File | Changes |
|------|---------|
| `lib/fit_trackerz/accounts/user.ex` | Add `:trainer` to role enum |
| `lib/fit_trackerz/gym.ex` | Add GymTrainer, TrainerInvitation, ClientAssignmentRequest resources + domain functions |
| `lib/fit_trackerz/gym/gym.ex` | Add `has_many :gym_trainers` and `has_many :trainer_invitations` relationships + update `list_by_owner` preloads |
| `lib/fit_trackerz/gym/gym_branch.ex` | Add `has_many :gym_trainers` relationship |
| `lib/fit_trackerz/gym/gym_member.ex` | Add `belongs_to :assigned_trainer` relationship + `list_by_assigned_trainer` action |
| `lib/fit_trackerz/training/workout_plan.ex` | Add `belongs_to :trainer` relationship + `list_by_trainer` action |
| `lib/fit_trackerz/training/diet_plan.ex` | Add `belongs_to :trainer` relationship + `list_by_trainer` action |
| `lib/fit_trackerz/scheduling/scheduled_class.ex` | Add `belongs_to :trainer` relationship + `list_by_trainer` action |
| `lib/fit_trackerz/scheduling/class_booking.ex` | Add `:trainer` to policies + restore trainer preload in `list_by_member` |
| `lib/fit_trackerz/training/attendance_record.ex` | Add `:trainer` to policies |
| `lib/fit_trackerz/training/workout_plan_template.ex` | Add `:trainer` to policies |
| `lib/fit_trackerz/training/diet_plan_template.ex` | Add `:trainer` to policies |
| `lib/fit_trackerz/training.ex` | Add `list_workouts_by_trainer` and `list_diets_by_trainer` domain functions |
| `lib/fit_trackerz/scheduling.ex` | Add `list_classes_by_trainer` domain function |
| `lib/fit_trackerz_web/router.ex` | Add trainer route scope + `/solutions/trainers` + gym operator `/trainers` + member `/trainer` |
| `lib/fit_trackerz_web/live_user_auth.ex` | Add `live_trainer_required` hook + add `:trainer` to `live_member_required` |
| `lib/fit_trackerz_web/components/layouts.ex` | Add trainer sidebar nav + `:trainer` format_role + gym_operator "Trainers" link + member "My Trainer" link |
| `lib/fit_trackerz_web/controllers/auth_controller.ex` | Add `:trainer` dashboard path |
| `lib/fit_trackerz_web/live/choose_role_live.ex` | Add trainer as a choosable role |
| `lib/fit_trackerz_web/live/dashboard_live/index.ex` | Add `:trainer` redirect |
| `lib/fit_trackerz_web/helpers/load_options.ex` | Add trainer preload helpers + update existing preloads with trainer data |
| `lib/fit_trackerz_web/controllers/page_controller.ex` | Add `solutions_trainers` action |

---

## Task 1: Database Migration

**Files:**
- Create: `priv/repo/migrations/YYYYMMDDHHMMSS_restore_trainer_functionality.exs`

This migration reverses the removal migration. It re-creates tables and re-adds columns.

- [ ] **Step 1: Create the migration file**

```bash
mix ecto.gen.migration restore_trainer_functionality
```

- [ ] **Step 2: Write the migration**

Replace the generated migration content with:

```elixir
defmodule FitTrackerz.Repo.Migrations.RestoreTrainerFunctionality do
  @moduledoc """
  Restore all trainer-related tables, columns, and references.
  """
  use Ecto.Migration

  def up do
    # 1. Create gym_trainers table
    create table(:gym_trainers, primary_key: false) do
      add :id, :uuid, null: false, primary_key: true
      add :user_id, references(:users, type: :uuid, on_delete: :delete_all), null: false
      add :gym_id, references(:gyms, type: :uuid, on_delete: :delete_all), null: false
      add :branch_id, references(:gym_branches, type: :uuid, on_delete: :nilify_all)
      add :specializations, {:array, :text}, default: []
      add :is_active, :boolean, default: true, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:gym_trainers, [:user_id])
    create index(:gym_trainers, [:gym_id])
    create index(:gym_trainers, [:branch_id])
    create unique_index(:gym_trainers, [:user_id, :gym_id])

    # 2. Add trainer_id to scheduled_classes
    alter table(:scheduled_classes) do
      add :trainer_id, references(:gym_trainers, type: :uuid, on_delete: :nilify_all)
    end

    create index(:scheduled_classes, [:trainer_id])

    # 3. Add trainer_id to workout_plans
    alter table(:workout_plans) do
      add :trainer_id, references(:gym_trainers, type: :uuid, on_delete: :nilify_all)
    end

    create index(:workout_plans, [:trainer_id])

    # 4. Add trainer_id to diet_plans
    alter table(:diet_plans) do
      add :trainer_id, references(:gym_trainers, type: :uuid, on_delete: :nilify_all)
    end

    create index(:diet_plans, [:trainer_id])

    # 5. Add assigned_trainer_id to gym_members
    alter table(:gym_members) do
      add :assigned_trainer_id, references(:gym_trainers, type: :uuid, on_delete: :nilify_all)
    end

    create index(:gym_members, [:assigned_trainer_id])

    # 6. Create trainer_invitations table
    create table(:trainer_invitations, primary_key: false) do
      add :id, :uuid, null: false, primary_key: true
      add :invited_email, :citext, null: false
      add :status, :text, null: false, default: "pending"
      add :gym_id, references(:gyms, type: :uuid, on_delete: :delete_all), null: false
      add :invited_by_id, references(:users, type: :uuid, on_delete: :nilify_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:trainer_invitations, [:gym_id])
    create index(:trainer_invitations, [:invited_email])

    # 7. Create client_assignment_requests table
    create table(:client_assignment_requests, primary_key: false) do
      add :id, :uuid, null: false, primary_key: true
      add :status, :text, null: false, default: "pending"
      add :gym_id, references(:gyms, type: :uuid, on_delete: :delete_all), null: false
      add :member_id, references(:gym_members, type: :uuid, on_delete: :delete_all), null: false
      add :trainer_id, references(:gym_trainers, type: :uuid, on_delete: :delete_all), null: false
      add :requested_by_id, references(:users, type: :uuid, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:client_assignment_requests, [:gym_id])
    create index(:client_assignment_requests, [:member_id])
    create index(:client_assignment_requests, [:trainer_id])
  end

  def down do
    drop_if_exists table(:client_assignment_requests)
    drop_if_exists table(:trainer_invitations)

    drop_if_exists index(:gym_members, [:assigned_trainer_id])
    alter table(:gym_members) do
      remove_if_exists :assigned_trainer_id, :uuid
    end

    drop_if_exists index(:workout_plans, [:trainer_id])
    alter table(:workout_plans) do
      remove_if_exists :trainer_id, :uuid
    end

    drop_if_exists index(:diet_plans, [:trainer_id])
    alter table(:diet_plans) do
      remove_if_exists :trainer_id, :uuid
    end

    drop_if_exists index(:scheduled_classes, [:trainer_id])
    alter table(:scheduled_classes) do
      remove_if_exists :trainer_id, :uuid
    end

    drop_if_exists table(:gym_trainers)
  end
end
```

- [ ] **Step 3: Run the migration**

```bash
mix ecto.migrate
```

Expected: Migration runs successfully, tables created.

- [ ] **Step 4: Commit**

```bash
git add priv/repo/migrations/*restore_trainer*
git commit -m "Add migration to restore trainer tables and columns"
```

---

## Task 2: Ash Resources — GymTrainer, TrainerInvitation, ClientAssignmentRequest, Change Modules

**Files:**
- Create: `lib/fit_trackerz/gym/gym_trainer.ex`
- Create: `lib/fit_trackerz/gym/trainer_invitation.ex`
- Create: `lib/fit_trackerz/gym/client_assignment_request.ex`
- Create: `lib/fit_trackerz/gym/changes/assign_trainer_on_accept.ex`
- Create: `lib/fit_trackerz/gym/changes/create_gym_trainer_on_accept.ex`

- [ ] **Step 1: Create `lib/fit_trackerz/gym/gym_trainer.ex`**

```elixir
defmodule FitTrackerz.Gym.GymTrainer do
  use Ash.Resource,
    domain: FitTrackerz.Gym,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("gym_trainers")
    repo(FitTrackerz.Repo)

    references do
      reference :gym, on_delete: :delete
      reference :user, on_delete: :delete
      reference :branch, on_delete: :nilify
    end

    custom_indexes do
      index([:user_id])
      index([:gym_id])
      index([:branch_id])
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
      authorize_if actor_attribute_equals(:role, :gym_operator)
    end
  end

  actions do
    defaults([:read, :destroy])

    read :list_active_by_user do
      argument :user_id, :uuid, allow_nil?: false
      filter expr(user_id == ^arg(:user_id) and is_active == true)
      prepare build(load: [:gym])
    end

    read :list_by_gym do
      argument :gym_id, :uuid, allow_nil?: false
      filter expr(gym_id == ^arg(:gym_id))
      prepare build(load: [:user])
    end

    read :list_active_by_gym do
      argument :gym_id, :uuid, allow_nil?: false
      filter expr(gym_id == ^arg(:gym_id) and is_active == true)
      prepare build(load: [:user])
    end

    create :create do
      accept([:user_id, :gym_id, :specializations, :branch_id])
    end

    update :update do
      accept([:specializations, :is_active, :branch_id])
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute :specializations, {:array, :string} do
      default([])
    end

    attribute :is_active, :boolean do
      allow_nil?(false)
      default(true)
    end

    timestamps()
  end

  relationships do
    belongs_to :user, FitTrackerz.Accounts.User do
      allow_nil?(false)
    end

    belongs_to :gym, FitTrackerz.Gym.Gym do
      allow_nil?(false)
    end

    belongs_to :branch, FitTrackerz.Gym.GymBranch

    has_many :scheduled_classes, FitTrackerz.Scheduling.ScheduledClass do
      destination_attribute(:trainer_id)
    end

    has_many :workout_plans, FitTrackerz.Training.WorkoutPlan do
      destination_attribute(:trainer_id)
    end

    has_many :diet_plans, FitTrackerz.Training.DietPlan do
      destination_attribute(:trainer_id)
    end

    has_many :assigned_members, FitTrackerz.Gym.GymMember do
      destination_attribute(:assigned_trainer_id)
    end
  end

  identities do
    identity(:unique_trainer_gym, [:user_id, :gym_id])
  end
end
```

- [ ] **Step 2: Create `lib/fit_trackerz/gym/trainer_invitation.ex`**

```elixir
defmodule FitTrackerz.Gym.TrainerInvitation do
  use Ash.Resource,
    domain: FitTrackerz.Gym,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("trainer_invitations")
    repo(FitTrackerz.Repo)

    identity_wheres_to_sql unique_pending_invitation: "status = 'pending'"

    references do
      reference :gym, on_delete: :delete
      reference :invited_by, on_delete: :nilify
    end

    custom_indexes do
      index([:gym_id])
      index([:invited_email])
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
      authorize_if actor_attribute_equals(:role, :gym_operator)
    end
  end

  actions do
    defaults([:read, :destroy])

    read :get_by_id do
      get? true
      argument :id, :uuid, allow_nil?: false
      filter expr(id == ^arg(:id))
      prepare build(load: [:gym, :invited_by])
    end

    read :list_pending_by_email do
      argument :email, :ci_string, allow_nil?: false
      filter expr(invited_email == ^arg(:email) and status == :pending)
      prepare build(load: [:gym, :invited_by])
    end

    read :list_pending_by_gym do
      argument :gym_id, :uuid, allow_nil?: false
      filter expr(gym_id == ^arg(:gym_id) and status == :pending)
      prepare build(load: [:gym, :invited_by])
    end

    create :create do
      accept([:invited_email, :gym_id, :invited_by_id])

      validate match(:invited_email, ~r/^[^\s]+@[^\s]+\.[^\s]+$/),
        message: "must be a valid email address"
    end

    update :accept do
      accept([])
      require_atomic?(false)

      change(set_attribute(:status, :accepted))
      change(FitTrackerz.Gym.Changes.CreateGymTrainerOnAccept)
    end

    update :reject do
      accept([])
      change(set_attribute(:status, :rejected))
    end

    update :expire do
      accept([])
      change(set_attribute(:status, :expired))
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute :invited_email, :ci_string do
      allow_nil?(false)
    end

    attribute :status, :atom do
      constraints(one_of: [:pending, :accepted, :rejected, :expired])
      allow_nil?(false)
      default(:pending)
    end

    timestamps()
  end

  identities do
    identity :unique_pending_invitation, [:gym_id, :invited_email],
      where: expr(status == :pending)
  end

  relationships do
    belongs_to :gym, FitTrackerz.Gym.Gym do
      allow_nil?(false)
    end

    belongs_to :invited_by, FitTrackerz.Accounts.User do
      allow_nil?(false)
    end
  end
end
```

- [ ] **Step 3: Create `lib/fit_trackerz/gym/client_assignment_request.ex`**

```elixir
defmodule FitTrackerz.Gym.ClientAssignmentRequest do
  use Ash.Resource,
    domain: FitTrackerz.Gym,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("client_assignment_requests")
    repo(FitTrackerz.Repo)

    references do
      reference :gym, on_delete: :delete
      reference :member, on_delete: :delete
      reference :trainer, on_delete: :delete
      reference :requested_by, on_delete: :delete
    end

    custom_indexes do
      index([:gym_id])
      index([:member_id])
      index([:trainer_id])
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
      authorize_if actor_attribute_equals(:role, :gym_operator)
      authorize_if actor_attribute_equals(:role, :trainer)
    end
  end

  actions do
    defaults([:read, :destroy])

    read :get_by_id do
      get? true
      argument :id, :uuid, allow_nil?: false
      filter expr(id == ^arg(:id))
      prepare build(load: [:gym, :requested_by, member: [:user]])
    end

    read :list_pending_by_trainer do
      argument :trainer_ids, {:array, :uuid}, allow_nil?: false
      filter expr(trainer_id in ^arg(:trainer_ids) and status == :pending)
      prepare build(load: [:gym, :requested_by, member: [:user]])
    end

    create :create do
      accept([:gym_id, :member_id, :trainer_id, :requested_by_id])
    end

    update :accept do
      accept([])
      require_atomic?(false)

      change(set_attribute(:status, :accepted))
      change(FitTrackerz.Gym.Changes.AssignTrainerOnAccept)
    end

    update :reject do
      accept([])
      change(set_attribute(:status, :rejected))
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute :status, :atom do
      constraints(one_of: [:pending, :accepted, :rejected])
      allow_nil?(false)
      default(:pending)
    end

    timestamps()
  end

  relationships do
    belongs_to :gym, FitTrackerz.Gym.Gym do
      allow_nil?(false)
    end

    belongs_to :member, FitTrackerz.Gym.GymMember do
      allow_nil?(false)
    end

    belongs_to :trainer, FitTrackerz.Gym.GymTrainer do
      allow_nil?(false)
    end

    belongs_to :requested_by, FitTrackerz.Accounts.User do
      allow_nil?(false)
    end
  end
end
```

- [ ] **Step 4: Create `lib/fit_trackerz/gym/changes/assign_trainer_on_accept.ex`**

```elixir
defmodule FitTrackerz.Gym.Changes.AssignTrainerOnAccept do
  use Ash.Resource.Change

  require Ash.Query

  alias FitTrackerz.Accounts.SystemActor

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn _changeset, request ->
      case Ash.get(FitTrackerz.Gym.GymMember, request.member_id, actor: SystemActor.system_actor()) do
        {:ok, member} ->
          case member
               |> Ash.Changeset.for_update(:update, %{assigned_trainer_id: request.trainer_id})
               |> Ash.update(actor: SystemActor.system_actor()) do
            {:ok, _updated_member} ->
              {:ok, request}

            {:error, error} ->
              {:error, error}
          end

        {:error, error} ->
          {:error, error}
      end
    end)
  end
end
```

- [ ] **Step 5: Create `lib/fit_trackerz/gym/changes/create_gym_trainer_on_accept.ex`**

```elixir
defmodule FitTrackerz.Gym.Changes.CreateGymTrainerOnAccept do
  use Ash.Resource.Change

  require Ash.Query

  alias FitTrackerz.Accounts.SystemActor

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn _changeset, invitation ->
      case Ash.get(FitTrackerz.Accounts.User, email: invitation.invited_email, actor: SystemActor.system_actor()) do
        {:ok, user} ->
          existing =
            case FitTrackerz.Gym.GymTrainer
                 |> Ash.Query.filter(user_id == ^user.id)
                 |> Ash.Query.filter(gym_id == ^invitation.gym_id)
                 |> Ash.read(actor: SystemActor.system_actor()) do
              {:ok, trainers} -> List.first(trainers)
              {:error, _} -> nil
            end

          unless existing do
            FitTrackerz.Gym.GymTrainer
            |> Ash.Changeset.for_create(:create, %{
              user_id: user.id,
              gym_id: invitation.gym_id
            })
            |> Ash.create(actor: SystemActor.system_actor())
          end

          if user.role == :member do
            user
            |> Ash.Changeset.for_update(:update, %{role: :trainer})
            |> Ash.update(actor: SystemActor.system_actor())
          end

          {:ok, invitation}

        _ ->
          {:ok, invitation}
      end
    end)
  end
end
```

- [ ] **Step 6: Commit**

```bash
git add lib/fit_trackerz/gym/gym_trainer.ex lib/fit_trackerz/gym/trainer_invitation.ex lib/fit_trackerz/gym/client_assignment_request.ex lib/fit_trackerz/gym/changes/assign_trainer_on_accept.ex lib/fit_trackerz/gym/changes/create_gym_trainer_on_accept.ex
git commit -m "Add GymTrainer, TrainerInvitation, ClientAssignmentRequest Ash resources and change modules"
```

---

## Task 3: Update Existing Ash Resources and Domains

**Files:**
- Modify: `lib/fit_trackerz/accounts/user.ex`
- Modify: `lib/fit_trackerz/gym.ex`
- Modify: `lib/fit_trackerz/gym/gym.ex`
- Modify: `lib/fit_trackerz/gym/gym_branch.ex`
- Modify: `lib/fit_trackerz/gym/gym_member.ex`
- Modify: `lib/fit_trackerz/training/workout_plan.ex`
- Modify: `lib/fit_trackerz/training/diet_plan.ex`
- Modify: `lib/fit_trackerz/scheduling/scheduled_class.ex`
- Modify: `lib/fit_trackerz/scheduling/class_booking.ex`
- Modify: `lib/fit_trackerz/training/attendance_record.ex`
- Modify: `lib/fit_trackerz/training/workout_plan_template.ex`
- Modify: `lib/fit_trackerz/training/diet_plan_template.ex`
- Modify: `lib/fit_trackerz/training.ex`
- Modify: `lib/fit_trackerz/scheduling.ex`

- [ ] **Step 1: Add `:trainer` to user role enum**

In `lib/fit_trackerz/accounts/user.ex`, change line 103:

```elixir
# FROM:
constraints(one_of: [:platform_admin, :gym_operator, :member])
# TO:
constraints(one_of: [:platform_admin, :gym_operator, :trainer, :member])
```

- [ ] **Step 2: Update Gym domain with trainer resources**

In `lib/fit_trackerz/gym.ex`, add after the GymMember resource block (after line 36) and before the MemberInvitation resource block:

```elixir
    resource FitTrackerz.Gym.GymTrainer do
      define :list_active_trainerships, args: [:user_id], action: :list_active_by_user
      define :list_trainers_by_gym, args: [:gym_id], action: :list_by_gym
      define :list_active_trainers_by_gym, args: [:gym_id], action: :list_active_by_gym
      define :create_gym_trainer, action: :create
      define :update_gym_trainer, action: :update
      define :destroy_gym_trainer, action: :destroy
    end
```

Also add after the MemberInvitation resource block (after line 46) and before the Contest resource block:

```elixir
    resource FitTrackerz.Gym.TrainerInvitation do
      define :get_trainer_invitation, args: [:id], action: :get_by_id
      define :list_pending_trainer_invitations, args: [:email], action: :list_pending_by_email
      define :list_pending_trainer_invitations_by_gym, args: [:gym_id], action: :list_pending_by_gym
      define :create_trainer_invitation, action: :create
      define :accept_trainer_invitation, action: :accept
      define :reject_trainer_invitation, action: :reject
      define :expire_trainer_invitation, action: :expire
    end

    resource FitTrackerz.Gym.ClientAssignmentRequest do
      define :get_assignment_request, args: [:id], action: :get_by_id
      define :list_pending_assignments_by_trainer, args: [:trainer_ids], action: :list_pending_by_trainer
      define :create_assignment_request, action: :create
      define :accept_assignment_request, action: :accept
      define :reject_assignment_request, action: :reject
    end
```

Also add `list_members_by_trainer` to the GymMember resource block:

```elixir
    # Add this line in the GymMember resource block, after line 32:
      define :list_members_by_trainer, args: [:trainer_ids], action: :list_by_assigned_trainer
```

- [ ] **Step 3: Add trainer relationships to Gym resource**

In `lib/fit_trackerz/gym/gym.ex`, add after `has_many :member_invitations`:

```elixir
    has_many :gym_trainers, FitTrackerz.Gym.GymTrainer
    has_many :trainer_invitations, FitTrackerz.Gym.TrainerInvitation
```

Also update the `list_by_owner` action to preload trainer data. Change:

```elixir
# FROM:
      prepare build(load: [:branches, :gym_members, :member_invitations])
# TO:
      prepare build(load: [:branches, :gym_members, :gym_trainers, :member_invitations, :trainer_invitations])
```

- [ ] **Step 3b: Add gym_trainers relationship to GymBranch**

In `lib/fit_trackerz/gym/gym_branch.ex`, add after the `has_many :gym_members` relationship:

```elixir
    has_many :gym_trainers, FitTrackerz.Gym.GymTrainer do
      destination_attribute(:branch_id)
    end
```

- [ ] **Step 4: Add assigned_trainer to GymMember**

In `lib/fit_trackerz/gym/gym_member.ex`:

Add to the `actions` block, after the `list_by_gym` action (after line 61):

```elixir
    read :list_by_assigned_trainer do
      argument :trainer_ids, {:array, :uuid}, allow_nil?: false
      filter expr(assigned_trainer_id in ^arg(:trainer_ids) and is_active == true)
      prepare build(load: [:user, :gym])
    end
```

Add `assigned_trainer_id` to the `update` action accept list (line 68):

```elixir
# FROM:
    update :update do
      accept([:is_active, :branch_id])
    end
# TO:
    update :update do
      accept([:is_active, :branch_id, :assigned_trainer_id])
    end
```

Add to the `relationships` block, after `belongs_to :branch` (after line 92):

```elixir
    belongs_to :assigned_trainer, FitTrackerz.Gym.GymTrainer
```

- [ ] **Step 5: Add trainer_id to WorkoutPlan**

In `lib/fit_trackerz/training/workout_plan.ex`:

Add a `list_by_trainer` action after the `list_by_member` action (after line 48):

```elixir
    read :list_by_trainer do
      argument :trainer_ids, {:array, :uuid}, allow_nil?: false
      filter expr(trainer_id in ^arg(:trainer_ids))
      prepare build(load: [:gym, :member])
    end
```

Add `:trainer_id` to the create action accept list (line 51):

```elixir
# FROM:
      accept([:name, :exercises, :member_id, :gym_id, :template_id])
# TO:
      accept([:name, :exercises, :member_id, :gym_id, :template_id, :trainer_id])
```

Add to the `relationships` block, after `belongs_to :template` (after line 93):

```elixir
    belongs_to :trainer, FitTrackerz.Gym.GymTrainer
```

- [ ] **Step 6: Add trainer_id to DietPlan**

In `lib/fit_trackerz/training/diet_plan.ex`:

Add a `list_by_trainer` action after the `list_by_member` action (after line 48):

```elixir
    read :list_by_trainer do
      argument :trainer_ids, {:array, :uuid}, allow_nil?: false
      filter expr(trainer_id in ^arg(:trainer_ids))
      prepare build(load: [:gym, :member])
    end
```

Add `:trainer_id` to the create action accept list (line 57):

```elixir
# FROM:
      accept([
        :name,
        :meals,
        :calorie_target,
        :dietary_type,
        :member_id,
        :gym_id,
        :template_id
      ])
# TO:
      accept([
        :name,
        :meals,
        :calorie_target,
        :dietary_type,
        :member_id,
        :gym_id,
        :template_id,
        :trainer_id
      ])
```

Add to the `relationships` block, after `belongs_to :template` (after line 109):

```elixir
    belongs_to :trainer, FitTrackerz.Gym.GymTrainer
```

- [ ] **Step 7: Add trainer_id to ScheduledClass**

In `lib/fit_trackerz/scheduling/scheduled_class.ex`:

Add a `list_by_trainer` action after the `list_scheduled_by_branch` action (after line 48):

```elixir
    read :list_by_trainer do
      argument :trainer_ids, {:array, :uuid}, allow_nil?: false
      filter expr(trainer_id in ^arg(:trainer_ids))
      prepare build(load: [:class_definition, :branch])
    end
```

Add `:trainer_id` to the create action accept list (line 51):

```elixir
# FROM:
      accept([:scheduled_at, :duration_minutes, :class_definition_id, :branch_id])
# TO:
      accept([:scheduled_at, :duration_minutes, :class_definition_id, :branch_id, :trainer_id])
```

Add to the `relationships` block, after `has_many :bookings` (after line 100):

```elixir
    belongs_to :trainer, FitTrackerz.Gym.GymTrainer
```

- [ ] **Step 8: Update Training domain**

In `lib/fit_trackerz/training.ex`, add to the WorkoutPlan resource block (after line 24):

```elixir
      define :list_workouts_by_trainer, args: [:trainer_ids], action: :list_by_trainer
```

Add to the DietPlan resource block (after line 39):

```elixir
      define :list_diets_by_trainer, args: [:trainer_ids], action: :list_by_trainer
```

- [ ] **Step 9: Update Scheduling domain**

In `lib/fit_trackerz/scheduling.ex`, add to the ScheduledClass resource block (after line 20):

```elixir
      define :list_classes_by_trainer, args: [:trainer_ids], action: :list_by_trainer
```

- [ ] **Step 10: Add `:trainer` to policies in 4 resource files**

Trainers need write access to attendance records, templates, and class bookings.

In `lib/fit_trackerz/training/attendance_record.ex`, add `:trainer` authorization to the create/destroy policy:

```elixir
# FROM:
    policy action_type([:create, :destroy]) do
      authorize_if actor_attribute_equals(:role, :gym_operator)
    end
# TO:
    policy action_type([:create, :destroy]) do
      authorize_if actor_attribute_equals(:role, :gym_operator)
      authorize_if actor_attribute_equals(:role, :trainer)
    end
```

In `lib/fit_trackerz/training/workout_plan_template.ex`, add `:trainer` to the create/update/destroy policy:

```elixir
# FROM:
    policy action_type([:create, :update, :destroy]) do
      authorize_if actor_attribute_equals(:role, :gym_operator)
    end
# TO:
    policy action_type([:create, :update, :destroy]) do
      authorize_if actor_attribute_equals(:role, :gym_operator)
      authorize_if actor_attribute_equals(:role, :trainer)
    end
```

In `lib/fit_trackerz/training/diet_plan_template.ex`, same change:

```elixir
# FROM:
    policy action_type([:create, :update, :destroy]) do
      authorize_if actor_attribute_equals(:role, :gym_operator)
    end
# TO:
    policy action_type([:create, :update, :destroy]) do
      authorize_if actor_attribute_equals(:role, :gym_operator)
      authorize_if actor_attribute_equals(:role, :trainer)
    end
```

In `lib/fit_trackerz/scheduling/class_booking.ex`, add `:trainer` to the create/update/destroy policy:

```elixir
# FROM:
    policy action_type([:create, :update, :destroy]) do
      authorize_if actor_attribute_equals(:role, :gym_operator)
      authorize_if actor_attribute_equals(:role, :member)
    end
# TO:
    policy action_type([:create, :update, :destroy]) do
      authorize_if actor_attribute_equals(:role, :gym_operator)
      authorize_if actor_attribute_equals(:role, :trainer)
      authorize_if actor_attribute_equals(:role, :member)
    end
```

- [ ] **Step 11: Restore trainer preload in ClassBooking**

In `lib/fit_trackerz/scheduling/class_booking.ex`, update the `list_by_member` action preload:

```elixir
# FROM:
      prepare build(load: [scheduled_class: [:class_definition, :branch]])
# TO:
      prepare build(load: [scheduled_class: [:class_definition, :trainer, :branch]])
```

- [ ] **Step 12: Add `:trainer` to WorkoutPlan and DietPlan policies**

In `lib/fit_trackerz/training/workout_plan.ex`, add `:trainer` authorization:

```elixir
# FROM:
    policy action_type([:create, :update, :destroy]) do
      authorize_if actor_attribute_equals(:role, :gym_operator)
    end
# TO:
    policy action_type([:create, :update, :destroy]) do
      authorize_if actor_attribute_equals(:role, :gym_operator)
      authorize_if actor_attribute_equals(:role, :trainer)
    end
```

In `lib/fit_trackerz/training/diet_plan.ex`, same change:

```elixir
# FROM:
    policy action_type([:create, :update, :destroy]) do
      authorize_if actor_attribute_equals(:role, :gym_operator)
    end
# TO:
    policy action_type([:create, :update, :destroy]) do
      authorize_if actor_attribute_equals(:role, :gym_operator)
      authorize_if actor_attribute_equals(:role, :trainer)
    end
```

- [ ] **Step 13: Verify compilation**

```bash
mix compile --warnings-as-errors
```

Expected: Compiles without errors. Warnings about unused functions are acceptable at this stage.

- [ ] **Step 14: Commit**

```bash
git add lib/fit_trackerz/accounts/user.ex lib/fit_trackerz/gym.ex lib/fit_trackerz/gym/gym.ex lib/fit_trackerz/gym/gym_branch.ex lib/fit_trackerz/gym/gym_member.ex lib/fit_trackerz/training/workout_plan.ex lib/fit_trackerz/training/diet_plan.ex lib/fit_trackerz/scheduling/scheduled_class.ex lib/fit_trackerz/scheduling/class_booking.ex lib/fit_trackerz/training/attendance_record.ex lib/fit_trackerz/training/workout_plan_template.ex lib/fit_trackerz/training/diet_plan_template.ex lib/fit_trackerz/training.ex lib/fit_trackerz/scheduling.ex
git commit -m "Add trainer role to user, trainer relationships, actions, and policies to existing resources"
```

---

## Task 4: Update Web Infrastructure (Auth, Router, Layouts, Helpers)

**Files:**
- Modify: `lib/fit_trackerz_web/live_user_auth.ex`
- Modify: `lib/fit_trackerz_web/router.ex`
- Modify: `lib/fit_trackerz_web/components/layouts.ex`
- Modify: `lib/fit_trackerz_web/controllers/auth_controller.ex`
- Modify: `lib/fit_trackerz_web/live/choose_role_live.ex`
- Modify: `lib/fit_trackerz_web/live/dashboard_live/index.ex`
- Modify: `lib/fit_trackerz_web/helpers/load_options.ex`
- Modify: `lib/fit_trackerz_web/controllers/page_controller.ex`

- [ ] **Step 1: Add `live_trainer_required` and update `live_member_required` in LiveUserAuth**

In `lib/fit_trackerz_web/live_user_auth.ex`:

First, add `:trainer` to the `live_member_required` role list so trainers can access member-level routes:

```elixir
# FROM:
    if user && role in [:platform_admin, :gym_operator, :member] do
# TO:
    if user && role in [:platform_admin, :gym_operator, :trainer, :member] do
```

Then add the new `live_trainer_required` hook after `live_gym_operator_required`:

```elixir
  def on_mount(:live_trainer_required, _params, session, socket) do
    user = get_current_user(socket, session)
    role = get_user_role(user)

    if user && role in [:platform_admin, :gym_operator, :trainer] do
      {:cont, socket}
    else
      {:halt,
       socket
       |> put_flash(:error, "You must be a trainer to access this page.")
       |> redirect(to: "/dashboard")}
    end
  end
```

- [ ] **Step 2: Add trainer routes to Router**

In `lib/fit_trackerz_web/router.ex`:

Add the `/solutions/trainers` route in the public scope (after line 27):

```elixir
    get "/solutions/trainers", PageController, :solutions_trainers
```

Add `/gym/trainers` route in the gym operator scope (after line 109, after the `/gym/members` route):

```elixir
      live "/trainers", TrainersLive
```

Add `/member/trainer` route in the member scope (after line 130, after the `/member/gym/:id` route):

```elixir
      live "/trainer", TrainerLive
```

Add the trainer route scope block. Insert after the gym_operator scope (after line 116) and before the member scope:

```elixir
  # Trainer routes
  ash_authentication_live_session :trainer,
    otp_app: :fit_trackerz,
    on_mount: [
      {FitTrackerzWeb.LiveUserAuth, :live_user_required},
      {FitTrackerzWeb.LiveUserAuth, :live_trainer_required}
    ] do
    scope "/trainer", FitTrackerzWeb.Trainer do
      pipe_through :browser

      live "/dashboard", DashboardLive
      live "/gyms", GymsLive
      live "/gyms/:id", GymDetailLive
      live "/clients", ClientsLive
      live "/workouts", WorkoutsLive
      live "/diets", DietsLive
      live "/templates", TemplatesLive
      live "/classes", ClassesLive
      live "/attendance", AttendanceLive
    end
  end
```

- [ ] **Step 3: Add trainer sidebar nav and format_role to Layouts**

In `lib/fit_trackerz_web/components/layouts.ex`:

Add a new `sidebar_nav` clause for `:trainer` BEFORE the catch-all `def sidebar_nav(assigns)` (before line 218):

```elixir
  def sidebar_nav(%{role: :trainer} = assigns) do
    ~H"""
    <p class="px-3 text-xs font-semibold text-base-content/40 uppercase tracking-wider mb-2">
      Overview
    </p>
    <.nav_link href="/trainer/dashboard" icon="hero-squares-2x2-solid" label="Dashboard" />
    <.nav_link href="/trainer/gyms" icon="hero-building-office-2-solid" label="My Gyms" />
    <.nav_link href="/trainer/clients" icon="hero-user-group-solid" label="My Clients" />

    <div class="divider my-3"></div>
    <p class="px-3 text-xs font-semibold text-base-content/40 uppercase tracking-wider mb-2">
      Training
    </p>
    <.nav_link href="/trainer/attendance" icon="hero-clipboard-document-check-solid" label="Attendance" />
    <.nav_link href="/trainer/workouts" icon="hero-fire-solid" label="Workout Plans" />
    <.nav_link href="/trainer/diets" icon="hero-heart-solid" label="Diet Plans" />
    <.nav_link href="/trainer/templates" icon="hero-document-duplicate-solid" label="Templates" />

    <div class="divider my-3"></div>
    <p class="px-3 text-xs font-semibold text-base-content/40 uppercase tracking-wider mb-2">
      Classes
    </p>
    <.nav_link href="/trainer/classes" icon="hero-calendar-days-solid" label="My Classes" />
    """
  end
```

Add "Trainers" link to the gym_operator sidebar. In the `sidebar_nav(%{role: :gym_operator})` function, add after the Members nav_link (after line 204):

```elixir
    <.nav_link href="/gym/trainers" icon="hero-academic-cap-solid" label="Trainers" />
```

Add "My Trainer" link to the member sidebar. In the catch-all `sidebar_nav(assigns)` function, add after the "My Gyms" nav_link (after line 224):

```elixir
    <.nav_link href="/member/trainer" icon="hero-academic-cap-solid" label="My Trainer" />
```

Update `format_role` — add before the catch-all (before line 368):

```elixir
  defp format_role(:trainer), do: "Trainer"
```

- [ ] **Step 4: Add trainer dashboard path to AuthController**

In `lib/fit_trackerz_web/controllers/auth_controller.ex`, add after line 108:

```elixir
  defp dashboard_path_for_role(:trainer), do: "/trainer/dashboard"
```

- [ ] **Step 5: Add trainer to ChooseRoleLive**

In `lib/fit_trackerz_web/live/choose_role_live.ex`:

Update `@valid_roles` (line 4):

```elixir
# FROM:
  @valid_roles ~w(member gym_operator)
# TO:
  @valid_roles ~w(member trainer gym_operator)
```

Add `dashboard_path_for_role(:trainer)` (after line 47):

```elixir
  defp dashboard_path_for_role(:trainer), do: "/trainer/dashboard"
```

In the render function, change the grid from 2-col to 3-col (line 72):

```elixir
# FROM:
          <div class="grid grid-cols-1 md:grid-cols-2 gap-6 max-w-2xl mx-auto" id="role-cards">
# TO:
          <div class="grid grid-cols-1 md:grid-cols-3 gap-6 max-w-4xl mx-auto" id="role-cards">
```

Add the Trainer card between the Member card and Gym Operator card (after the Member card closing `</button>` on line 94, before the Gym Operator card):

```html
            <%!-- Trainer Card --%>
            <button
              phx-click="select_role"
              phx-value-role="trainer"
              class="card bg-base-200/50 border-2 border-base-300/50 hover:border-secondary/50 shadow-sm hover:shadow-xl hover:-translate-y-1 cursor-pointer text-left group"
              id="role-trainer"
            >
              <div class="card-body items-center text-center p-8">
                <div class="w-16 h-16 rounded-2xl bg-secondary/10 flex items-center justify-center mb-4 group-hover:bg-secondary/20 group-hover:scale-110">
                  <.icon name="hero-academic-cap-solid" class="size-8 text-secondary" />
                </div>
                <h2 class="card-title text-xl">Trainer</h2>
                <p class="text-base-content/50 text-sm mt-2 leading-relaxed">
                  Manage clients, create workout & diet plans, track attendance, and conduct classes.
                </p>
                <div class="mt-6">
                  <span class="btn btn-secondary btn-sm font-semibold gap-2 group-hover:shadow-lg group-hover:shadow-secondary/25">
                    <.icon name="hero-arrow-right-mini" class="size-4" /> Join as Trainer
                  </span>
                </div>
              </div>
            </button>
```

- [ ] **Step 6: Add trainer redirect to DashboardLive.Index**

In `lib/fit_trackerz_web/live/dashboard_live/index.ex`, add after line 11 (`:gym_operator` case):

```elixir
        :trainer -> "/trainer/dashboard"
```

- [ ] **Step 7: Add trainer load options and update existing preloads**

In `lib/fit_trackerz_web/helpers/load_options.ex`:

First, update existing preload functions to include trainer data:

```elixir
# FROM:
  def gym_detailed do
    [:branches, :gym_members, :member_invitations, :owner]
  end
# TO:
  def gym_detailed do
    [:branches, :gym_members, :gym_trainers, :member_invitations, :trainer_invitations, :owner]
  end

# FROM:
  def gym_with_stats do
    [:branches, :gym_members]
  end
# TO:
  def gym_with_stats do
    [:branches, :gym_members, :gym_trainers]
  end

# FROM:
  def gym_member_basic, do: [:user, :branch]
# TO:
  def gym_member_basic, do: [:user, :branch, :assigned_trainer]

# FROM:
  def scheduled_class_basic, do: [:class_definition, :branch]
  def scheduled_class_with_bookings, do: [:class_definition, :branch, :bookings]
# TO:
  def scheduled_class_basic, do: [:class_definition, :branch, :trainer]
  def scheduled_class_with_bookings, do: [:class_definition, :branch, :trainer, :bookings]
```

Then add new trainer-specific preload helpers before the final `end`:

```elixir
  # Trainer
  def gym_trainer_basic, do: [:user]
  def gym_trainer_with_gym, do: [:user, :gym]
  def gym_member_with_trainer, do: [:user, assigned_trainer: [:user]]
  def trainer_invitation_basic, do: [:gym, :invited_by]
  def assignment_request_basic, do: [:gym, :requested_by, member: [:user]]
  def workout_with_trainer, do: [:gym, trainer: [:user]]
  def diet_with_trainer, do: [:gym, trainer: [:user]]
```

- [ ] **Step 8: Add solutions_trainers to PageController**

In `lib/fit_trackerz_web/controllers/page_controller.ex`, add before the final `end`:

```elixir
  def solutions_trainers(conn, _params) do
    render(conn, :solutions_trainers)
  end
```

- [ ] **Step 9: Note on compilation**

**Do NOT run `mix compile --warnings-as-errors` at this point.** The router references LiveView modules (e.g., `FitTrackerzWeb.Trainer.DashboardLive`) that do not yet exist. Phoenix `live` macros resolve modules at compile time, so compilation will **fail** until the LiveViews are created in Tasks 5-8. Proceed directly to Task 5.

- [ ] **Step 10: Commit**

```bash
git add lib/fit_trackerz_web/live_user_auth.ex lib/fit_trackerz_web/router.ex lib/fit_trackerz_web/components/layouts.ex lib/fit_trackerz_web/controllers/auth_controller.ex lib/fit_trackerz_web/live/choose_role_live.ex lib/fit_trackerz_web/live/dashboard_live/index.ex lib/fit_trackerz_web/helpers/load_options.ex lib/fit_trackerz_web/controllers/page_controller.ex
git commit -m "Add trainer web infrastructure: auth, routes, layouts, helpers"
```

---

## Task 5: Trainer LiveViews — Dashboard, Gyms, GymDetail

**Files:**
- Create: `lib/fit_trackerz_web/live/trainer/dashboard_live.ex`
- Create: `lib/fit_trackerz_web/live/trainer/gyms_live.ex`
- Create: `lib/fit_trackerz_web/live/trainer/gym_detail_live.ex`

These are the core navigation views for a trainer. The code below is adapted from the old Fitconnex versions, renamed to FitTrackerz namespace, and using the current codebase patterns.

- [ ] **Step 1: Create trainer LiveView directory**

```bash
mkdir -p lib/fit_trackerz_web/live/trainer
```

- [ ] **Step 2: Create `lib/fit_trackerz_web/live/trainer/dashboard_live.ex`**

This is a large file (~580 lines). Create it with the full trainer dashboard including:
- Pending gym invitations (accept/reject)
- Client assignment requests (accept/reject)
- Stats cards (clients, classes, workouts, diets)
- Quick action links
- Upcoming classes table
- Recent clients list

The module name must be `FitTrackerzWeb.Trainer.DashboardLive` and use `FitTrackerzWeb, :live_view`. All domain calls use `FitTrackerz.Gym.*` and `FitTrackerz.Training.*` and `FitTrackerz.Scheduling.*`.

Key mount logic:
```elixir
defmodule FitTrackerzWeb.Trainer.DashboardLive do
  use FitTrackerzWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    actor = socket.assigns.current_user
    {:ok, load_dashboard(socket, actor)}
  end

  # load_dashboard fetches:
  # 1. pending trainer invitations via FitTrackerz.Gym.list_pending_trainer_invitations(actor.email, ...)
  # 2. active trainerships via FitTrackerz.Gym.list_active_trainerships(actor.id, ...)
  # 3. client assignment requests via FitTrackerz.Gym.list_pending_assignments_by_trainer(trainer_ids, ...)
  # 4. clients via FitTrackerz.Gym.list_members_by_trainer(trainer_ids, ...)
  # 5. classes via FitTrackerz.Scheduling.list_classes_by_trainer(trainer_ids, ...)
  # 6. workouts via FitTrackerz.Training.list_workouts_by_trainer(trainer_ids, ...)
  # 7. diets via FitTrackerz.Training.list_diets_by_trainer(trainer_ids, ...)
end
```

Handle events: `accept_invitation`, `reject_invitation`, `accept_assignment`, `reject_assignment`.

The render function should use `Layouts.app` wrapper with current_user, display stats cards, invitation/assignment sections, quick actions, upcoming classes, and recent clients — all using DaisyUI card/table/badge/stat components consistent with the existing codebase style.

**Note to implementer:** Retrieve the full old file content via `git show 71475ed^:lib/fitconnex_web/live/trainer/dashboard_live.ex` and adapt all `Fitconnex` → `FitTrackerz`, `FitconnexWeb` → `FitTrackerzWeb` module references.

- [ ] **Step 3: Create `lib/fit_trackerz_web/live/trainer/gyms_live.ex`**

Module: `FitTrackerzWeb.Trainer.GymsLive`

Lists gyms the trainer is associated with. Mount loads active trainerships with gym data. Renders a grid of gym cards showing name, verification status, and branch count.

**Note to implementer:** Retrieve via `git show 71475ed^:lib/fitconnex_web/live/trainer/gyms_live.ex` and adapt namespace.

- [ ] **Step 4: Create `lib/fit_trackerz_web/live/trainer/gym_detail_live.ex`**

Module: `FitTrackerzWeb.Trainer.GymDetailLive`

Shows detailed gym view for a trainer — branches, pricing/plans, class definitions, fellow trainers. Mount takes `:id` param, verifies the trainer belongs to the gym. Includes tabs or sections for branches, plans, classes, trainers.

**Note to implementer:** Retrieve via `git show 71475ed^:lib/fitconnex_web/live/trainer/gym_detail_live.ex` and adapt namespace.

- [ ] **Step 5: Commit**

```bash
git add lib/fit_trackerz_web/live/trainer/dashboard_live.ex lib/fit_trackerz_web/live/trainer/gyms_live.ex lib/fit_trackerz_web/live/trainer/gym_detail_live.ex
git commit -m "Add trainer dashboard, gyms, and gym detail LiveViews"
```

---

## Task 6: Trainer LiveViews — Clients, Workouts, Diets

**Files:**
- Create: `lib/fit_trackerz_web/live/trainer/clients_live.ex`
- Create: `lib/fit_trackerz_web/live/trainer/workouts_live.ex`
- Create: `lib/fit_trackerz_web/live/trainer/diets_live.ex`

- [ ] **Step 1: Create `lib/fit_trackerz_web/live/trainer/clients_live.ex`**

Module: `FitTrackerzWeb.Trainer.ClientsLive`

Lists assigned clients with stats (total, active, across how many gyms). Table shows client name, email, gym, active status. Mount loads active trainerships then fetches members assigned to those trainer records.

**Note to implementer:** Retrieve via `git show 71475ed^:lib/fitconnex_web/live/trainer/clients_live.ex` and adapt namespace.

- [ ] **Step 2: Create `lib/fit_trackerz_web/live/trainer/workouts_live.ex`**

Module: `FitTrackerzWeb.Trainer.WorkoutsLive`

Full CRUD for workout plans created by the trainer. Includes a dynamic exercise builder (add/remove exercises with name, sets, reps, duration, rest fields). Mount loads trainer records then workouts by trainer IDs. Members are loaded for assignment dropdown.

Handle events: `save_workout`, `delete_workout`, `add_exercise`, `remove_exercise`, `update_exercise`, `show_form`, `cancel_form`, `edit_workout`.

**Note to implementer:** Retrieve via `git show 71475ed^:lib/fitconnex_web/live/trainer/workouts_live.ex` and adapt namespace.

- [ ] **Step 3: Create `lib/fit_trackerz_web/live/trainer/diets_live.ex`**

Module: `FitTrackerzWeb.Trainer.DietsLive`

Full CRUD for diet plans. Similar pattern to workouts but with meals, calorie_target, dietary_type fields. Mount loads trainer records then diets by trainer IDs.

Handle events: `save_diet`, `delete_diet`, `show_form`, `cancel_form`, `edit_diet`.

**Note to implementer:** Retrieve via `git show 71475ed^:lib/fitconnex_web/live/trainer/diets_live.ex` and adapt namespace.

- [ ] **Step 4: Commit**

```bash
git add lib/fit_trackerz_web/live/trainer/clients_live.ex lib/fit_trackerz_web/live/trainer/workouts_live.ex lib/fit_trackerz_web/live/trainer/diets_live.ex
git commit -m "Add trainer clients, workouts, and diets LiveViews"
```

---

## Task 7: Trainer LiveViews — Templates, Classes, Attendance

**Files:**
- Create: `lib/fit_trackerz_web/live/trainer/templates_live.ex`
- Create: `lib/fit_trackerz_web/live/trainer/classes_live.ex`
- Create: `lib/fit_trackerz_web/live/trainer/attendance_live.ex`

- [ ] **Step 1: Create `lib/fit_trackerz_web/live/trainer/templates_live.ex`**

Module: `FitTrackerzWeb.Trainer.TemplatesLive`

Manages reusable workout templates (with difficulty levels: beginner/intermediate/advanced) and diet templates. Templates are filtered by `created_by_id == actor.id` and scoped to the trainer's gyms. Full CRUD with exercise/meal builders.

**Note to implementer:** Retrieve via `git show 71475ed^:lib/fitconnex_web/live/trainer/templates_live.ex` and adapt namespace.

- [ ] **Step 2: Create `lib/fit_trackerz_web/live/trainer/classes_live.ex`**

Module: `FitTrackerzWeb.Trainer.ClassesLive`

Views scheduled classes assigned to the trainer with complete/cancel actions. Shows stats: total, scheduled, completed. Table with class name, branch, scheduled time, duration, status, and action buttons.

**Note to implementer:** Retrieve via `git show 71475ed^:lib/fitconnex_web/live/trainer/classes_live.ex` and adapt namespace.

- [ ] **Step 3: Create `lib/fit_trackerz_web/live/trainer/attendance_live.ex`**

Module: `FitTrackerzWeb.Trainer.AttendanceLive`

Mark and track client attendance. Form with member selection, datetime picker, and notes. List of attendance records filtered by `marked_by_id == actor.id`. Stats: total records, today's count.

**Note to implementer:** Retrieve via `git show 71475ed^:lib/fitconnex_web/live/trainer/attendance_live.ex` and adapt namespace.

- [ ] **Step 4: Commit**

```bash
git add lib/fit_trackerz_web/live/trainer/templates_live.ex lib/fit_trackerz_web/live/trainer/classes_live.ex lib/fit_trackerz_web/live/trainer/attendance_live.ex
git commit -m "Add trainer templates, classes, and attendance LiveViews"
```

---

## Task 8: Gym Operator TrainersLive + Member TrainerLive

**Files:**
- Create: `lib/fit_trackerz_web/live/gym_operator/trainers_live.ex`
- Create: `lib/fit_trackerz_web/live/member/trainer_live.ex`

- [ ] **Step 1: Create `lib/fit_trackerz_web/live/gym_operator/trainers_live.ex`**

Module: `FitTrackerzWeb.GymOperator.TrainersLive`

Gym operator page to manage trainers: invite by email, toggle active/inactive status, view specializations. Mount loads the gym by owner, then trainers and pending trainer invitations for that gym.

Handle events: `invite_trainer`, `toggle_active`, `cancel_invitation`.

**Note to implementer:** Retrieve via `git show 71475ed^:lib/fitconnex_web/live/gym_operator/trainers_live.ex` and adapt namespace.

- [ ] **Step 2: Create `lib/fit_trackerz_web/live/member/trainer_live.ex`**

Module: `FitTrackerzWeb.Member.TrainerLive`

Member view showing their assigned trainer per gym membership. Mount loads active memberships with assigned_trainer loaded. Shows trainer name, email, specializations per gym.

**Note to implementer:** Retrieve via `git show 71475ed^:lib/fitconnex_web/live/member/trainer_live.ex` and adapt namespace.

- [ ] **Step 3: Commit**

```bash
git add lib/fit_trackerz_web/live/gym_operator/trainers_live.ex lib/fit_trackerz_web/live/member/trainer_live.ex
git commit -m "Add gym operator trainers management and member trainer view LiveViews"
```

---

## Task 9: Solutions Trainers Marketing Page

**Files:**
- Create: `lib/fit_trackerz_web/controllers/page_html/solutions_trainers.html.heex`

- [ ] **Step 1: Create the marketing page template**

Module: HEEx template at `lib/fit_trackerz_web/controllers/page_html/solutions_trainers.html.heex`

A public marketing page for trainers with sections:
- Hero section with headline and CTA
- Features grid (client management, workout plans, diet plans, templates, class scheduling, attendance tracking)
- How it works steps
- Benefits section
- CTA section with register link

Style consistently with the existing `solutions_members.html.heex` and `solutions_operators.html.heex` pages. Use DaisyUI components and the FitTrackerz brand colors.

**Note to implementer:** Retrieve via `git show 71475ed^:lib/fitconnex_web/controllers/page_html/solutions_trainers.html.heex` and adapt branding from Fitconnex to FitTrackerz.

- [ ] **Step 2: Commit**

```bash
git add lib/fit_trackerz_web/controllers/page_html/solutions_trainers.html.heex
git commit -m "Add trainer solutions marketing page"
```

---

## Task 10: Final Verification and Compilation

- [ ] **Step 1: Compile and check for errors**

```bash
mix compile --warnings-as-errors
```

Expected: Clean compilation with no errors.

- [ ] **Step 2: Run the migration**

```bash
mix ecto.migrate
```

Expected: Migration runs successfully.

- [ ] **Step 3: Start the server and test**

```bash
mix phx.server
```

Verify:
1. `/solutions/trainers` page loads
2. `/choose-role` shows three role cards (Member, Trainer, Gym Operator)
3. Selecting "Trainer" role redirects to `/trainer/dashboard`
4. Trainer sidebar shows all navigation links
5. `/gym/trainers` accessible for gym operators
6. `/member/trainer` accessible for members

- [ ] **Step 4: Final commit**

```bash
git add -A
git commit -m "Restore trainer role: complete feature restoration with all LiveViews, resources, and routes"
```
