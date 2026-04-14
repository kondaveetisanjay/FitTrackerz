defmodule FitTrackerz.Billing.SubscriptionPlan do
  use Ash.Resource,
    domain: FitTrackerz.Billing,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  import Ecto.Query, only: [from: 2]

  postgres do
    table("subscription_plans")
    repo(FitTrackerz.Repo)

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
      accept([:name, :plan_type, :duration, :price_in_paise, :gym_id, :category, :features])

      validate string_length(:name, min: 1, max: 255)
      validate numericality(:price_in_paise, greater_than_or_equal_to: 0)

      validate fn changeset, _context ->
        plan_type = Ash.Changeset.get_attribute(changeset, :plan_type)
        gym_id = Ash.Changeset.get_attribute(changeset, :gym_id)

        if plan_type == :personal_training && gym_id do
          tier =
            from(g in FitTrackerz.Gym.Gym, where: g.id == ^gym_id, select: g.tier)
            |> FitTrackerz.Repo.one()

          if tier != :premium do
            {:error,
             field: :gym_id,
             message:
               "Personal Training plans require a Premium gym tier. Upgrade your gym to create this plan type."}
          else
            :ok
          end
        else
          :ok
        end
      end
    end

    update :update do
      accept([:name, :plan_type, :duration, :price_in_paise, :category, :features])

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

    attribute :features, {:array, :string} do
      default []
      public? true
    end

    timestamps()
  end

  relationships do
    belongs_to :gym, FitTrackerz.Gym.Gym do
      allow_nil?(false)
    end

    has_many :member_subscriptions, FitTrackerz.Billing.MemberSubscription
  end
end
