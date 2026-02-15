defmodule Fitconnex.Billing.MemberSubscription do
  use Ash.Resource,
    domain: Fitconnex.Billing,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("member_subscriptions")
    repo(Fitconnex.Repo)

    references do
      reference :member, on_delete: :delete
      reference :subscription_plan, on_delete: :restrict
      reference :gym, on_delete: :delete
    end

    custom_indexes do
      index([:member_id])
      index([:gym_id])
      index([:subscription_plan_id])
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

    read :list_active_by_member do
      argument :member_ids, {:array, :uuid}, allow_nil?: false
      filter expr(member_id in ^arg(:member_ids) and status == :active)
      prepare build(load: [:subscription_plan, :gym])
    end

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
