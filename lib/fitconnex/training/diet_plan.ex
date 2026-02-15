defmodule Fitconnex.Training.DietPlan do
  use Ash.Resource,
    domain: Fitconnex.Training,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("diet_plans")
    repo(Fitconnex.Repo)

    references do
      reference :member, on_delete: :delete
      reference :gym, on_delete: :delete
      reference :trainer, on_delete: :nilify
      reference :template, on_delete: :nilify
    end

    custom_indexes do
      index([:member_id])
      index([:trainer_id])
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
      authorize_if actor_attribute_equals(:role, :trainer)
    end
  end

  actions do
    defaults([:read, :destroy])

    read :list_by_member do
      argument :member_ids, {:array, :uuid}, allow_nil?: false
      filter expr(member_id in ^arg(:member_ids))
      prepare build(load: [:gym, trainer: [:user]])
    end

    read :list_by_trainer do
      argument :trainer_ids, {:array, :uuid}, allow_nil?: false
      filter expr(trainer_id in ^arg(:trainer_ids))
    end

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

      validate string_length(:name, min: 1, max: 255)
      validate numericality(:calorie_target, greater_than: 0)
    end

    create :create_from_template do
      accept([:member_id, :gym_id, :trainer_id, :template_id])

      change(Fitconnex.Training.Changes.CopyFromDietTemplate)
    end

    update :update do
      accept([:name, :meals, :calorie_target, :dietary_type])

      validate string_length(:name, min: 1, max: 255)
      validate numericality(:calorie_target, greater_than: 0)
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute :name, :string do
      allow_nil?(false)
      constraints(max_length: 255)
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
