defmodule Fitconnex.Billing.MemberSubscription do
  use Ash.Resource,
    domain: Fitconnex.Billing,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("member_subscriptions")
    repo(Fitconnex.Repo)
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      accept([:member_id, :subscription_plan_id, :gym_id, :starts_at, :ends_at, :payment_status])
    end

    update :update do
      accept([:status, :payment_status])
    end

    update :cancel do
      accept([])
      change(set_attribute(:status, :cancelled))
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute :status, :atom do
      constraints(one_of: [:active, :cancelled, :expired])
      allow_nil?(false)
      default(:active)
    end

    attribute :starts_at, :utc_datetime do
      allow_nil?(false)
    end

    attribute :ends_at, :utc_datetime do
      allow_nil?(false)
    end

    attribute :payment_status, :atom do
      constraints(one_of: [:pending, :paid, :failed, :refunded])
      allow_nil?(false)
      default(:pending)
    end

    timestamps()
  end

  relationships do
    belongs_to :member, Fitconnex.Gym.GymMember do
      allow_nil?(false)
    end

    belongs_to :subscription_plan, Fitconnex.Billing.SubscriptionPlan do
      allow_nil?(false)
    end

    belongs_to :gym, Fitconnex.Gym.Gym do
      allow_nil?(false)
    end
  end
end
