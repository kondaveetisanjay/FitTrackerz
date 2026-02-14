defmodule Fitconnex.Gym.Changes.AssignTrainerOnAccept do
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn _changeset, request ->
      member = Ash.get!(Fitconnex.Gym.GymMember, request.member_id)

      member
      |> Ash.Changeset.for_update(:update, %{assigned_trainer_id: request.trainer_id})
      |> Ash.update()

      {:ok, request}
    end)
  end
end
