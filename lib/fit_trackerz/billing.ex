defmodule FitTrackerz.Billing do
  use Ash.Domain

  authorization do
    authorize :by_default
    require_actor? true
  end

  resources do
    resource FitTrackerz.Billing.SubscriptionPlan do
      define :list_plans_by_gym, args: [:gym_id], action: :list_by_gym
      define :create_plan, action: :create
      define :update_plan, action: :update
      define :destroy_plan, action: :destroy
    end

    resource FitTrackerz.Billing.MemberSubscription do
      define :list_subscriptions, action: :read
      define :list_active_subscriptions_by_member, args: [:member_ids], action: :list_active_by_member
      define :list_subscriptions_by_gym, args: [:gym_id], action: :list_by_gym
      define :create_subscription, action: :create
      define :update_subscription, action: :update
      define :cancel_subscription, action: :cancel
    end
  end
end
