defmodule FitTrackerz.Health.ProgressPhoto do
  use Ash.Resource,
    domain: FitTrackerz.Health,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("health_progress_photos")
    repo(FitTrackerz.Repo)

    references do
      reference :member, on_delete: :delete
    end

    custom_indexes do
      index([:member_id])
      index([:member_id, :taken_on])
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
      authorize_if actor_attribute_equals(:role, :member)
    end
  end

  actions do
    defaults([:read, :destroy])

    read :list_by_member do
      argument :member_ids, {:array, :uuid}, allow_nil?: false
      filter expr(member_id in ^arg(:member_ids))
      prepare build(sort: [taken_on: :desc])
    end

    read :list_shared_with_trainer do
      argument :member_ids, {:array, :uuid}, allow_nil?: false
      filter expr(member_id in ^arg(:member_ids) and shared_with_trainer == true)
      prepare build(sort: [taken_on: :desc])
    end

    create :create do
      accept([:member_id, :taken_on, :photo_url, :category, :shared_with_trainer, :notes])

      validate string_length(:photo_url, min: 1, max: 500)
    end

    update :update do
      accept([:shared_with_trainer, :notes, :category])
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute :taken_on, :date do
      allow_nil?(false)
    end

    attribute :photo_url, :string do
      allow_nil?(false)
      constraints(max_length: 500)
    end

    attribute :category, :atom do
      constraints(one_of: [:front, :side, :back, :other])
      allow_nil?(false)
      default(:front)
    end

    attribute :shared_with_trainer, :boolean do
      allow_nil?(false)
      default(false)
    end

    attribute :notes, :string do
      allow_nil?(true)
      constraints(max_length: 500)
    end

    timestamps()
  end

  relationships do
    belongs_to :member, FitTrackerz.Gym.GymMember do
      allow_nil?(false)
    end
  end
end
