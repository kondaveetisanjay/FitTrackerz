defmodule Fitconnex.Gym.GymBranch do
  use Ash.Resource,
    domain: Fitconnex.Gym,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("gym_branches")
    repo(Fitconnex.Repo)
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      accept([:address, :city, :state, :postal_code, :latitude, :longitude, :is_primary, :gym_id])
    end

    update :update do
      accept([:address, :city, :state, :postal_code, :latitude, :longitude, :is_primary])
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute :address, :string do
      allow_nil?(false)
    end

    attribute :city, :string do
      allow_nil?(false)
    end

    attribute :state, :string do
      allow_nil?(false)
    end

    attribute :postal_code, :string do
      allow_nil?(false)
    end

    attribute(:latitude, :float)
    attribute(:longitude, :float)

    attribute :is_primary, :boolean do
      allow_nil?(false)
      default(false)
    end

    timestamps()
  end

  relationships do
    belongs_to :gym, Fitconnex.Gym.Gym do
      allow_nil?(false)
    end
  end
end
