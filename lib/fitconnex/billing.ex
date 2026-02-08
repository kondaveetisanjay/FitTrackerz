defmodule Fitconnex.Billing do
  use Ash.Domain

  resources do
    resource(Fitconnex.Billing.SubscriptionPlan)
    resource(Fitconnex.Billing.MemberSubscription)
  end
end
