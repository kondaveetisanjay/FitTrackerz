defmodule FitTrackerz.Scheduling.Validations.ValidateActiveSubscription do
  use Ash.Resource.Validation
  require Ash.Query

  alias FitTrackerz.Accounts.SystemActor

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def validate(changeset, _opts, _context) do
    member_id = Ash.Changeset.get_attribute(changeset, :member_id)
    scheduled_class_id = Ash.Changeset.get_attribute(changeset, :scheduled_class_id)

    if is_nil(member_id) or is_nil(scheduled_class_id) do
      :ok
    else
      with {:ok, scheduled_class} <-
             Ash.get(FitTrackerz.Scheduling.ScheduledClass, scheduled_class_id, actor: SystemActor.system_actor()),
           {:ok, class_definition} <-
             Ash.get(FitTrackerz.Scheduling.ClassDefinition, scheduled_class.class_definition_id, actor: SystemActor.system_actor()) do
        gym_id = class_definition.gym_id

        active_subs =
          FitTrackerz.Billing.MemberSubscription
          |> Ash.Query.filter(member_id == ^member_id)
          |> Ash.Query.filter(gym_id == ^gym_id)
          |> Ash.Query.filter(status == :active)
          |> Ash.Query.filter(payment_status == :paid)
          |> Ash.read!(actor: SystemActor.system_actor())

        if active_subs != [] do
          :ok
        else
          {:error,
           field: :member_id,
           message: "Member does not have an active paid subscription at this gym."}
        end
      else
        {:error, _} ->
          {:error, field: :scheduled_class_id, message: "Could not verify subscription status."}
      end
    end
  end
end
