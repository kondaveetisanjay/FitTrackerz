defmodule FitTrackerz.Gym.Changes.AssignTrainerOnAccept do
  use Ash.Resource.Change

  require Ash.Query

  alias FitTrackerz.Accounts.SystemActor

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn _changeset, request ->
      actor = SystemActor.system_actor()

      case Ash.get(FitTrackerz.Gym.GymMember, request.member_id, actor: actor) do
        {:ok, member} ->
          case member
               |> Ash.Changeset.for_update(:update, %{assigned_trainer_id: request.trainer_id}, actor: actor)
               |> Ash.update(actor: actor) do
            {:ok, _updated_member} ->
              {:ok, request}

            {:error, error} ->
              {:error, error}
          end

        {:error, error} ->
          {:error, error}
      end
    end)
  end
end
