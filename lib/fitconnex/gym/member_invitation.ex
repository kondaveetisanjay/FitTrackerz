defmodule Fitconnex.Gym.MemberInvitation do
  use Ash.Resource,
    domain: Fitconnex.Gym,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("member_invitations")
    repo(Fitconnex.Repo)

    references do
      reference :gym, on_delete: :delete
      reference :invited_by, on_delete: :nilify
      reference :branch, on_delete: :nilify
    end

    custom_indexes do
      index([:gym_id])
      index([:invited_email])
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
      prepare build(load: [:gym, :invited_by, :branch])
    end

    read :list_pending_by_email do
      argument :email, :ci_string, allow_nil?: false
      filter expr(invited_email == ^arg(:email) and status == :pending)
      prepare build(load: [:gym, :invited_by, :branch])
    end

    create :create do
      accept([:invited_email, :gym_id, :invited_by_id, :branch_id])

      validate match(:invited_email, ~r/^[^\s]+@[^\s]+\.[^\s]+$/),
        message: "must be a valid email address"
    end

    update :accept do
      accept([])
      require_atomic?(false)

      change(set_attribute(:status, :accepted))
      change(Fitconnex.Gym.Changes.CreateGymMemberOnAccept)
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

  identities do
    identity :unique_pending_invitation, [:gym_id, :invited_email],
      where: expr(status == :pending)
  end

  relationships do
    belongs_to :gym, Fitconnex.Gym.Gym do
      allow_nil?(false)
    end

    belongs_to :invited_by, Fitconnex.Accounts.User do
      allow_nil?(false)
    end

    belongs_to :branch, Fitconnex.Gym.GymBranch
  end
end
