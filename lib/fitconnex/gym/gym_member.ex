defmodule Fitconnex.Gym.GymMember do
  use Ash.Resource,
    domain: Fitconnex.Gym,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("gym_members")
    repo(Fitconnex.Repo)

    references do
      reference :gym, on_delete: :delete
      reference :user, on_delete: :delete
      reference :assigned_trainer, on_delete: :nilify
      reference :branch, on_delete: :nilify
    end

    custom_indexes do
      index([:user_id])
      index([:gym_id])
      index([:branch_id])
      index([:assigned_trainer_id])
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
    end

    read :list_active_by_user do
      argument :user_id, :uuid, allow_nil?: false
      filter expr(user_id == ^arg(:user_id) and is_active == true)
      prepare build(load: [:gym, :assigned_trainer, :branch])
    end

    read :list_by_gym do
      argument :gym_id, :uuid, allow_nil?: false
      filter expr(gym_id == ^arg(:gym_id))
      prepare build(load: [:user, assigned_trainer: [:user]])
    end

    read :list_by_assigned_trainer do
      argument :trainer_ids, {:array, :uuid}, allow_nil?: false
      filter expr(assigned_trainer_id in ^arg(:trainer_ids))
      prepare build(load: [:user, :gym])
    end

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
