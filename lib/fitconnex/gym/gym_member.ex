defmodule Fitconnex.Gym.GymMember do
  use Ash.Resource,
    domain: Fitconnex.Gym,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("gym_members")
    repo(Fitconnex.Repo)
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      accept([:user_id, :gym_id, :assigned_trainer_id, :branch_id])
    end

    update :update do
      accept([:assigned_trainer_id, :is_active, :branch_id])
    end
  end

  attributes do
    uuid_primary_key(:id)

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

    belongs_to :assigned_trainer, Fitconnex.Gym.GymTrainer

    belongs_to :branch, Fitconnex.Gym.GymBranch
  end

  identities do
    identity(:unique_membership, [:user_id, :gym_id])
  end
end
