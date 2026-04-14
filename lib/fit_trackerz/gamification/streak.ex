defmodule FitTrackerz.Gamification.Streak do
  use Ash.Resource,
    domain: FitTrackerz.Gamification,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("gamification_streaks")
    repo(FitTrackerz.Repo)

    references do
      reference :gym_member, on_delete: :delete
    end

    custom_indexes do
      index([:gym_member_id])
      index([:gym_member_id, :streak_type])
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

    policy action_type([:create, :update]) do
      forbid_if always()
    end
  end

  actions do
    defaults([:read, :destroy])

    read :list_by_member do
      argument :gym_member_id, :uuid, allow_nil?: false
      filter expr(gym_member_id == ^arg(:gym_member_id))
    end

    read :get_by_member_and_type do
      get? true
      argument :gym_member_id, :uuid, allow_nil?: false
      argument :streak_type, :atom, allow_nil?: false
      filter expr(gym_member_id == ^arg(:gym_member_id) and streak_type == ^arg(:streak_type))
    end

    create :create do
      accept([:gym_member_id, :streak_type, :current_streak, :longest_streak, :last_activity_date])
    end

    update :update do
      accept([:current_streak, :longest_streak, :last_activity_date])
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute :streak_type, :atom do
      constraints(one_of: [:workout, :attendance])
      allow_nil?(false)
    end

    attribute :current_streak, :integer do
      allow_nil?(false)
      default(0)
    end

    attribute :longest_streak, :integer do
      allow_nil?(false)
      default(0)
    end

    attribute :last_activity_date, :date

    timestamps()
  end

  relationships do
    belongs_to :gym_member, FitTrackerz.Gym.GymMember do
      allow_nil?(false)
    end
  end

  identities do
    identity :unique_member_streak_type, [:gym_member_id, :streak_type]
  end
end
