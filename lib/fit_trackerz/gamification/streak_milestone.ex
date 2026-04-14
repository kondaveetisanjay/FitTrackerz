defmodule FitTrackerz.Gamification.StreakMilestone do
  use Ash.Resource,
    domain: FitTrackerz.Gamification,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("gamification_streak_milestones")
    repo(FitTrackerz.Repo)

    references do
      reference :gym_member, on_delete: :delete
    end

    custom_indexes do
      index([:gym_member_id])
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

    policy action_type(:create) do
      forbid_if always()
    end
  end

  actions do
    defaults([:read])

    read :list_by_member do
      argument :gym_member_id, :uuid, allow_nil?: false
      filter expr(gym_member_id == ^arg(:gym_member_id))
      prepare build(sort: [achieved_at: :desc])
    end

    create :create do
      accept([:gym_member_id, :streak_type, :milestone_days, :achieved_at])
      upsert? true
      upsert_identity :unique_member_milestone
      upsert_fields []

      validate fn changeset, _context ->
        days = Ash.Changeset.get_attribute(changeset, :milestone_days)

        if days in [7, 30, 90, 365] do
          :ok
        else
          {:error, field: :milestone_days, message: "must be one of: 7, 30, 90, 365"}
        end
      end
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute :streak_type, :atom do
      constraints(one_of: [:workout, :attendance])
      allow_nil?(false)
    end

    attribute :milestone_days, :integer do
      constraints(min: 1)
      allow_nil?(false)
    end

    attribute :achieved_at, :utc_datetime do
      allow_nil?(false)
    end

    timestamps()
  end

  relationships do
    belongs_to :gym_member, FitTrackerz.Gym.GymMember do
      allow_nil?(false)
    end
  end

  identities do
    identity :unique_member_milestone, [:gym_member_id, :streak_type, :milestone_days]
  end
end
