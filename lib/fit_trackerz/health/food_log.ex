defmodule FitTrackerz.Health.FoodLog do
  use Ash.Resource,
    domain: FitTrackerz.Health,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("food_logs")
    repo(FitTrackerz.Repo)

    references do
      reference :member, on_delete: :delete
      reference :gym, on_delete: :delete
    end

    custom_indexes do
      index([:member_id])
      index([:gym_id])
      index([:member_id, :logged_on])
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

    read :list_by_member_and_date do
      argument :member_ids, {:array, :uuid}, allow_nil?: false
      argument :date, :date, allow_nil?: false
      filter expr(member_id in ^arg(:member_ids) and logged_on == ^arg(:date))
      prepare build(sort: [inserted_at: :asc])
    end

    read :list_by_member do
      argument :member_ids, {:array, :uuid}, allow_nil?: false
      filter expr(member_id in ^arg(:member_ids))
      prepare build(sort: [logged_on: :desc, inserted_at: :asc])
    end

    read :list_by_member_date_range do
      argument :member_ids, {:array, :uuid}, allow_nil?: false
      argument :start_date, :date, allow_nil?: false
      argument :end_date, :date, allow_nil?: false

      filter expr(
               member_id in ^arg(:member_ids) and
                 logged_on >= ^arg(:start_date) and
                 logged_on <= ^arg(:end_date)
             )

      prepare build(sort: [logged_on: :asc])
    end

    create :create do
      accept([:member_id, :gym_id, :logged_on, :meal_type, :food_name, :calories, :protein_g, :carbs_g, :fat_g])

      validate string_length(:food_name, min: 1, max: 255)
      validate numericality(:calories, greater_than: 0)
    end

    update :update do
      accept([:meal_type, :food_name, :calories, :protein_g, :carbs_g, :fat_g])

      validate string_length(:food_name, min: 1, max: 255)
      validate numericality(:calories, greater_than: 0)
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute :logged_on, :date do
      allow_nil?(false)
    end

    attribute :meal_type, :atom do
      allow_nil?(false)
      constraints(one_of: [:breakfast, :lunch, :dinner, :snack])
    end

    attribute :food_name, :string do
      allow_nil?(false)
      constraints(max_length: 255)
    end

    attribute :calories, :integer do
      allow_nil?(false)
    end

    attribute :protein_g, :decimal do
      allow_nil?(true)
    end

    attribute :carbs_g, :decimal do
      allow_nil?(true)
    end

    attribute :fat_g, :decimal do
      allow_nil?(true)
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
end
