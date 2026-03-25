defmodule FitTrackerz.Training.WorkoutLogEntry do
  use Ash.Resource,
    domain: FitTrackerz.Training,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("workout_log_entries")
    repo(FitTrackerz.Repo)

    references do
      reference :workout_log, on_delete: :delete
    end

    custom_indexes do
      index([:workout_log_id])
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

    read :list_by_workout_log do
      argument :workout_log_id, :uuid, allow_nil?: false
      filter expr(workout_log_id == ^arg(:workout_log_id))
      prepare build(sort: [order: :asc])
    end

    read :list_by_member_exercise do
      argument :member_id, :uuid, allow_nil?: false
      argument :exercise_name, :string, allow_nil?: false
      filter expr(
        workout_log.member_id == ^arg(:member_id) and
          exercise_name == ^arg(:exercise_name) and
          not is_nil(weight_kg)
      )
      prepare build(sort: [weight_kg: :desc], limit: 1)
    end

    create :create do
      accept([
        :workout_log_id,
        :exercise_name,
        :planned_sets,
        :planned_reps,
        :actual_sets,
        :actual_reps,
        :weight_kg,
        :order
      ])
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute :exercise_name, :string do
      allow_nil?(false)
      constraints(max_length: 255)
    end

    attribute(:planned_sets, :integer)
    attribute(:planned_reps, :integer)

    attribute :actual_sets, :integer do
      allow_nil?(false)
      constraints(min: 0)
    end

    attribute :actual_reps, :integer do
      allow_nil?(false)
      constraints(min: 0)
    end

    attribute :weight_kg, :decimal do
      constraints(min: 0)
    end

    attribute :order, :integer do
      allow_nil?(false)
      constraints(min: 0)
    end

    timestamps()
  end

  relationships do
    belongs_to :workout_log, FitTrackerz.Training.WorkoutLog do
      allow_nil?(false)
    end
  end
end
