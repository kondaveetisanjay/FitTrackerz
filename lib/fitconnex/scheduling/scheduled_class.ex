defmodule Fitconnex.Scheduling.ScheduledClass do
  use Ash.Resource,
    domain: Fitconnex.Scheduling,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("scheduled_classes")
    repo(Fitconnex.Repo)
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      accept([:scheduled_at, :duration_minutes, :class_definition_id, :branch_id, :trainer_id])
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
    belongs_to :class_definition, Fitconnex.Scheduling.ClassDefinition do
      allow_nil?(false)
    end

    belongs_to :branch, Fitconnex.Gym.GymBranch do
      allow_nil?(false)
    end

    belongs_to :trainer, Fitconnex.Accounts.User

    has_many :bookings, Fitconnex.Scheduling.ClassBooking
  end
end
