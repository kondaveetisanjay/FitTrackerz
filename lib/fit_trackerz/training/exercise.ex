defmodule FitTrackerz.Training.Exercise do
  use Ash.Resource,
    data_layer: :embedded

  attributes do
    attribute :name, :string do
      allow_nil?(false)
      constraints(max_length: 255)
    end

    attribute :sets, :integer do
      constraints(min: 1)
    end

    attribute :reps, :integer do
      constraints(min: 1)
    end

    attribute :duration_seconds, :integer do
      constraints(min: 0)
    end

    attribute :rest_seconds, :integer do
      constraints(min: 0)
    end

    attribute :order, :integer do
      allow_nil?(false)
      constraints(min: 0)
    end
  end
end
