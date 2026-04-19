defmodule FitTrackerz.Repo.Migrations.DropQrCheckIns do
  @moduledoc """
  Drops the training_qr_check_ins table — QR check-in feature removed.
  """

  use Ecto.Migration

  def up do
    drop_if_exists(unique_index(:training_qr_check_ins, [:token],
                     name: "training_qr_check_ins_unique_token_index"
                   ))

    drop_if_exists(index(:training_qr_check_ins, [:gym_member_id]))
    drop_if_exists(index(:training_qr_check_ins, [:token]))
    drop_if_exists(table(:training_qr_check_ins))
  end

  def down do
    create table(:training_qr_check_ins, primary_key: false) do
      add(:id, :uuid, null: false, primary_key: true)
      add(:token, :text, null: false)
      add(:expires_at, :utc_datetime, null: false)
      add(:used_at, :utc_datetime)
      add(:status, :text, null: false, default: "active")

      add(:gym_member_id,
          references(:gym_members,
            column: :id,
            name: "training_qr_check_ins_gym_member_id_fkey",
            type: :uuid,
            prefix: "public",
            on_delete: :delete_all
          ),
          null: false)

      add(:gym_branch_id,
          references(:gym_branches,
            column: :id,
            name: "training_qr_check_ins_gym_branch_id_fkey",
            type: :uuid,
            prefix: "public",
            on_delete: :nilify_all
          ))

      add(:inserted_at, :utc_datetime_usec, null: false, default: fragment("(now() AT TIME ZONE 'utc')"))
      add(:updated_at, :utc_datetime_usec, null: false, default: fragment("(now() AT TIME ZONE 'utc')"))
    end

    create(index(:training_qr_check_ins, [:token]))
    create(index(:training_qr_check_ins, [:gym_member_id]))

    create(unique_index(:training_qr_check_ins, [:token],
             name: "training_qr_check_ins_unique_token_index"
           ))
  end
end
