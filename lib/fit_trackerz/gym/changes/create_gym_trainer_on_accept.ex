defmodule FitTrackerz.Gym.Changes.CreateGymTrainerOnAccept do
  use Ash.Resource.Change

  require Ash.Query

  alias FitTrackerz.Accounts.SystemActor

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn _changeset, invitation ->
      actor = SystemActor.system_actor()

      user =
        FitTrackerz.Accounts.User
        |> Ash.Query.filter(email == ^invitation.invited_email)
        |> Ash.read_one(actor: actor)

      case user do
        {:ok, %{} = user} ->
          existing =
            case FitTrackerz.Gym.GymTrainer
                 |> Ash.Query.filter(user_id == ^user.id)
                 |> Ash.Query.filter(gym_id == ^invitation.gym_id)
                 |> Ash.read(actor: actor) do
              {:ok, trainers} -> List.first(trainers)
              {:error, _} -> nil
            end

          unless existing do
            FitTrackerz.Gym.GymTrainer
            |> Ash.Changeset.for_create(:create, %{
              user_id: user.id,
              gym_id: invitation.gym_id
            }, actor: actor)
            |> Ash.create(actor: actor)
          end

          if user.role == :member do
            user
            |> Ash.Changeset.for_update(:update, %{role: :trainer}, actor: actor)
            |> Ash.update(actor: actor)
          end

          {:ok, invitation}

        _ ->
          {:ok, invitation}
      end
    end)
  end
end
