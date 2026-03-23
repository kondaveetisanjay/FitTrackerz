defmodule FitTrackerz.Messaging do
  use Ash.Domain

  authorization do
    authorize :by_default
    require_actor? true
  end

  resources do
    resource FitTrackerz.Messaging.Conversation do
      define :get_conversation, args: [:id], action: :get_by_id
      define :list_conversations, args: [:user_id], action: :list_by_participant
      define :list_direct_conversations, args: [:user_id], action: :list_direct_by_participant
      define :list_announcements, args: [:user_id], action: :list_announcements_by_participant
      define :find_direct_conversation, args: [:user_id_1, :user_id_2, :gym_id], action: :find_direct_between
      define :create_conversation, action: :create
      define :update_conversation, action: :update
      define :touch_conversation, action: :touch
      define :destroy_conversation, action: :destroy
    end

    resource FitTrackerz.Messaging.ConversationParticipant do
      define :list_participants, args: [:conversation_id], action: :list_by_conversation
      define :list_user_participations, args: [:user_id], action: :list_by_user
      define :create_participant, action: :create
      define :mark_participant_read, action: :mark_read
      define :destroy_participant, action: :destroy
    end

    resource FitTrackerz.Messaging.Message do
      define :list_messages, args: [:conversation_id], action: :list_by_conversation
      define :get_latest_message, args: [:conversation_id], action: :latest_by_conversation
      define :create_message, action: :create
      define :destroy_message, action: :destroy
    end
  end
end
