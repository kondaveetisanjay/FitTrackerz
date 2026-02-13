defmodule Fitconnex.Scheduling.Validations.ValidateActiveSubscription do
  use Ash.Resource.Validation
  require Ash.Query

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def validate(changeset, _opts, _context) do
    member_id = Ash.Changeset.get_attribute(changeset, :member_id)
    scheduled_class_id = Ash.Changeset.get_attribute(changeset, :scheduled_class_id)

    with true <- not is_nil(member_id) and not is_nil(scheduled_class_id),
         {:ok, scheduled_class} <-
           Ash.get(Fitconnex.Scheduling.ScheduledClass, scheduled_class_id),
         {:ok, class_definition} <-
           Ash.get(Fitconnex.Scheduling.ClassDefinition, scheduled_class.class_definition_id) do
      gym_id = class_definition.gym_id

      active_subs =
        Fitconnex.Billing.MemberSubscription
        |> Ash.Query.filter(member_id == ^member_id)
        |> Ash.Query.filter(gym_id == ^gym_id)
        |> Ash.Query.filter(status == :active)
        |> Ash.Query.filter(payment_status == :paid)
        |> Ash.read!()

      if active_subs != [] do
        :ok
      else
        {:error,
         field: :member_id,
         message: "Member does not have an active paid subscription at this gym."}
      end
    else
      # If fields are missing or lookups fail, let other validations handle it
      _ -> :ok
    end
  end
end
