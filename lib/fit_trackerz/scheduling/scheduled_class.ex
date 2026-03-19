defmodule FitTrackerz.Scheduling.ScheduledClass do
  use Ash.Resource,
    domain: FitTrackerz.Scheduling,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("scheduled_classes")
    repo(FitTrackerz.Repo)

    references do
      reference :class_definition, on_delete: :delete
      reference :branch, on_delete: :delete
    end

    custom_indexes do
      index([:branch_id])
      index([:scheduled_at])
      index([:class_definition_id])
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

    read :list_scheduled_by_branch do
      argument :branch_ids, {:array, :uuid}, allow_nil?: false
      filter expr(branch_id in ^arg(:branch_ids) and status == :scheduled)
      prepare build(load: [:class_definition, :branch, :bookings])
    end

    read :list_by_trainer do
      argument :trainer_ids, {:array, :uuid}, allow_nil?: false
      filter expr(trainer_id in ^arg(:trainer_ids))
      prepare build(load: [:class_definition, :branch])
    end

    create :create do
      accept([:scheduled_at, :duration_minutes, :class_definition_id, :branch_id, :trainer_id])

      validate numericality(:duration_minutes, greater_than: 0)
    end

    update :update do
      accept([:scheduled_at, :duration_minutes, :status])
    end

    update :complete do
      accept([])
      change(set_attribute(:status, :completed))
    end

    update :cancel do
      accept([])
      change(set_attribute(:status, :cancelled))
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute :scheduled_at, :utc_datetime do
      allow_nil?(false)
    end

    attribute :duration_minutes, :integer do
      allow_nil?(false)
    end

    attribute :status, :atom do
      constraints(one_of: [:scheduled, :completed, :cancelled])
      allow_nil?(false)
      default(:scheduled)
    end

    timestamps()
  end

  relationships do
    belongs_to :class_definition, FitTrackerz.Scheduling.ClassDefinition do
      allow_nil?(false)
    end

    belongs_to :branch, FitTrackerz.Gym.GymBranch do
      allow_nil?(false)
    end

    has_many :bookings, FitTrackerz.Scheduling.ClassBooking

    belongs_to :trainer, FitTrackerz.Gym.GymTrainer
  end
end
