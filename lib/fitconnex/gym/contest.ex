defmodule Fitconnex.Gym.Contest do
  use Ash.Resource,
    domain: Fitconnex.Gym,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("contests")
    repo(Fitconnex.Repo)

    references do
      reference :gym, on_delete: :delete
      reference :branch, on_delete: :nilify
    end

    custom_indexes do
      index([:gym_id])
      index([:status])
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

    read :get_by_id do
      get? true
      argument :id, :uuid, allow_nil?: false
      filter expr(id == ^arg(:id))
      prepare build(load: [:gym, :branch])
    end

    read :list_public do
      filter expr(status in [:upcoming, :active])
      prepare build(load: [:gym])
    end

    read :list_by_gym do
      argument :gym_id, :uuid, allow_nil?: false
      filter expr(gym_id == ^arg(:gym_id))
      prepare build(load: [:branch])
    end

    create :create do
      accept([
        :title, :description, :contest_type, :status,
        :starts_at, :ends_at, :max_participants,
        :prize_description, :banner_url, :gym_id, :branch_id
      ])
    end

    update :update do
      accept([
        :title, :description, :contest_type, :status,
        :starts_at, :ends_at, :max_participants,
        :prize_description, :banner_url, :branch_id
      ])
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute :title, :string do
      allow_nil?(false)
      public?(true)
      constraints(max_length: 255)
    end

    attribute :description, :string do
      allow_nil?(true)
      public?(true)
      constraints(max_length: 2000)
    end

    attribute :contest_type, :atom do
      constraints(one_of: [:challenge, :competition, :event, :other])
      allow_nil?(false)
      public?(true)
    end

    attribute :status, :atom do
      constraints(one_of: [:upcoming, :active, :completed, :cancelled])
      allow_nil?(false)
      default(:upcoming)
      public?(true)
    end

    attribute :starts_at, :utc_datetime do
      allow_nil?(false)
      public?(true)
    end

    attribute :ends_at, :utc_datetime do
      allow_nil?(false)
      public?(true)
    end

    attribute :max_participants, :integer do
      allow_nil?(true)
      public?(true)
    end

    attribute :prize_description, :string do
      allow_nil?(true)
      public?(true)
      constraints(max_length: 1000)
    end

    attribute :banner_url, :string do
      allow_nil?(true)
      public?(true)
    end

    timestamps()
  end

  relationships do
    belongs_to :gym, Fitconnex.Gym.Gym do
      allow_nil?(false)
    end

    belongs_to :branch, Fitconnex.Gym.GymBranch
  end
end
