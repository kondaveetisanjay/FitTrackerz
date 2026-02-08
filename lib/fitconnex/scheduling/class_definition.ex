defmodule Fitconnex.Scheduling.ClassDefinition do
  use Ash.Resource,
    domain: Fitconnex.Scheduling,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("class_definitions")
    repo(Fitconnex.Repo)
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      accept([:name, :class_type, :default_duration_minutes, :max_participants, :gym_id])
    end

    update :update do
      accept([:name, :class_type, :default_duration_minutes, :max_participants])
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute :name, :string do
      allow_nil?(false)
    end

    attribute :class_type, :string do
      allow_nil?(false)
    end

    attribute :default_duration_minutes, :integer do
      allow_nil?(false)
    end

    attribute(:max_participants, :integer)

    timestamps()
  end

  relationships do
    belongs_to :gym, Fitconnex.Gym.Gym do
      allow_nil?(false)
    end

    has_many :scheduled_classes, Fitconnex.Scheduling.ScheduledClass
  end
end
