defmodule FitTrackerz.Repo.Migrations.AddNotificationsAndJoinedAt do
  use Ecto.Migration

  def change do
    # Add joined_at to gym_members
    alter table(:gym_members) do
      add :joined_at, :date
    end

    # Set existing rows to use inserted_at date
    execute(
      "UPDATE gym_members SET joined_at = inserted_at::date",
      "SELECT 1"
    )

    # Create notifications table
    create table(:notifications, primary_key: false) do
      add :id, :uuid, primary_key: true, null: false, default: fragment("gen_random_uuid()")
      add :type, :text, null: false
      add :title, :text, null: false
      add :message, :text, null: false
      add :is_read, :boolean, null: false, default: false
      add :metadata, :map, default: %{}

      add :user_id, references(:users, type: :uuid, on_delete: :delete_all), null: false
      add :gym_id, references(:gyms, type: :uuid, on_delete: :delete_all)

      timestamps()
    end

    create index(:notifications, [:user_id])
    create index(:notifications, [:gym_id])
    create index(:notifications, [:user_id, :is_read])
  end
end
