defmodule FitTrackerz.Gamification do
  use Ash.Domain

  authorization do
    authorize :by_default
    require_actor? true
  end

  resources do
    resource FitTrackerz.Gamification.Streak do
      define :list_streaks_by_member, args: [:gym_member_id], action: :list_by_member
      define :get_streak, args: [:gym_member_id, :streak_type], action: :get_by_member_and_type
      define :create_streak, action: :create
      define :update_streak, action: :update
    end

    resource FitTrackerz.Gamification.StreakMilestone do
      define :list_milestones_by_member, args: [:gym_member_id], action: :list_by_member
      define :create_milestone, action: :create
    end
  end
end
