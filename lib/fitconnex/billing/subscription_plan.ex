defmodule Fitconnex.Billing.SubscriptionPlan do
  use Ash.Resource,
    domain: Fitconnex.Billing,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("subscription_plans")
    repo(Fitconnex.Repo)

    references do
      reference :gym, on_delete: :delete
    end

    custom_indexes do
      index([:gym_id])
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

    read :list_by_gym do
      argument :gym_id, :uuid, allow_nil?: false
      filter expr(gym_id == ^arg(:gym_id))
    end

    create :create do
      accept([:name, :plan_type, :duration, :price_in_paise, :gym_id, :category])

      validate string_length(:name, min: 1, max: 255)
      validate numericality(:price_in_paise, greater_than_or_equal_to: 0)
    end

    update :update do
      accept([:name, :plan_type, :duration, :price_in_paise, :category])

      validate string_length(:name, min: 1, max: 255)
      validate numericality(:price_in_paise, greater_than_or_equal_to: 0)
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute :name, :string do
      allow_nil?(false)
      constraints(max_length: 255)
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

    attribute :category, :string do
      allow_nil?(true)
      constraints(max_length: 100)
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
