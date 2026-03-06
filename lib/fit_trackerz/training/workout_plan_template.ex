defmodule FitTrackerz.Training.WorkoutPlanTemplate do
  use Ash.Resource,
    domain: FitTrackerz.Training,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("workout_plan_templates")
    repo(FitTrackerz.Repo)

    references do
      reference :gym, on_delete: :delete
      reference :created_by, on_delete: :nilify
    end

    custom_indexes do
      index([:gym_id])
      index([:created_by_id])
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

    read :list_by_gym do
      argument :gym_id, :uuid, allow_nil?: false
      filter expr(gym_id == ^arg(:gym_id))
    end

    create :create do
      accept([:name, :exercises, :difficulty_level, :gym_id, :created_by_id])

      validate string_length(:name, min: 1, max: 255)
    end

    update :update do
      accept([:name, :exercises, :difficulty_level])

      validate string_length(:name, min: 1, max: 255)
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute :name, :string do
      allow_nil?(false)
      constraints(max_length: 255)
    end

    attribute :exercises, {:array, FitTrackerz.Training.Exercise} do
      default([])
    end

    attribute :difficulty_level, :atom do
      constraints(one_of: [:beginner, :intermediate, :advanced])
    end

    timestamps()
  end

  relationships do
    belongs_to :gym, FitTrackerz.Gym.Gym do
      allow_nil?(false)
    end

    belongs_to :created_by, FitTrackerz.Accounts.User do
      allow_nil?(false)
    end
  end
end
