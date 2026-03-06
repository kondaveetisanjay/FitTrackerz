defmodule FitTrackerz.Accounts.Token do
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAuthentication.TokenResource],
    domain: FitTrackerz.Accounts

  postgres do
    table("tokens")
    repo(FitTrackerz.Repo)
  end

  actions do
    defaults([:read, :destroy])
  end
end
