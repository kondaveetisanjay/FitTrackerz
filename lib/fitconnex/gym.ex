defmodule Fitconnex.Gym do
  use Ash.Domain

  resources do
    resource(Fitconnex.Gym.Gym)
    resource(Fitconnex.Gym.GymBranch)
    resource(Fitconnex.Gym.GymMember)
    resource(Fitconnex.Gym.GymTrainer)
    resource(Fitconnex.Gym.MemberInvitation)
    resource(Fitconnex.Gym.TrainerInvitation)
    resource(Fitconnex.Gym.ClientAssignmentRequest)
  end
end
