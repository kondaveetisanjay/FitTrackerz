defmodule Fitconnex.Training.Meal do
  use Ash.Resource,
    data_layer: :embedded

  attributes do
    attribute :name, :string do
      allow_nil?(false)
    end

    attribute :time_of_day, :string do
      allow_nil?(false)
    end

    attribute :items, {:array, :string} do
      default([])
    end

    attribute(:calories, :integer)
    attribute(:protein, :float)
    attribute(:carbs, :float)
    attribute(:fat, :float)

    attribute :order, :integer do
      allow_nil?(false)
    end
  end
end
