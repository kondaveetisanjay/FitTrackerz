defmodule FitTrackerz.Scheduling.ClassBooking do
  use Ash.Resource,
    domain: FitTrackerz.Scheduling,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("class_bookings")
    repo(FitTrackerz.Repo)

    references do
      reference :scheduled_class, on_delete: :delete
      reference :member, on_delete: :delete
    end

    custom_indexes do
      index([:member_id])
      index([:scheduled_class_id])
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
      authorize_if actor_attribute_equals(:role, :member)
    end
  end

  actions do
    defaults([:read, :destroy])

    read :list_by_member do
      argument :member_ids, {:array, :uuid}, allow_nil?: false
      filter expr(member_id in ^arg(:member_ids))
      prepare build(load: [scheduled_class: [:class_definition, :trainer, :branch]])
    end

    create :create do
      accept([:scheduled_class_id, :member_id])
      validate(FitTrackerz.Scheduling.Validations.ValidateActiveSubscription)
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
    belongs_to :scheduled_class, FitTrackerz.Scheduling.ScheduledClass do
      allow_nil?(false)
    end

    belongs_to :member, FitTrackerz.Gym.GymMember do
      allow_nil?(false)
    end
  end

  identities do
    identity(:unique_booking, [:scheduled_class_id, :member_id])
  end
end
