defmodule Fitconnex.Training.Changes.CopyFromDietTemplate do
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.before_action(changeset, fn changeset ->
      case Ash.Changeset.get_attribute(changeset, :template_id) do
        nil ->
          changeset

        template_id ->
          case Ash.get(Fitconnex.Training.DietPlanTemplate, template_id) do
            {:ok, template} ->
              changeset
              |> Ash.Changeset.change_attribute(:name, template.name)
              |> Ash.Changeset.change_attribute(:meals, template.meals)
              |> Ash.Changeset.change_attribute(:calorie_target, template.calorie_target)
              |> Ash.Changeset.change_attribute(:dietary_type, template.dietary_type)

            _ ->
              changeset
          end
      end
    end)
  end
end
