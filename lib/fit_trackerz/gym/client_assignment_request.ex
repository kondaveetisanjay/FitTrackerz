defmodule FitTrackerz.Gym.ClientAssignmentRequest do
  use Ash.Resource,
    domain: FitTrackerz.Gym,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("client_assignment_requests")
    repo(FitTrackerz.Repo)

    references do
      reference :gym, on_delete: :delete
      reference :member, on_delete: :delete
      reference :trainer, on_delete: :delete
      reference :requested_by, on_delete: :delete
    end

    custom_indexes do
      index([:gym_id])
      index([:member_id])
      index([:trainer_id])
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
      authorize_if actor_attribute_equals(:role, :trainer)
    end
  end

  actions do
    defaults([:read, :destroy])

    read :get_by_id do
      get? true
      argument :id, :uuid, allow_nil?: false
      filter expr(id == ^arg(:id))
      prepare build(load: [:gym, :requested_by, member: [:user]])
    end

    read :list_pending_by_trainer do
      argument :trainer_ids, {:array, :uuid}, allow_nil?: false
      filter expr(trainer_id in ^arg(:trainer_ids) and status == :pending)
      prepare build(load: [:gym, :requested_by, member: [:user]])
    end

    create :create do
      accept([:gym_id, :member_id, :trainer_id, :requested_by_id])
    end

    update :accept do
      accept([])
      require_atomic?(false)

      change(set_attribute(:status, :accepted))
      change(FitTrackerz.Gym.Changes.AssignTrainerOnAccept)
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
    belongs_to :gym, FitTrackerz.Gym.Gym do
      allow_nil?(false)
    end

    belongs_to :member, FitTrackerz.Gym.GymMember do
      allow_nil?(false)
    end

    belongs_to :trainer, FitTrackerz.Gym.GymTrainer do
      allow_nil?(false)
    end

    belongs_to :requested_by, FitTrackerz.Accounts.User do
      allow_nil?(false)
    end
  end
end
