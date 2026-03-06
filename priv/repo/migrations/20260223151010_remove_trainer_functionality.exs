defmodule FitTrackerz.Repo.Migrations.RemoveTrainerFunctionality do
  @moduledoc """
  Remove all trainer-related tables, columns, and data.
  Updates existing trainer users to member role.
  """
  use Ecto.Migration

  def up do
    # 1. Drop client_assignment_requests table
    drop_if_exists table(:client_assignment_requests)

    # 2. Drop trainer_invitations table
    drop_if_exists table(:trainer_invitations)

    # 3. Remove assigned_trainer_id from gym_members
    drop_if_exists index(:gym_members, [:assigned_trainer_id])

    alter table(:gym_members) do
      remove_if_exists :assigned_trainer_id, :uuid
    end

    # 4. Remove trainer_id from workout_plans
    drop_if_exists index(:workout_plans, [:trainer_id])

    alter table(:workout_plans) do
      remove_if_exists :trainer_id, :uuid
    end

    # 5. Remove trainer_id from diet_plans
    drop_if_exists index(:diet_plans, [:trainer_id])

    alter table(:diet_plans) do
      remove_if_exists :trainer_id, :uuid
    end

    # 6. Remove trainer_id from scheduled_classes
    drop_if_exists index(:scheduled_classes, [:trainer_id])

    alter table(:scheduled_classes) do
      remove_if_exists :trainer_id, :uuid
    end

    # 7. Drop gym_trainers table
    drop_if_exists table(:gym_trainers)

    # 8. Update existing trainer users to member role
    execute "UPDATE users SET role = 'member' WHERE role = 'trainer'"
  end

  def down do
    # Re-create gym_trainers table
    create table(:gym_trainers, primary_key: false) do
      add :id, :uuid, null: false, primary_key: true
      add :user_id, references(:users, type: :uuid, on_delete: :delete_all), null: false
      add :gym_id, references(:gyms, type: :uuid, on_delete: :delete_all), null: false
      add :specializations, {:array, :text}, default: []
      add :is_active, :boolean, default: true, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:gym_trainers, [:user_id])
    create index(:gym_trainers, [:gym_id])
    create unique_index(:gym_trainers, [:user_id, :gym_id])

    # Re-add trainer_id columns
    alter table(:scheduled_classes) do
      add :trainer_id, references(:gym_trainers, type: :uuid, on_delete: :nilify_all)
    end

    create index(:scheduled_classes, [:trainer_id])

    alter table(:diet_plans) do
      add :trainer_id, references(:gym_trainers, type: :uuid, on_delete: :nilify_all)
    end

    create index(:diet_plans, [:trainer_id])

    alter table(:workout_plans) do
      add :trainer_id, references(:gym_trainers, type: :uuid, on_delete: :nilify_all)
    end

    create index(:workout_plans, [:trainer_id])

    alter table(:gym_members) do
      add :assigned_trainer_id, references(:gym_trainers, type: :uuid, on_delete: :nilify_all)
    end

    create index(:gym_members, [:assigned_trainer_id])

    # Re-create trainer_invitations table
    create table(:trainer_invitations, primary_key: false) do
      add :id, :uuid, null: false, primary_key: true
      add :email, :citext, null: false
      add :status, :text, null: false, default: "pending"
      add :gym_id, references(:gyms, type: :uuid, on_delete: :delete_all), null: false
      add :invited_by_id, references(:users, type: :uuid, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    # Re-create client_assignment_requests table
    create table(:client_assignment_requests, primary_key: false) do
      add :id, :uuid, null: false, primary_key: true
      add :status, :text, null: false, default: "pending"
      add :member_id, references(:gym_members, type: :uuid, on_delete: :delete_all), null: false
      add :trainer_id, references(:gym_trainers, type: :uuid, on_delete: :delete_all), null: false
      add :gym_id, references(:gyms, type: :uuid, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end
  end
end
