defmodule Fitconnex.Training do
  use Ash.Domain

  authorization do
    authorize :by_default
    require_actor? false
  end

  resources do
    resource Fitconnex.Training.AttendanceRecord do
      define :list_attendance_by_member, args: [:member_ids], action: :list_by_member
      define :create_attendance, action: :create
    end

    resource Fitconnex.Training.WorkoutPlanTemplate do
      define :list_workout_templates_by_gym, args: [:gym_id], action: :list_by_gym
      define :create_workout_template, action: :create
      define :update_workout_template, action: :update
      define :destroy_workout_template, action: :destroy
    end

    resource Fitconnex.Training.WorkoutPlan do
      define :list_workouts_by_member, args: [:member_ids], action: :list_by_member
      define :list_workouts_by_trainer, args: [:trainer_ids], action: :list_by_trainer
      define :create_workout, action: :create
      define :create_workout_from_template, action: :create_from_template
      define :update_workout, action: :update
      define :destroy_workout, action: :destroy
    end

    resource Fitconnex.Training.DietPlanTemplate do
      define :list_diet_templates_by_gym, args: [:gym_id], action: :list_by_gym
      define :create_diet_template, action: :create
      define :update_diet_template, action: :update
      define :destroy_diet_template, action: :destroy
    end

    resource Fitconnex.Training.DietPlan do
      define :list_diets_by_member, args: [:member_ids], action: :list_by_member
      define :list_diets_by_trainer, args: [:trainer_ids], action: :list_by_trainer
      define :create_diet, action: :create
      define :create_diet_from_template, action: :create_from_template
      define :update_diet, action: :update
      define :destroy_diet, action: :destroy
    end
  end
end
