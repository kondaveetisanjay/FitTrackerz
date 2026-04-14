defmodule FitTrackerz.Notifications.Notification do
  use Ash.Resource,
    domain: FitTrackerz.Notifications,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("notifications")
    repo(FitTrackerz.Repo)

    references do
      reference :user, on_delete: :delete
      reference :gym, on_delete: :delete
    end

    custom_indexes do
      index([:user_id])
      index([:gym_id])
      index([:user_id, :is_read])
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
      authorize_if actor_attribute_equals(:role, :member)
    end
  end

  actions do
    defaults([:read, :destroy])

    read :list_by_user do
      argument :user_id, :uuid, allow_nil?: false
      filter expr(user_id == ^arg(:user_id))
      prepare build(sort: [inserted_at: :desc], limit: 50)
    end

    read :list_unread_by_user do
      argument :user_id, :uuid, allow_nil?: false
      filter expr(user_id == ^arg(:user_id) and is_read == false)
      prepare build(sort: [inserted_at: :desc])
    end

    read :count_unread_by_user do
      argument :user_id, :uuid, allow_nil?: false
      filter expr(user_id == ^arg(:user_id) and is_read == false)
    end

    create :create do
      accept([:type, :title, :message, :user_id, :gym_id, :metadata])
    end

    update :mark_read do
      accept([])
      change set_attribute(:is_read, true)
    end

    update :update do
      accept([:is_read])
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute :type, :atom do
      constraints(
        one_of: [
          :subscription_expiring,
          :subscription_expired,
          :payment_due,
          :payment_received,
          :invitation_received,
          :plan_assigned,
          :streak_milestone,
          :inactivity_reminder,
          :general
        ]
      )

      allow_nil?(false)
    end

    attribute :title, :string do
      allow_nil?(false)
      constraints(max_length: 255)
    end

    attribute :message, :string do
      allow_nil?(false)
      constraints(max_length: 1000)
    end

    attribute :is_read, :boolean do
      allow_nil?(false)
      default(false)
    end

    attribute :metadata, :map do
      default(%{})
    end

    timestamps()
  end

  relationships do
    belongs_to :user, FitTrackerz.Accounts.User do
      allow_nil?(false)
    end

    belongs_to :gym, FitTrackerz.Gym.Gym
  end
end
