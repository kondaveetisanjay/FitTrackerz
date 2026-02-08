defmodule Fitconnex.Training.WorkoutPlanTemplate do
  use Ash.Resource,
    domain: Fitconnex.Training,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("workout_plan_templates")
    repo(Fitconnex.Repo)
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      accept([:name, :exercises, :difficulty_level, :gym_id, :created_by_id])
    end

    update :update do
      accept([:name, :exercises, :difficulty_level])
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute :name, :string do
      allow_nil?(false)
    end

    attribute :exercises, {:array, Fitconnex.Training.Exercise} do
      default([])
    end

    attribute :difficulty_level, :atom do
      constraints(one_of: [:beginner, :intermediate, :advanced])
    end

    timestamps()
  end

  relationships do
    belongs_to :gym, Fitconnex.Gym.Gym do
      allow_nil?(false)
    end

    belongs_to :created_by, Fitconnex.Accounts.User do
      allow_nil?(false)
    end
  end
end
