defmodule Fitconnex.Gym.TrainerInvitation do
  use Ash.Resource,
    domain: Fitconnex.Gym,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("trainer_invitations")
    repo(Fitconnex.Repo)
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      accept([:invited_email, :gym_id, :invited_by_id])
    end

    update :accept do
      accept([])
      require_atomic?(false)

      change(set_attribute(:status, :accepted))
      change(Fitconnex.Gym.Changes.CreateGymTrainerOnAccept)
    end

    update :reject do
      accept([])
      change(set_attribute(:status, :rejected))
    end

    update :expire do
      accept([])
      change(set_attribute(:status, :expired))
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute :invited_email, :ci_string do
      allow_nil?(false)
    end

    attribute :status, :atom do
      constraints(one_of: [:pending, :accepted, :rejected, :expired])
      allow_nil?(false)
      default(:pending)
    end

    timestamps()
  end

  relationships do
    belongs_to :gym, Fitconnex.Gym.Gym do
      allow_nil?(false)
    end

    belongs_to :invited_by, Fitconnex.Accounts.User do
      allow_nil?(false)
    end
  end
end
