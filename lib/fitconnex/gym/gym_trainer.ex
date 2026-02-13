defmodule Fitconnex.Gym.GymTrainer do
  use Ash.Resource,
    domain: Fitconnex.Gym,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("gym_trainers")
    repo(Fitconnex.Repo)
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      accept([:user_id, :gym_id, :specializations, :branch_id])
    end

    update :update do
      accept([:specializations, :is_active, :branch_id])
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute :specializations, {:array, :string} do
      default([])
    end

    attribute :is_active, :boolean do
      allow_nil?(false)
      default(true)
    end

    timestamps()
  end

  relationships do
    belongs_to :user, Fitconnex.Accounts.User do
      allow_nil?(false)
    end

    belongs_to :gym, Fitconnex.Gym.Gym do
      allow_nil?(false)
    end

    belongs_to :branch, Fitconnex.Gym.GymBranch

    has_many :scheduled_classes, Fitconnex.Scheduling.ScheduledClass
    has_many :workout_plans, Fitconnex.Training.WorkoutPlan
    has_many :diet_plans, Fitconnex.Training.DietPlan

    has_many :assigned_members, Fitconnex.Gym.GymMember do
      destination_attribute(:assigned_trainer_id)
    end
  end

  identities do
    identity(:unique_trainer_gym, [:user_id, :gym_id])
  end
end
