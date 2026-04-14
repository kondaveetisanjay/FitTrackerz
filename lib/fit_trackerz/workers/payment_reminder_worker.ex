defmodule FitTrackerz.Workers.PaymentReminderWorker do
  @moduledoc """
  Daily Oban worker (runs at 09:00 UTC) that:
  Finds MemberSubscriptions with payment_status == :pending for 3+ days
  and sends payment due notifications to both the member and gym operator.
  """
  use Oban.Worker, queue: :notifications, max_attempts: 3

  import Ecto.Query

  alias FitTrackerz.Repo
  alias FitTrackerz.Notifications.Notification

  require Logger

  @impl Oban.Worker
  def perform(_job) do
    cutoff = DateTime.add(DateTime.utc_now(), -(3 * 24 * 60 * 60), :second)

    pending_subscriptions =
      from(s in FitTrackerz.Billing.MemberSubscription,
        join: m in FitTrackerz.Gym.GymMember,
        on: m.id == s.member_id,
        join: u in FitTrackerz.Accounts.User,
        on: u.id == m.user_id,
        join: g in FitTrackerz.Gym.Gym,
        on: g.id == s.gym_id,
        join: o in FitTrackerz.Accounts.User,
        on: o.id == g.owner_id,
        join: p in FitTrackerz.Billing.SubscriptionPlan,
        on: p.id == s.subscription_plan_id,
        where: s.payment_status == :pending and s.inserted_at <= ^cutoff and s.status == :active,
        select: %{
          subscription_id: s.id,
          member_user_id: u.id,
          operator_user_id: o.id,
          gym_id: g.id,
          gym_name: g.name,
          plan_name: p.name,
          member_name: u.name
        }
      )
      |> Repo.all()

    for sub <- pending_subscriptions do
      send_payment_reminders(sub)
    end

    reminder_count = length(pending_subscriptions)

    if reminder_count > 0 do
      Logger.info("PaymentReminderWorker: sent #{reminder_count} payment reminders")
    end

    :ok
  end

  defp send_payment_reminders(sub) do
    today = Date.utc_today()

    already_sent =
      from(n in Notification,
        where:
          n.user_id == ^sub.member_user_id and
            n.type == :payment_due and
            fragment("(?->>'subscription_id')::text", n.metadata) == ^sub.subscription_id and
            fragment("?::date", n.inserted_at) == ^today
      )
      |> Repo.exists?()

    unless already_sent do
      Ash.create!(
        Notification,
        %{
          type: :payment_due,
          title: "Payment Required",
          message:
            "Your #{sub.plan_name} subscription at #{sub.gym_name} has a pending payment. Please contact your gym to settle it.",
          user_id: sub.member_user_id,
          gym_id: sub.gym_id,
          metadata: %{"subscription_id" => sub.subscription_id}
        },
        authorize?: false
      )

      Ash.create!(
        Notification,
        %{
          type: :payment_due,
          title: "Member Payment Pending",
          message:
            "#{sub.member_name}'s #{sub.plan_name} subscription has a pending payment that is 3+ days overdue.",
          user_id: sub.operator_user_id,
          gym_id: sub.gym_id,
          metadata: %{
            "subscription_id" => sub.subscription_id,
            "member_user_id" => sub.member_user_id
          }
        },
        authorize?: false
      )

      Phoenix.PubSub.broadcast(
        FitTrackerz.PubSub,
        "notifications:#{sub.member_user_id}",
        {:new_notification, %{type: :payment_due, title: "Payment Required"}}
      )

      Phoenix.PubSub.broadcast(
        FitTrackerz.PubSub,
        "gym_notifications:#{sub.gym_id}",
        {:payment_reminder, %{subscription_id: sub.subscription_id}}
      )
    end
  end
end
