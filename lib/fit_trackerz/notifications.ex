defmodule FitTrackerz.Notifications do
  use Ash.Domain

  authorization do
    authorize :by_default
    require_actor? true
  end

  resources do
    resource FitTrackerz.Notifications.Notification do
      define :list_notifications, args: [:user_id], action: :list_by_user
      define :list_unread_notifications, args: [:user_id], action: :list_unread_by_user
      define :count_unread_notifications, args: [:user_id], action: :count_unread_by_user
      define :create_notification, action: :create
      define :mark_notification_read, action: :mark_read
      define :update_notification, action: :update
      define :destroy_notification, action: :destroy
    end
  end
end
