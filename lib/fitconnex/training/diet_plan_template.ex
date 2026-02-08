defmodule Fitconnex.Training.DietPlanTemplate do
  use Ash.Resource,
    domain: Fitconnex.Training,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("diet_plan_templates")
    repo(Fitconnex.Repo)
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      accept([:name, :meals, :calorie_target, :dietary_type, :gym_id, :created_by_id])
    end

    update :update do
      accept([:name, :meals, :calorie_target, :dietary_type])
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute :name, :string do
      allow_nil?(false)
    end

    attribute :meals, {:array, Fitconnex.Training.Meal} do
      default([])
    end

    attribute(:calorie_target, :integer)

    attribute :dietary_type, :atom do
      constraints(one_of: [:vegetarian, :non_vegetarian, :vegan, :eggetarian])
    end

    timestamps()
  end

  relationships do
    belongs_to :gym, Fitconnex.Gym.Gym do
      allow_nil?(false)
    end

    belongs_to :created_by, Fitconnex.Accounts.User do
      allow_nil?(false)
    end
  end
end
