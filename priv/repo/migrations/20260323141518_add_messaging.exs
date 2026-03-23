defmodule FitTrackerz.Repo.Migrations.AddMessaging do
  use Ecto.Migration

  def change do
    # Create conversations table
    create table(:conversations, primary_key: false) do
      add :id, :uuid, primary_key: true, null: false, default: fragment("gen_random_uuid()")
      add :type, :text, null: false
      add :title, :text

      add :gym_id, references(:gyms, type: :uuid, on_delete: :delete_all), null: false
      add :created_by_id, references(:users, type: :uuid, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:conversations, [:gym_id])
    create index(:conversations, [:created_by_id])

    # Create conversation_participants table
    create table(:conversation_participants, primary_key: false) do
      add :id, :uuid, primary_key: true, null: false, default: fragment("gen_random_uuid()")
      add :role, :text, null: false, default: "participant"
      add :last_read_at, :utc_datetime_usec

      add :conversation_id, references(:conversations, type: :uuid, on_delete: :delete_all),
        null: false

      add :user_id, references(:users, type: :uuid, on_delete: :delete_all), null: false

      timestamps()
    end

    create unique_index(:conversation_participants, [:conversation_id, :user_id])
    create index(:conversation_participants, [:user_id])
    create index(:conversation_participants, [:conversation_id])

    # Create messages table
    create table(:messages, primary_key: false) do
      add :id, :uuid, primary_key: true, null: false, default: fragment("gen_random_uuid()")
      add :body, :text, null: false
      add :attachments, {:array, :map}, default: []

      add :conversation_id, references(:conversations, type: :uuid, on_delete: :delete_all),
        null: false

      add :sender_id, references(:users, type: :uuid, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:messages, [:conversation_id, :inserted_at])
    create index(:messages, [:sender_id])
  end
end
