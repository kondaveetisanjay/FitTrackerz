defmodule Fitconnex.Scheduling do
  use Ash.Domain

  authorization do
    authorize :by_default
    require_actor? false
  end

  resources do
    resource Fitconnex.Scheduling.ClassDefinition do
      define :list_class_definitions_by_gym, args: [:gym_id], action: :list_by_gym
      define :create_class_definition, action: :create
      define :update_class_definition, action: :update
      define :destroy_class_definition, action: :destroy
    end

    resource Fitconnex.Scheduling.ScheduledClass do
      define :list_scheduled_classes, action: :read
      define :list_classes_by_trainer, args: [:trainer_ids], action: :list_scheduled_by_trainer
      define :list_classes_by_branch, args: [:branch_ids], action: :list_scheduled_by_branch
      define :create_scheduled_class, action: :create
      define :update_scheduled_class, action: :update
      define :complete_scheduled_class, action: :complete
      define :cancel_scheduled_class, action: :cancel
    end

    resource Fitconnex.Scheduling.ClassBooking do
      define :list_bookings_by_member, args: [:member_ids], action: :list_by_member
      define :create_booking, action: :create
      define :confirm_booking, action: :confirm
      define :decline_booking, action: :decline
      define :cancel_booking, action: :cancel
    end
  end
end
