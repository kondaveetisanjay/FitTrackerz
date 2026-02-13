defmodule Fitconnex.Training.WorkoutPlan do
  use Ash.Resource,
    domain: Fitconnex.Training,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("workout_plans")
    repo(Fitconnex.Repo)
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      accept([:name, :exercises, :member_id, :gym_id, :trainer_id, :template_id])
    end

    create :create_from_template do
      accept([:member_id, :gym_id, :trainer_id, :template_id])

      change(Fitconnex.Training.Changes.CopyFromWorkoutTemplate)
    end

    update :update do
      accept([:name, :exercises])
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

    timestamps()
  end

  relationships do
    belongs_to :member, Fitconnex.Gym.GymMember do
      allow_nil?(false)
    end

    belongs_to :gym, Fitconnex.Gym.Gym do
      allow_nil?(false)
    end

    belongs_to :trainer, Fitconnex.Gym.GymTrainer

    belongs_to :template, Fitconnex.Training.WorkoutPlanTemplate
  end
end
