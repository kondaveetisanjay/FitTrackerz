defmodule Fitconnex.Training.DietPlan do
  use Ash.Resource,
    domain: Fitconnex.Training,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("diet_plans")
    repo(Fitconnex.Repo)
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      accept([
        :name,
        :meals,
        :calorie_target,
        :dietary_type,
        :member_id,
        :gym_id,
        :trainer_id,
        :template_id
      ])
    end

    create :create_from_template do
      accept([:member_id, :gym_id, :trainer_id, :template_id])

      change(Fitconnex.Training.Changes.CopyFromDietTemplate)
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
    belongs_to :member, Fitconnex.Gym.GymMember do
      allow_nil?(false)
    end

    belongs_to :gym, Fitconnex.Gym.Gym do
      allow_nil?(false)
    end

    belongs_to :trainer, Fitconnex.Gym.GymTrainer

    belongs_to :template, Fitconnex.Training.DietPlanTemplate
  end
end
