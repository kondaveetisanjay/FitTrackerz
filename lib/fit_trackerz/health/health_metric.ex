defmodule FitTrackerz.Health.HealthMetric do
  use Ash.Resource,
    domain: FitTrackerz.Health,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("health_metrics")
    repo(FitTrackerz.Repo)

    references do
      reference :member, on_delete: :delete
      reference :gym, on_delete: :delete
    end

    custom_indexes do
      index([:member_id])
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

    read :latest_by_member do
      argument :member_ids, {:array, :uuid}, allow_nil?: false
      filter expr(member_id in ^arg(:member_ids))
      prepare build(sort: [recorded_on: :desc], limit: 1)
    end

    create :create do
      accept([:member_id, :gym_id, :recorded_on, :weight_kg, :height_cm, :body_fat_pct, :notes])

      change fn changeset, _context ->
        weight = Ash.Changeset.get_argument_or_attribute(changeset, :weight_kg)
        height = Ash.Changeset.get_argument_or_attribute(changeset, :height_cm)

        if weight && height do
          height_m = Decimal.div(height, Decimal.new(100))
          bmi =
            Decimal.div(weight, Decimal.mult(height_m, height_m))
            |> Decimal.round(1)

          Ash.Changeset.change_attribute(changeset, :bmi, bmi)
        else
          changeset
        end
      end
    end

    update :update do
      accept([:weight_kg, :height_cm, :body_fat_pct, :notes])
      require_atomic? false

      change fn changeset, _context ->
        weight =
          Ash.Changeset.get_argument_or_attribute(changeset, :weight_kg) ||
            changeset.data.weight_kg

        height =
          Ash.Changeset.get_argument_or_attribute(changeset, :height_cm) ||
            changeset.data.height_cm

        if weight && height do
          height_m = Decimal.div(height, Decimal.new(100))
          bmi =
            Decimal.div(weight, Decimal.mult(height_m, height_m))
            |> Decimal.round(1)

          Ash.Changeset.change_attribute(changeset, :bmi, bmi)
        else
          changeset
        end
      end
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute :recorded_on, :date do
      allow_nil?(false)
    end

    attribute :weight_kg, :decimal do
      allow_nil?(false)
      constraints(min: 1)
    end

    attribute :height_cm, :decimal do
      allow_nil?(true)
      constraints(min: 50, max: 300)
    end

    attribute :bmi, :decimal do
      allow_nil?(true)
    end

    attribute :body_fat_pct, :decimal do
      allow_nil?(true)
      constraints(min: 1, max: 70)
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

    belongs_to :gym, FitTrackerz.Gym.Gym do
      allow_nil?(false)
    end
  end

  identities do
    identity :unique_member_date, [:member_id, :recorded_on]
  end
end
