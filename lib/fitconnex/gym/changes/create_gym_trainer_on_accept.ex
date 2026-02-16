defmodule Fitconnex.Gym.Changes.CreateGymTrainerOnAccept do
  use Ash.Resource.Change

  require Ash.Query

  alias Fitconnex.Accounts.SystemActor

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn _changeset, invitation ->
      case Ash.get(Fitconnex.Accounts.User, email: invitation.invited_email, actor: SystemActor.system_actor()) do
        {:ok, user} ->
          existing =
            case Fitconnex.Gym.GymTrainer
                 |> Ash.Query.filter(user_id == ^user.id)
                 |> Ash.Query.filter(gym_id == ^invitation.gym_id)
                 |> Ash.read(actor: SystemActor.system_actor()) do
              {:ok, trainers} -> List.first(trainers)
              {:error, _} -> nil
            end

          unless existing do
            Fitconnex.Gym.GymTrainer
            |> Ash.Changeset.for_create(:create, %{
              user_id: user.id,
              gym_id: invitation.gym_id
            })
            |> Ash.create(actor: SystemActor.system_actor())
          end

          # Upgrade user role to :trainer if currently :member
          # Never downgrade higher roles (gym_operator, platform_admin)
          if user.role == :member do
            user
            |> Ash.Changeset.for_update(:update, %{role: :trainer})
            |> Ash.update(actor: SystemActor.system_actor())
          end

          {:ok, invitation}

        _ ->
          {:ok, invitation}
      end
    end)
  end
end
