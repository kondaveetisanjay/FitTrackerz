defmodule Fitconnex.Training.AttendanceRecord do
  use Ash.Resource,
    domain: Fitconnex.Training,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("attendance_records")
    repo(Fitconnex.Repo)
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      accept([:attended_at, :notes, :member_id, :gym_id, :marked_by_id])
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute :attended_at, :utc_datetime do
      allow_nil?(false)
    end

    attribute(:notes, :string)

    timestamps()
  end

  relationships do
    belongs_to :member, Fitconnex.Gym.GymMember do
      allow_nil?(false)
    end

    belongs_to :gym, Fitconnex.Gym.Gym do
      allow_nil?(false)
    end

    belongs_to :marked_by, Fitconnex.Accounts.User
  end
end
