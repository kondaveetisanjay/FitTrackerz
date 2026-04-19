defmodule FitTrackerz.Gym.Changes.NotifyTrainerOnAssignmentRequest do
  use Ash.Resource.Change

  require Ash.Query

  alias FitTrackerz.Accounts.SystemActor

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn _changeset, request ->
      system_actor = SystemActor.system_actor()

      with {:ok, trainer} <-
             FitTrackerz.Gym.GymTrainer
             |> Ash.Query.filter(id == ^request.trainer_id)
             |> Ash.read_one(actor: system_actor),
           true <- not is_nil(trainer),
           {:ok, member} <-
             FitTrackerz.Gym.GymMember
             |> Ash.Query.filter(id == ^request.member_id)
             |> Ash.Query.load(:user)
             |> Ash.read_one(actor: system_actor),
           true <- not is_nil(member),
           {:ok, gym} <-
             FitTrackerz.Gym.Gym
             |> Ash.Query.filter(id == ^request.gym_id)
             |> Ash.read_one(actor: system_actor),
           true <- not is_nil(gym) do
        member_name = if member.user, do: member.user.name, else: "a member"

        Ash.create(
          FitTrackerz.Notifications.Notification,
          %{
            type: :assignment_request,
            title: "New Client Assignment Request",
            message: "You've been requested to train #{member_name} at #{gym.name}.",
            user_id: trainer.user_id,
            gym_id: gym.id,
            metadata: %{
              "request_id" => request.id,
              "member_id" => request.member_id,
              "trainer_id" => request.trainer_id
            }
          },
          authorize?: false
        )

        Phoenix.PubSub.broadcast(
          FitTrackerz.PubSub,
          "notifications:#{trainer.user_id}",
          {:new_notification, %{type: :assignment_request, title: "New Client Assignment Request"}}
        )
      end

      {:ok, request}
    end)
  end
end
