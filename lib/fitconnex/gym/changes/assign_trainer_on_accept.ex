defmodule Fitconnex.Gym.Changes.AssignTrainerOnAccept do
  use Ash.Resource.Change

  require Ash.Query

  alias Fitconnex.Accounts.SystemActor

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn _changeset, request ->
      case Ash.get(Fitconnex.Gym.GymMember, request.member_id, actor: SystemActor.system_actor()) do
        {:ok, member} ->
          case member
               |> Ash.Changeset.for_update(:update, %{assigned_trainer_id: request.trainer_id})
               |> Ash.update(actor: SystemActor.system_actor()) do
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
