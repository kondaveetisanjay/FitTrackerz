defmodule FitTrackerz.Gym.Changes.CreateGymMemberOnAccept do
  use Ash.Resource.Change

  require Ash.Query

  alias FitTrackerz.Accounts.SystemActor

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn _changeset, invitation ->
      case Ash.get(FitTrackerz.Accounts.User, email: invitation.invited_email, actor: SystemActor.system_actor()) do
        {:ok, user} ->
          existing =
            case FitTrackerz.Gym.GymMember
                 |> Ash.Query.filter(user_id == ^user.id)
                 |> Ash.Query.filter(gym_id == ^invitation.gym_id)
                 |> Ash.read(actor: SystemActor.system_actor()) do
              {:ok, members} -> List.first(members)
              {:error, _} -> nil
            end

          system_actor = SystemActor.system_actor()

          if existing do
            # Membership already exists — update branch if provided
            if invitation.branch_id do
              existing
              |> Ash.Changeset.for_update(:update, %{branch_id: invitation.branch_id}, actor: system_actor)
              |> Ash.update(actor: system_actor)
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

            FitTrackerz.Gym.GymMember
            |> Ash.Changeset.for_create(:create, params, actor: system_actor)
            |> Ash.create(actor: system_actor)
          end

          {:ok, invitation}

        _ ->
          {:ok, invitation}
      end
    end)
  end
end
