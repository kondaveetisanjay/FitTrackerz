defmodule FitconnexWeb.LoadOptions do
  @moduledoc """
  Standardized preload options for Ash resources.
  Used with domain function calls to ensure consistent data loading.
  """

  # Gym
  def gym_basic, do: [:branches, :owner]

  def gym_detailed do
    [:branches, :gym_members, :gym_trainers, :member_invitations, :trainer_invitations, :owner]
  end

  def gym_with_stats do
    [:branches, :gym_members, :gym_trainers]
  end

  # Gym Member
  def gym_member_basic, do: [:user, :branch, :assigned_trainer]
  def gym_member_with_trainer, do: [:user, assigned_trainer: [:user]]

  # Gym Trainer
  def gym_trainer_basic, do: [:user]
  def gym_trainer_with_gym, do: [:user, :gym]

  # Invitations
  def member_invitation_basic, do: [:gym, :invited_by, :branch]
  def trainer_invitation_basic, do: [:gym, :invited_by]

  # Assignment Requests
  def assignment_request_basic, do: [:gym, :requested_by, member: [:user]]

  # Scheduled Class
  def scheduled_class_basic, do: [:class_definition, :branch, :trainer]
  def scheduled_class_with_bookings, do: [:class_definition, :branch, :trainer, :bookings]

  # Booking
  def booking_with_class, do: [scheduled_class: [:class_definition, :trainer, :branch]]

  # Subscription
  def subscription_basic, do: [:subscription_plan, :gym]

  # Training
  def workout_with_trainer, do: [:gym, trainer: [:user]]
  def diet_with_trainer, do: [:gym, trainer: [:user]]

  # Attendance
  def attendance_basic, do: [:gym, :marked_by]
end
