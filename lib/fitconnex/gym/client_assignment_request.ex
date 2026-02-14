defmodule Fitconnex.Gym.ClientAssignmentRequest do
  use Ash.Resource,
    domain: Fitconnex.Gym,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("client_assignment_requests")
    repo(Fitconnex.Repo)
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      accept([:gym_id, :member_id, :trainer_id, :requested_by_id])
    end

    update :accept do
      accept([])
      require_atomic?(false)

      change(set_attribute(:status, :accepted))
      change(Fitconnex.Gym.Changes.AssignTrainerOnAccept)
    end

    update :reject do
      accept([])
      change(set_attribute(:status, :rejected))
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute :status, :atom do
      constraints(one_of: [:pending, :accepted, :rejected])
      allow_nil?(false)
      default(:pending)
    end

    timestamps()
  end

  relationships do
    belongs_to :gym, Fitconnex.Gym.Gym do
      allow_nil?(false)
    end

    belongs_to :member, Fitconnex.Gym.GymMember do
      allow_nil?(false)
    end

    belongs_to :trainer, Fitconnex.Gym.GymTrainer do
      allow_nil?(false)
    end

    belongs_to :requested_by, Fitconnex.Accounts.User do
      allow_nil?(false)
    end
  end
end
