defmodule FitTrackerz.Health do
  use Ash.Domain

  authorization do
    authorize :by_default
    require_actor? true
  end

  resources do
    resource FitTrackerz.Health.HealthMetric do
      define :list_health_metrics, args: [:member_ids], action: :list_by_member
      define :get_latest_health_metric, args: [:member_ids], action: :latest_by_member
      define :create_health_metric, action: :create
      define :update_health_metric, action: :update
      define :destroy_health_metric, action: :destroy
    end

    resource FitTrackerz.Health.FoodLog do
      define :list_food_logs_by_date, args: [:member_ids, :date], action: :list_by_member_and_date
      define :list_food_logs, args: [:member_ids], action: :list_by_member
      define :list_food_logs_by_range, args: [:member_ids, :start_date, :end_date], action: :list_by_member_date_range
      define :create_food_log, action: :create
      define :update_food_log, action: :update
      define :destroy_food_log, action: :destroy
    end
  end
end
