defmodule Fitconnex.Gym.Gym do
  use Ash.Resource,
    domain: Fitconnex.Gym,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("gyms")
    repo(Fitconnex.Repo)

    references do
      reference :owner, on_delete: :restrict
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
    end

    read :list_verified do
      filter expr(status == :verified)
      prepare build(load: [:branches])
    end

    read :list_by_owner do
      argument :owner_id, :uuid, allow_nil?: false
      filter expr(owner_id == ^arg(:owner_id))
      prepare build(load: [:branches, :gym_members, :member_invitations])
    end

    read :list_pending_verification do
      filter expr(status == :pending_verification)
      prepare build(load: [:owner])
    end

    read :get_by_slug do
      get? true
      argument :slug, :ci_string, allow_nil?: false
      filter expr(slug == ^arg(:slug) and status == :verified)
      prepare build(load: [:branches])
    end

    create :create do
      accept([:name, :slug, :description, :owner_id, :phone, :equipment, :services])

      validate string_length(:name, min: 1, max: 255)
      validate string_length(:slug, min: 1, max: 255)
    end

    update :update do
      accept([:name, :slug, :description, :status, :is_promoted, :phone, :equipment, :services])
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute :name, :string do
      allow_nil?(false)
      constraints(max_length: 255)
    end

    attribute :slug, :ci_string do
      allow_nil?(false)
      constraints(max_length: 255)
    end

    attribute :description, :string do
      constraints(max_length: 2000)
    end

    attribute :status, :atom do
      constraints(one_of: [:pending_verification, :verified, :suspended])
      allow_nil?(false)
      default(:pending_verification)
    end

    attribute :is_promoted, :boolean do
      allow_nil?(false)
      default(false)
    end

    attribute :phone, :string do
      constraints max_length: 20
      allow_nil? true
      public? true
    end

    attribute :equipment, {:array, :string} do
      default []
      public? true
    end

    attribute :services, {:array, :string} do
      default []
      public? true
    end

    timestamps()
  end

  relationships do
    belongs_to :owner, Fitconnex.Accounts.User do
      allow_nil?(false)
    end

    has_many :branches, Fitconnex.Gym.GymBranch
    has_many :gym_members, Fitconnex.Gym.GymMember
    has_many :member_invitations, Fitconnex.Gym.MemberInvitation
  end

  identities do
    identity(:unique_slug, [:slug])
  end
end
