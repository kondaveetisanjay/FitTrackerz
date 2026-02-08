defmodule Fitconnex.Training do
  use Ash.Domain

  resources do
    resource(Fitconnex.Training.AttendanceRecord)
    resource(Fitconnex.Training.WorkoutPlanTemplate)
    resource(Fitconnex.Training.WorkoutPlan)
    resource(Fitconnex.Training.DietPlanTemplate)
    resource(Fitconnex.Training.DietPlan)
  end
end
