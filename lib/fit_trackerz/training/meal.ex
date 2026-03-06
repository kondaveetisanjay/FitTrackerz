defmodule FitTrackerz.Training.Meal do
  use Ash.Resource,
    data_layer: :embedded

  attributes do
    attribute :name, :string do
      allow_nil?(false)
      constraints(max_length: 255)
    end

    attribute :time_of_day, :string do
      allow_nil?(false)
      constraints(max_length: 50)
    end

    attribute :items, {:array, :string} do
      default([])
    end

    attribute :calories, :integer do
      constraints(min: 0)
    end

    attribute :protein, :float do
      constraints(min: 0)
    end

    attribute :carbs, :float do
      constraints(min: 0)
    end

    attribute :fat, :float do
      constraints(min: 0)
    end

    attribute :order, :integer do
      allow_nil?(false)
      constraints(min: 0)
    end
  end
end
