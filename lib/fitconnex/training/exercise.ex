defmodule Fitconnex.Training.Exercise do
  use Ash.Resource,
    data_layer: :embedded

  attributes do
    attribute :name, :string do
      allow_nil?(false)
    end

    attribute(:sets, :integer)
    attribute(:reps, :integer)
    attribute(:duration_seconds, :integer)
    attribute(:rest_seconds, :integer)

    attribute :order, :integer do
      allow_nil?(false)
    end
  end
end
