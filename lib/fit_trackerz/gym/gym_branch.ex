defmodule FitTrackerz.Gym.GymBranch do
  use Ash.Resource,
    domain: FitTrackerz.Gym,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("gym_branches")
    repo(FitTrackerz.Repo)

    references do
      reference :gym, on_delete: :delete
    end

    custom_indexes do
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

    read :list_by_gym do
      argument :gym_id, :uuid, allow_nil?: false
      filter expr(gym_id == ^arg(:gym_id))
    end

    create :create do
      accept([
        :address, :city, :state, :postal_code, :latitude, :longitude,
        :gym_id, :logo_url, :gallery_urls
      ])

      validate string_length(:address, min: 1, max: 500)
      validate string_length(:city, min: 1, max: 100)
      validate string_length(:state, min: 1, max: 100)
      validate string_length(:postal_code, min: 1, max: 20)
    end

    update :update do
      accept([
        :address, :city, :state, :postal_code, :latitude, :longitude,
        :logo_url, :gallery_urls
      ])
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute :address, :string do
      allow_nil?(false)
      constraints(max_length: 500)
    end

    attribute :city, :string do
      allow_nil?(false)
      constraints(max_length: 100)
    end

    attribute :state, :string do
      allow_nil?(false)
      constraints(max_length: 100)
    end

    attribute :postal_code, :string do
      allow_nil?(false)
      constraints(max_length: 20)
    end

    attribute(:latitude, :float)
    attribute(:longitude, :float)

    attribute :logo_url, :string do
      allow_nil?(true)
    end

    attribute :gallery_urls, {:array, :string} do
      allow_nil?(false)
      default([])
    end

    attribute :is_primary, :boolean do
      allow_nil?(false)
      default(false)
    end

    timestamps()
  end

  relationships do
    belongs_to :gym, FitTrackerz.Gym.Gym do
      allow_nil?(false)
    end

    has_many :gym_members, FitTrackerz.Gym.GymMember do
      destination_attribute(:branch_id)
    end

  end
end
