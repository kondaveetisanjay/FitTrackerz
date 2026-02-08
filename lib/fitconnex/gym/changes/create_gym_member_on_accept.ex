defmodule Fitconnex.Gym.Changes.CreateGymMemberOnAccept do
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn _changeset, invitation ->
      case Ash.get(Fitconnex.Accounts.User, email: invitation.invited_email) do
        {:ok, user} ->
          Fitconnex.Gym.GymMember
          |> Ash.Changeset.for_create(:create, %{
            user_id: user.id,
            gym_id: invitation.gym_id
          })
          |> Ash.create()

          {:ok, invitation}

        _ ->
          {:ok, invitation}
      end
    end)
  end
end
