defmodule FitTrackerz.Health.BodyMeasurement do
  use Ash.Resource,
    domain: FitTrackerz.Health,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("health_body_measurements")
    repo(FitTrackerz.Repo)

    references do
      reference :member, on_delete: :delete
    end

    custom_indexes do
      index([:member_id])
      index([:member_id, :recorded_on])
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
      prepare build(sort: [recorded_on: :desc])
    end

    create :create do
      accept([
        :member_id,
        :recorded_on,
        :weight_kg,
        :body_fat_pct,
        :muscle_mass_kg,
        :chest_cm,
        :waist_cm,
        :hips_cm,
        :bicep_cm,
        :thigh_cm,
        :notes
      ])

      upsert? true
      upsert_identity :unique_member_date
      upsert_fields [
        :weight_kg,
        :body_fat_pct,
        :muscle_mass_kg,
        :chest_cm,
        :waist_cm,
        :hips_cm,
        :bicep_cm,
        :thigh_cm,
        :notes,
        :updated_at
      ]
    end

    update :update do
      accept([
        :weight_kg,
        :body_fat_pct,
        :muscle_mass_kg,
        :chest_cm,
        :waist_cm,
        :hips_cm,
        :bicep_cm,
        :thigh_cm,
        :notes
      ])
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute :recorded_on, :date do
      allow_nil?(false)
    end

    attribute :weight_kg, :decimal do
      allow_nil?(true)
      constraints(min: 1, max: 500)
    end

    attribute :body_fat_pct, :decimal do
      allow_nil?(true)
      constraints(min: 1, max: 70)
    end

    attribute :muscle_mass_kg, :decimal do
      allow_nil?(true)
      constraints(min: 1, max: 300)
    end

    attribute :chest_cm, :decimal do
      allow_nil?(true)
      constraints(min: 1, max: 300)
    end

    attribute :waist_cm, :decimal do
      allow_nil?(true)
      constraints(min: 1, max: 300)
    end

    attribute :hips_cm, :decimal do
      allow_nil?(true)
      constraints(min: 1, max: 300)
    end

    attribute :bicep_cm, :decimal do
      allow_nil?(true)
      constraints(min: 1, max: 100)
    end

    attribute :thigh_cm, :decimal do
      allow_nil?(true)
      constraints(min: 1, max: 200)
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

  identities do
    identity :unique_member_date, [:member_id, :recorded_on]
  end
end
