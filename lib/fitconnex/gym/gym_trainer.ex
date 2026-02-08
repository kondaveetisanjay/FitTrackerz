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
      accept([:user_id, :gym_id, :specializations])
    end

    update :update do
      accept([:specializations, :is_active])
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
  end

  identities do
    identity(:unique_trainer_gym, [:user_id, :gym_id])
  end
end
