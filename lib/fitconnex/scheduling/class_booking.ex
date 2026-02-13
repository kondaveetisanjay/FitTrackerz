defmodule Fitconnex.Scheduling.ClassBooking do
  use Ash.Resource,
    domain: Fitconnex.Scheduling,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("class_bookings")
    repo(Fitconnex.Repo)
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      accept([:scheduled_class_id, :member_id])
      require_atomic?(false)
      validate(Fitconnex.Scheduling.Validations.ValidateActiveSubscription)
    end

    update :confirm do
      accept([])
      change(set_attribute(:status, :confirmed))
    end

    update :decline do
      accept([])
      change(set_attribute(:status, :declined))
    end

    update :cancel do
      accept([])
      change(set_attribute(:status, :cancelled))
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute :status, :atom do
      constraints(one_of: [:pending, :confirmed, :declined, :cancelled])
      allow_nil?(false)
      default(:pending)
    end

    timestamps()
  end

  relationships do
    belongs_to :scheduled_class, Fitconnex.Scheduling.ScheduledClass do
      allow_nil?(false)
    end

    belongs_to :member, Fitconnex.Gym.GymMember do
      allow_nil?(false)
    end
  end

  identities do
    identity(:unique_booking, [:scheduled_class_id, :member_id])
  end
end
