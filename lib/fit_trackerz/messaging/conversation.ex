defmodule FitTrackerz.Messaging.Conversation do
  use Ash.Resource,
    domain: FitTrackerz.Messaging,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  require Ash.Query

  alias FitTrackerz.Messaging.{ConversationParticipant, Message}

  postgres do
    table("conversations")
    repo(FitTrackerz.Repo)

    references do
      reference :gym, on_delete: :delete
      reference :created_by, on_delete: :delete
    end

    custom_indexes do
      index([:gym_id])
      index([:created_by_id])
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

    read :get_by_id do
      get? true
      argument :id, :uuid, allow_nil?: false
      filter expr(id == ^arg(:id))
      prepare build(load: [participants: [:user], messages: [:sender], created_by: []])
    end

    read :list_by_participant do
      argument :user_id, :uuid, allow_nil?: false

      prepare fn query, _context ->
        uid = Ash.Query.get_argument(query, :user_id)

        query
        |> Ash.Query.filter(exists(participants, user_id == ^uid))
        |> Ash.Query.sort(updated_at: :desc)
        |> Ash.Query.load(participants: [:user], messages: [:sender], created_by: [])
      end
    end

    read :list_direct_by_participant do
      argument :user_id, :uuid, allow_nil?: false

      prepare fn query, _context ->
        uid = Ash.Query.get_argument(query, :user_id)

        query
        |> Ash.Query.filter(type == :direct and exists(participants, user_id == ^uid))
        |> Ash.Query.sort(updated_at: :desc)
        |> Ash.Query.load(participants: [:user], messages: [:sender], created_by: [])
      end
    end

    read :list_announcements_by_participant do
      argument :user_id, :uuid, allow_nil?: false

      prepare fn query, _context ->
        uid = Ash.Query.get_argument(query, :user_id)

        query
        |> Ash.Query.filter(type == :announcement and exists(participants, user_id == ^uid))
        |> Ash.Query.sort(updated_at: :desc)
        |> Ash.Query.load(participants: [:user], messages: [:sender], created_by: [])
      end
    end

    read :find_direct_between do
      argument :user_id_1, :uuid, allow_nil?: false
      argument :user_id_2, :uuid, allow_nil?: false
      argument :gym_id, :uuid, allow_nil?: false

      prepare fn query, _context ->
        gid = Ash.Query.get_argument(query, :gym_id)
        uid1 = Ash.Query.get_argument(query, :user_id_1)
        uid2 = Ash.Query.get_argument(query, :user_id_2)

        query
        |> Ash.Query.filter(
          type == :direct and
            gym_id == ^gid and
            exists(participants, user_id == ^uid1) and
            exists(participants, user_id == ^uid2)
        )
        |> Ash.Query.load(participants: [:user], messages: [:sender], created_by: [])
      end
    end

    create :create do
      accept([:type, :title, :gym_id, :created_by_id])
    end

    update :update do
      accept([:title])
    end

    update :touch do
      accept([])
      change set_attribute(:updated_at, &DateTime.utc_now/0)
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute :type, :atom do
      constraints(one_of: [:direct, :announcement])
      allow_nil?(false)
    end

    attribute :title, :string do
      constraints(max_length: 255)
    end

    timestamps()
  end

  relationships do
    belongs_to :gym, FitTrackerz.Gym.Gym do
      allow_nil?(false)
    end

    belongs_to :created_by, FitTrackerz.Accounts.User do
      allow_nil?(false)
    end

    has_many :participants, ConversationParticipant do
      destination_attribute(:conversation_id)
    end

    has_many :messages, Message do
      destination_attribute(:conversation_id)
    end
  end
end
