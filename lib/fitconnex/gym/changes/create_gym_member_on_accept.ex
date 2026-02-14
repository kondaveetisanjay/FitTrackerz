defmodule Fitconnex.Gym.Changes.CreateGymMemberOnAccept do
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn _changeset, invitation ->
      case Ash.get(Fitconnex.Accounts.User, email: invitation.invited_email) do
        {:ok, user} ->
          require Ash.Query

          existing =
            Fitconnex.Gym.GymMember
            |> Ash.Query.filter(user_id == ^user.id)
            |> Ash.Query.filter(gym_id == ^invitation.gym_id)
            |> Ash.read!()
            |> List.first()

          if existing do
            # Membership already exists — update branch if provided
            if invitation.branch_id do
              existing
              |> Ash.Changeset.for_update(:update, %{branch_id: invitation.branch_id})
              |> Ash.update()
            end
          else
            params = %{
              user_id: user.id,
              gym_id: invitation.gym_id
            }

            params =
              if invitation.branch_id,
                do: Map.put(params, :branch_id, invitation.branch_id),
                else: params

            Fitconnex.Gym.GymMember
            |> Ash.Changeset.for_create(:create, params)
            |> Ash.create()
          end

          {:ok, invitation}

        _ ->
          {:ok, invitation}
      end
    end)
  end
end
