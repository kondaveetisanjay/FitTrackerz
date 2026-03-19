defmodule FitTrackerz.Training.Meal do
  use Ash.Resource,
    data_layer: :embedded

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
  end

  attributes do
    attribute :name, :string do
      allow_nil?(false)
      public?(true)
      constraints(max_length: 255)
    end

    attribute :time_of_day, :string do
      allow_nil?(false)
      public?(true)
      constraints(max_length: 50)
    end

    attribute :items, {:array, :string} do
      default([])
      public?(true)
    end

    attribute :calories, :integer do
      public?(true)
      constraints(min: 0)
    end

    attribute :protein, :float do
      public?(true)
      constraints(min: 0)
    end

    attribute :carbs, :float do
      public?(true)
      constraints(min: 0)
    end

    attribute :fat, :float do
      public?(true)
      constraints(min: 0)
    end

    attribute :order, :integer do
      allow_nil?(false)
      public?(true)
      constraints(min: 0)
    end
  end
end
