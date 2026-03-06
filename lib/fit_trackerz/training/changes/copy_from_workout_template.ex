defmodule FitTrackerz.Training.Changes.CopyFromWorkoutTemplate do
  use Ash.Resource.Change

  alias FitTrackerz.Accounts.SystemActor

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.before_action(changeset, fn changeset ->
      case Ash.Changeset.get_attribute(changeset, :template_id) do
        nil ->
          changeset

        template_id ->
          case Ash.get(FitTrackerz.Training.WorkoutPlanTemplate, template_id, actor: SystemActor.system_actor()) do
            {:ok, template} ->
              changeset
              |> Ash.Changeset.change_attribute(:name, template.name)
              |> Ash.Changeset.change_attribute(:exercises, template.exercises)

            _ ->
              changeset
          end
      end
    end)
  end
end
