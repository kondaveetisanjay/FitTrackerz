defmodule FitTrackerz.Training.Exercise do
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

    attribute :sets, :integer do
      public?(true)
      constraints(min: 1)
    end

    attribute :reps, :integer do
      public?(true)
      constraints(min: 1)
    end

    attribute :duration_seconds, :integer do
      public?(true)
      constraints(min: 0)
    end

    attribute :rest_seconds, :integer do
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
