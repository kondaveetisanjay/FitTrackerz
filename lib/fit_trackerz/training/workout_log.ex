defmodule FitTrackerz.Training.WorkoutLog do
  use Ash.Resource,
    domain: FitTrackerz.Training,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("workout_logs")
    repo(FitTrackerz.Repo)

    references do
      reference :member, on_delete: :delete
      reference :gym, on_delete: :delete
      reference :workout_plan, on_delete: :nilify
    end

    custom_indexes do
      index([:member_id])
      index([:gym_id])
      index([:member_id, :completed_on])
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
      authorize_if actor_attribute_equals(:role, :member)
    end
  end

  actions do
    defaults([:read, :destroy])

    read :list_by_member do
      argument :member_ids, {:array, :uuid}, allow_nil?: false
      filter expr(member_id in ^arg(:member_ids))
      prepare build(sort: [completed_on: :desc], load: [:entries, :workout_plan])
    end

    read :list_dates_by_member do
      argument :member_ids, {:array, :uuid}, allow_nil?: false
      filter expr(member_id in ^arg(:member_ids))
      prepare build(sort: [completed_on: :desc])
    end

    create :create do
      accept([:member_id, :gym_id, :workout_plan_id, :completed_on, :duration_minutes, :notes])

      validate string_length(:notes, max: 500)
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute :completed_on, :date do
      allow_nil?(false)
    end

    attribute :duration_minutes, :integer do
      constraints(min: 1)
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

    belongs_to :workout_plan, FitTrackerz.Training.WorkoutPlan

    has_many :entries, FitTrackerz.Training.WorkoutLogEntry
  end
end
