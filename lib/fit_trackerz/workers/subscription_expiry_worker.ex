defmodule FitTrackerz.Workers.SubscriptionExpiryWorker do
  @moduledoc """
  Oban worker that runs daily to:
  1. Auto-expire subscriptions past their end date
  2. Send notifications for subscriptions expiring in 7, 3, or 1 days
  3. Send notification on expiry day
  """
  use Oban.Worker, queue: :notifications, max_attempts: 3

  import Ecto.Query

  alias FitTrackerz.Repo
  alias FitTrackerz.Billing.MemberSubscription
  alias FitTrackerz.Notifications.Notification

  @notify_days_before [3, 1, 0]

  @impl Oban.Worker
  def perform(_job) do
    today = DateTime.utc_now()

    auto_expire_subscriptions(today)
    send_expiry_notifications(today)

    :ok
  end

  defp auto_expire_subscriptions(now) do
    from(s in MemberSubscription,
      where: s.status == :active and s.ends_at <= ^now
    )
    |> Repo.update_all(set: [status: :expired, updated_at: DateTime.utc_now()])
  end

  defp send_expiry_notifications(now) do
    today = DateTime.to_date(now)

    for days <- @notify_days_before do
      target_date = Date.add(today, days)

      # Find active subscriptions ending on this target date
      subscriptions =
        from(s in MemberSubscription,
          where: s.status == :active and fragment("?::date", s.ends_at) == ^target_date,
          join: m in assoc(s, :member),
          join: u in assoc(m, :user),
          join: g in assoc(s, :gym),
          join: p in assoc(s, :subscription_plan),
          select: %{
            subscription_id: s.id,
            user_id: u.id,
            gym_id: g.id,
            gym_name: g.name,
            plan_name: p.name,
            ends_at: s.ends_at,
            member_id: m.id
          }
        )
        |> Repo.all()

      for sub <- subscriptions do
        maybe_create_notification(sub, days)
      end
    end
  end

  defp maybe_create_notification(sub, days) do
    # Check if we already sent this notification today for this subscription
    today = Date.utc_today()

    existing =
      from(n in Notification,
        where:
          n.user_id == ^sub.user_id and
            fragment("(?->>'subscription_id')::text", n.metadata) == ^sub.subscription_id and
            fragment("?::date", n.inserted_at) == ^today
      )
      |> Repo.exists?()

    unless existing do
      {type, title, message} = notification_content(sub, days)

      # Create notification for the member
      Ash.create!(Notification,
        %{
          type: type,
          title: title,
          message: message,
          user_id: sub.user_id,
          gym_id: sub.gym_id,
          metadata: %{
            "subscription_id" => sub.subscription_id,
            "member_id" => sub.member_id,
            "days_remaining" => days
          }
        },
        authorize?: false
      )

      # Broadcast via PubSub for real-time
      Phoenix.PubSub.broadcast(
        FitTrackerz.PubSub,
        "notifications:#{sub.user_id}",
        {:new_notification, %{type: type, title: title, message: message}}
      )

      # Also notify gym operator
      Phoenix.PubSub.broadcast(
        FitTrackerz.PubSub,
        "gym_notifications:#{sub.gym_id}",
        {:member_subscription_expiring,
         %{
           member_id: sub.member_id,
           subscription_id: sub.subscription_id,
           days_remaining: days
         }}
      )
    end
  end

  defp notification_content(sub, 0) do
    {:subscription_expired,
     "Subscription Expired",
     "Your #{sub.plan_name} subscription at #{sub.gym_name} has expired today. Please renew to continue."}
  end

  defp notification_content(sub, days) do
    {:subscription_expiring,
     "Subscription Expiring Soon",
     "Your #{sub.plan_name} subscription at #{sub.gym_name} expires in #{days} day#{if days > 1, do: "s", else: ""}. Please renew to continue uninterrupted access."}
  end
end
