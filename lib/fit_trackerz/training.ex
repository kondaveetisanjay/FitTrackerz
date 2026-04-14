defmodule FitTrackerz.Training do
  use Ash.Domain

  authorization do
    authorize :by_default
    require_actor? true
  end

  resources do
    resource FitTrackerz.Training.AttendanceRecord do
      define :list_attendance_by_member, args: [:member_ids], action: :list_by_member
      define :create_attendance, action: :create
    end

    resource FitTrackerz.Training.WorkoutPlanTemplate do
      define :list_workout_templates_by_gym, args: [:gym_id], action: :list_by_gym
      define :create_workout_template, action: :create
      define :update_workout_template, action: :update
      define :destroy_workout_template, action: :destroy
    end

    resource FitTrackerz.Training.WorkoutPlan do
      define :list_workouts_by_member, args: [:member_ids], action: :list_by_member
      define :create_workout, action: :create
      define :create_workout_from_template, action: :create_from_template
      define :update_workout, action: :update
      define :list_workouts_by_trainer, args: [:trainer_ids], action: :list_by_trainer
      define :destroy_workout, action: :destroy
    end

    resource FitTrackerz.Training.DietPlanTemplate do
      define :list_diet_templates_by_gym, args: [:gym_id], action: :list_by_gym
      define :create_diet_template, action: :create
      define :update_diet_template, action: :update
      define :destroy_diet_template, action: :destroy
    end

    resource FitTrackerz.Training.DietPlan do
      define :list_diets_by_member, args: [:member_ids], action: :list_by_member
      define :create_diet, action: :create
      define :create_diet_from_template, action: :create_from_template
      define :update_diet, action: :update
      define :list_diets_by_trainer, args: [:trainer_ids], action: :list_by_trainer
      define :destroy_diet, action: :destroy
    end

    resource FitTrackerz.Training.WorkoutLog do
      define :list_workout_logs, args: [:member_ids], action: :list_by_member
      define :list_workout_log_dates, args: [:member_ids], action: :list_dates_by_member
      define :create_workout_log, action: :create
      define :destroy_workout_log, action: :destroy
    end

    resource FitTrackerz.Training.WorkoutLogEntry do
      define :list_workout_log_entries, args: [:workout_log_id], action: :list_by_workout_log
      define :get_exercise_pr, args: [:member_id, :exercise_name], action: :list_by_member_exercise
      define :create_workout_log_entry, action: :create
    end

    resource FitTrackerz.Training.QrCheckIn do
      define :generate_qr_check_in, action: :generate
      define :get_qr_check_in_by_token, args: [:token], action: :get_by_token
      define :list_qr_check_ins_by_member, args: [:gym_member_id], action: :list_by_member
      define :redeem_qr_check_in, action: :redeem
    end
  end
end
