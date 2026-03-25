defmodule FitTrackerz.Messaging.ConversationParticipant do
  use Ash.Resource,
    domain: FitTrackerz.Messaging,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("conversation_participants")
    repo(FitTrackerz.Repo)

    references do
      reference :conversation, on_delete: :delete
      reference :user, on_delete: :delete
    end

    custom_indexes do
      index([:user_id])
      index([:conversation_id])
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

    read :list_by_conversation do
      argument :conversation_id, :uuid, allow_nil?: false
      filter expr(conversation_id == ^arg(:conversation_id))
      prepare build(load: [:user])
    end

    read :list_by_user do
      argument :user_id, :uuid, allow_nil?: false
      filter expr(user_id == ^arg(:user_id))
      prepare build(load: [:conversation])
    end

    create :create do
      accept([:conversation_id, :user_id, :role])
    end

    update :mark_read do
      accept([])
      change set_attribute(:last_read_at, &DateTime.utc_now/0)
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute :role, :atom do
      constraints(one_of: [:owner, :participant])
      allow_nil?(false)
      default(:participant)
    end

    attribute :last_read_at, :utc_datetime_usec

    timestamps()
  end

  relationships do
    belongs_to :conversation, FitTrackerz.Messaging.Conversation do
      allow_nil?(false)
    end

    belongs_to :user, FitTrackerz.Accounts.User do
      allow_nil?(false)
    end
  end

  identities do
    identity :unique_conversation_user, [:conversation_id, :user_id]
  end
end
