defmodule Fitconnex.Scheduling do
  use Ash.Domain

  resources do
    resource(Fitconnex.Scheduling.ClassDefinition)
    resource(Fitconnex.Scheduling.ScheduledClass)
    resource(Fitconnex.Scheduling.ClassBooking)
  end
end
