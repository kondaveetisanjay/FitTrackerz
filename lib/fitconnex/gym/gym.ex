defmodule Fitconnex.Gym.Gym do
  use Ash.Resource,
    domain: Fitconnex.Gym,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("gyms")
    repo(Fitconnex.Repo)
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      accept([:name, :slug, :description, :owner_id])
    end

    update :update do
      accept([:name, :description, :status, :is_promoted])
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute :name, :string do
      allow_nil?(false)
    end

    attribute :slug, :ci_string do
      allow_nil?(false)
    end

    attribute(:description, :string)

    attribute :status, :atom do
      constraints(one_of: [:pending_verification, :verified, :suspended])
      allow_nil?(false)
      default(:pending_verification)
    end

    attribute :is_promoted, :boolean do
      allow_nil?(false)
      default(false)
    end

    timestamps()
  end

  relationships do
    belongs_to :owner, Fitconnex.Accounts.User do
      allow_nil?(false)
    end

    has_many :branches, Fitconnex.Gym.GymBranch
    has_many :gym_members, Fitconnex.Gym.GymMember
    has_many :gym_trainers, Fitconnex.Gym.GymTrainer
    has_many :member_invitations, Fitconnex.Gym.MemberInvitation
    has_many :trainer_invitations, Fitconnex.Gym.TrainerInvitation
  end

  identities do
    identity(:unique_slug, [:slug])
  end
end
