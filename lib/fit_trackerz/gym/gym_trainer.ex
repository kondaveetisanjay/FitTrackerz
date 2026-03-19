defmodule FitTrackerz.Gym.GymTrainer do
  use Ash.Resource,
    domain: FitTrackerz.Gym,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("gym_trainers")
    repo(FitTrackerz.Repo)

    references do
      reference :gym, on_delete: :delete
      reference :user, on_delete: :delete
      reference :branch, on_delete: :nilify
    end

    custom_indexes do
      index([:user_id])
      index([:gym_id])
      index([:branch_id])
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

    read :list_active_by_user do
      argument :user_id, :uuid, allow_nil?: false
      filter expr(user_id == ^arg(:user_id) and is_active == true)
      prepare build(load: [:gym])
    end

    read :list_by_gym do
      argument :gym_id, :uuid, allow_nil?: false
      filter expr(gym_id == ^arg(:gym_id))
      prepare build(load: [:user])
    end

    read :list_active_by_gym do
      argument :gym_id, :uuid, allow_nil?: false
      filter expr(gym_id == ^arg(:gym_id) and is_active == true)
      prepare build(load: [:user])
    end

    create :create do
      accept([:user_id, :gym_id, :specializations, :branch_id])
    end

    update :update do
      accept([:specializations, :is_active, :branch_id])
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute :specializations, {:array, :string} do
      default([])
    end

    attribute :is_active, :boolean do
      allow_nil?(false)
      default(true)
    end

    timestamps()
  end

  relationships do
    belongs_to :user, FitTrackerz.Accounts.User do
      allow_nil?(false)
    end

    belongs_to :gym, FitTrackerz.Gym.Gym do
      allow_nil?(false)
    end

    belongs_to :branch, FitTrackerz.Gym.GymBranch

    has_many :scheduled_classes, FitTrackerz.Scheduling.ScheduledClass do
      destination_attribute(:trainer_id)
    end

    has_many :workout_plans, FitTrackerz.Training.WorkoutPlan do
      destination_attribute(:trainer_id)
    end

    has_many :diet_plans, FitTrackerz.Training.DietPlan do
      destination_attribute(:trainer_id)
    end

    has_many :assigned_members, FitTrackerz.Gym.GymMember do
      destination_attribute(:assigned_trainer_id)
    end
  end

  identities do
    identity(:unique_trainer_gym, [:user_id, :gym_id])
  end
end
