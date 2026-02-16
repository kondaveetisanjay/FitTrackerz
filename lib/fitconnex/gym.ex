defmodule Fitconnex.Gym do
  use Ash.Domain

  authorization do
    authorize :by_default
    require_actor? true
  end

  resources do
    resource Fitconnex.Gym.Gym do
      define :list_gyms, action: :read
      define :get_gym, args: [:id], action: :get_by_id
      define :list_verified_gyms, action: :list_verified
      define :list_gyms_by_owner, args: [:owner_id], action: :list_by_owner
      define :list_pending_gyms, action: :list_pending_verification
      define :get_gym_by_slug, args: [:slug], action: :get_by_slug
      define :create_gym, action: :create
      define :update_gym, action: :update
      define :destroy_gym, action: :destroy
    end

    resource Fitconnex.Gym.GymBranch do
      define :list_branches_by_gym, args: [:gym_id], action: :list_by_gym
      define :create_branch, action: :create
      define :update_branch, action: :update
      define :destroy_branch, action: :destroy
    end

    resource Fitconnex.Gym.GymMember do
      define :get_gym_member, args: [:id], action: :get_by_id
      define :list_active_memberships, args: [:user_id], action: :list_active_by_user
      define :list_members_by_gym, args: [:gym_id], action: :list_by_gym
      define :list_members_by_trainer, args: [:trainer_ids], action: :list_by_assigned_trainer
      define :create_gym_member, action: :create
      define :update_gym_member, action: :update
      define :destroy_gym_member, action: :destroy
    end

    resource Fitconnex.Gym.GymTrainer do
      define :list_active_trainerships, args: [:user_id], action: :list_active_by_user
      define :list_trainers_by_gym, args: [:gym_id], action: :list_by_gym
      define :list_active_trainers_by_gym, args: [:gym_id], action: :list_active_by_gym
      define :create_gym_trainer, action: :create
      define :update_gym_trainer, action: :update
      define :destroy_gym_trainer, action: :destroy
    end

    resource Fitconnex.Gym.MemberInvitation do
      define :get_member_invitation, args: [:id], action: :get_by_id
      define :list_pending_member_invitations, args: [:email], action: :list_pending_by_email
      define :list_pending_member_invitations_by_gym, args: [:gym_id], action: :list_pending_by_gym
      define :create_member_invitation, action: :create
      define :accept_member_invitation, action: :accept
      define :reject_member_invitation, action: :reject
      define :expire_member_invitation, action: :expire
    end

    resource Fitconnex.Gym.TrainerInvitation do
      define :get_trainer_invitation, args: [:id], action: :get_by_id
      define :list_pending_trainer_invitations, args: [:email], action: :list_pending_by_email
      define :list_pending_trainer_invitations_by_gym, args: [:gym_id], action: :list_pending_by_gym
      define :create_trainer_invitation, action: :create
      define :accept_trainer_invitation, action: :accept
      define :reject_trainer_invitation, action: :reject
      define :expire_trainer_invitation, action: :expire
    end

    resource Fitconnex.Gym.ClientAssignmentRequest do
      define :get_assignment_request, args: [:id], action: :get_by_id
      define :list_pending_assignments_by_trainer, args: [:trainer_ids], action: :list_pending_by_trainer
      define :create_assignment_request, action: :create
      define :accept_assignment_request, action: :accept
      define :reject_assignment_request, action: :reject
    end
  end
end
