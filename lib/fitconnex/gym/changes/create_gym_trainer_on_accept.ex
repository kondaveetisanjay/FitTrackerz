defmodule Fitconnex.Gym.Changes.CreateGymTrainerOnAccept do
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn _changeset, invitation ->
      case Ash.get(Fitconnex.Accounts.User, email: invitation.invited_email) do
        {:ok, user} ->
          Fitconnex.Gym.GymTrainer
          |> Ash.Changeset.for_create(:create, %{
            user_id: user.id,
            gym_id: invitation.gym_id
          })
          |> Ash.create()

          # Upgrade user role to :trainer if currently :member
          # Never downgrade higher roles (gym_operator, platform_admin)
          if user.role == :member do
            user
            |> Ash.Changeset.for_update(:update, %{role: :trainer})
            |> Ash.update()
          end

          {:ok, invitation}

        _ ->
          {:ok, invitation}
      end
    end)
  end
end
