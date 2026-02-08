defmodule Fitconnex.Billing.SubscriptionPlan do
  use Ash.Resource,
    domain: Fitconnex.Billing,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("subscription_plans")
    repo(Fitconnex.Repo)
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      accept([:name, :plan_type, :duration, :price_in_paise, :gym_id])
    end

    update :update do
      accept([:name, :plan_type, :duration, :price_in_paise])
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute :name, :string do
      allow_nil?(false)
    end

    attribute :plan_type, :atom do
      constraints(one_of: [:general, :personal_training])
      allow_nil?(false)
    end

    attribute :duration, :atom do
      constraints(one_of: [:day_pass, :monthly, :quarterly, :half_yearly, :annual, :two_year])
      allow_nil?(false)
    end

    attribute :price_in_paise, :integer do
      allow_nil?(false)
    end

    timestamps()
  end

  relationships do
    belongs_to :gym, Fitconnex.Gym.Gym do
      allow_nil?(false)
    end

    has_many :member_subscriptions, Fitconnex.Billing.MemberSubscription
  end
end
