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
