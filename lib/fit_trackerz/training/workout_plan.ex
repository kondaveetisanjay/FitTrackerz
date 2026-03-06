defmodule FitTrackerz.Training.WorkoutPlan do
  use Ash.Resource,
    domain: FitTrackerz.Training,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("workout_plans")
    repo(FitTrackerz.Repo)

    references do
      reference :member, on_delete: :delete
      reference :gym, on_delete: :delete
      reference :template, on_delete: :nilify
    end

    custom_indexes do
      index([:member_id])
      index([:gym_id])
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

    read :list_by_member do
      argument :member_ids, {:array, :uuid}, allow_nil?: false
      filter expr(member_id in ^arg(:member_ids))
      prepare build(load: [:gym])
    end

    create :create do
      accept([:name, :exercises, :member_id, :gym_id, :template_id])

      validate string_length(:name, min: 1, max: 255)
    end

    create :create_from_template do
      accept([:member_id, :gym_id, :template_id])

      change(FitTrackerz.Training.Changes.CopyFromWorkoutTemplate)
    end

    update :update do
      accept([:name, :exercises])

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

    timestamps()
  end

  relationships do
    belongs_to :member, FitTrackerz.Gym.GymMember do
      allow_nil?(false)
    end

    belongs_to :gym, FitTrackerz.Gym.Gym do
      allow_nil?(false)
    end

    belongs_to :template, FitTrackerz.Training.WorkoutPlanTemplate
  end
end
