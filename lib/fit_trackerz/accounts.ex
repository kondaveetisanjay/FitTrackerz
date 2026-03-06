defmodule FitTrackerz.Accounts do
  use Ash.Domain

  authorization do
    authorize :by_default
    require_actor? false
  end

  resources do
    resource FitTrackerz.Accounts.User do
      define :list_users, action: :read
      define :get_user, args: [:id], action: :get_by_id
      define :create_user, action: :create
      define :update_user, action: :update
      define :destroy_user, action: :destroy
    end

    resource(FitTrackerz.Accounts.Token)
  end
end
