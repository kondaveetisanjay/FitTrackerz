defmodule FitTrackerz.Scheduling.ClassDefinition do
  use Ash.Resource,
    domain: FitTrackerz.Scheduling,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("class_definitions")
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
      accept([:name, :class_type, :default_duration_minutes, :max_participants, :gym_id])

      validate string_length(:name, min: 1, max: 255)
      validate string_length(:class_type, min: 1, max: 100)
      validate numericality(:default_duration_minutes, greater_than: 0)
      validate numericality(:max_participants, greater_than: 0)
    end

    update :update do
      accept([:name, :class_type, :default_duration_minutes, :max_participants])

      validate string_length(:name, min: 1, max: 255)
      validate numericality(:default_duration_minutes, greater_than: 0)
      validate numericality(:max_participants, greater_than: 0)
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute :name, :string do
      allow_nil?(false)
      constraints(max_length: 255)
    end

    attribute :class_type, :string do
      allow_nil?(false)
      constraints(max_length: 100)
    end

    attribute :default_duration_minutes, :integer do
      allow_nil?(false)
    end

    attribute(:max_participants, :integer)

    timestamps()
  end

  relationships do
    belongs_to :gym, FitTrackerz.Gym.Gym do
      allow_nil?(false)
    end

    has_many :scheduled_classes, FitTrackerz.Scheduling.ScheduledClass
  end
end
