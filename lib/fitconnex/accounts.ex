defmodule Fitconnex.Accounts do
  use Ash.Domain

  resources do
    resource(Fitconnex.Accounts.User)
    resource(Fitconnex.Accounts.Token)
  end
end
