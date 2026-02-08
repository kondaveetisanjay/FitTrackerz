defmodule Fitconnex.Accounts.Token do
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAuthentication.TokenResource],
    domain: Fitconnex.Accounts

  postgres do
    table("tokens")
    repo(Fitconnex.Repo)
  end

  actions do
    defaults([:read, :destroy])
  end
end
