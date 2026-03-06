defmodule FitTrackerzWeb.LoadOptions do
  @moduledoc """
  Standardized preload options for Ash resources.
  Used with domain function calls to ensure consistent data loading.
  """

  # Gym
  def gym_basic, do: [:branches, :owner]

  def gym_detailed do
    [:branches, :gym_members, :member_invitations, :owner]
  end

  def gym_with_stats do
    [:branches, :gym_members]
  end

  # Gym Member
  def gym_member_basic, do: [:user, :branch]

  # Invitations
  def member_invitation_basic, do: [:gym, :invited_by, :branch]

  # Scheduled Class
  def scheduled_class_basic, do: [:class_definition, :branch]
  def scheduled_class_with_bookings, do: [:class_definition, :branch, :bookings]

  # Booking
  def booking_with_class, do: [scheduled_class: [:class_definition, :branch]]

  # Subscription
  def subscription_basic, do: [:subscription_plan, :gym]

  # Training
  def workout_basic, do: [:gym]
  def diet_basic, do: [:gym]

  # Attendance
  def attendance_basic, do: [:gym, :marked_by]
end
