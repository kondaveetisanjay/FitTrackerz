defmodule FitTrackerz.Training.AttendanceRecord do
  use Ash.Resource,
    domain: FitTrackerz.Training,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("attendance_records")
    repo(FitTrackerz.Repo)

    references do
      reference :member, on_delete: :delete
      reference :gym, on_delete: :delete
      reference :marked_by, on_delete: :nilify
    end

    custom_indexes do
      index([:member_id])
      index([:gym_id])
      index([:attended_at])
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

    policy action_type([:create, :destroy]) do
      authorize_if actor_attribute_equals(:role, :gym_operator)
    end
  end

  actions do
    defaults([:read, :destroy])

    read :list_by_member do
      argument :member_ids, {:array, :uuid}, allow_nil?: false
      filter expr(member_id in ^arg(:member_ids))
      prepare build(load: [:gym, :marked_by])
    end

    create :create do
      accept([:attended_at, :notes, :member_id, :gym_id, :marked_by_id])

      validate string_length(:notes, max: 500)
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute :attended_at, :utc_datetime do
      allow_nil?(false)
    end

    attribute :notes, :string do
      constraints(max_length: 500)
    end

    timestamps()
  end

  relationships do
    belongs_to :member, FitTrackerz.Gym.GymMember do
      allow_nil?(false)
    end

    belongs_to :gym, FitTrackerz.Gym.Gym do
      allow_nil?(false)
    end

    belongs_to :marked_by, FitTrackerz.Accounts.User
  end
end
