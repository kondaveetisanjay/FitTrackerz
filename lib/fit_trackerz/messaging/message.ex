defmodule FitTrackerz.Messaging.Message do
  use Ash.Resource,
    domain: FitTrackerz.Messaging,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("messages")
    repo(FitTrackerz.Repo)

    references do
      reference :conversation, on_delete: :delete
      reference :sender, on_delete: :delete
    end

    custom_indexes do
      index([:conversation_id, :inserted_at])
      index([:sender_id])
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

    policy action_type([:create, :destroy]) do
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
      prepare build(sort: [inserted_at: :asc], load: [:sender])
    end

    read :latest_by_conversation do
      argument :conversation_id, :uuid, allow_nil?: false
      filter expr(conversation_id == ^arg(:conversation_id))
      prepare build(sort: [inserted_at: :desc], limit: 1, load: [:sender])
    end

    create :create do
      accept([:body, :attachments, :conversation_id, :sender_id])
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute :body, :string do
      allow_nil?(false)
      constraints(max_length: 5000)
    end

    attribute :attachments, {:array, :map} do
      default([])
    end

    timestamps()
  end

  relationships do
    belongs_to :conversation, FitTrackerz.Messaging.Conversation do
      allow_nil?(false)
    end

    belongs_to :sender, FitTrackerz.Accounts.User do
      allow_nil?(false)
    end
  end
end
