defmodule Fitconnex.Accounts.User do
  use Ash.Resource,
    domain: Fitconnex.Accounts,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAuthentication]

  postgres do
    table("users")
    repo(Fitconnex.Repo)
  end

  authentication do
    session_identifier(:jti)

    tokens do
      enabled?(true)
      token_resource(Fitconnex.Accounts.Token)
      require_token_presence_for_authentication?(false)

      signing_secret(fn _, _ ->
        Application.fetch_env(:fitconnex, :token_signing_secret)
      end)
    end

    strategies do
      password :password do
        identity_field(:email)
        hash_provider(AshAuthentication.BcryptProvider)
        confirmation_required?(false)

        register_action_accept([:name])
      end
    end
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      accept([:email, :name, :phone, :role])
    end

    update :update do
      accept([:name, :phone, :role, :is_active])
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute :email, :ci_string do
      allow_nil?(false)
      public?(true)
    end

    attribute :name, :string do
      allow_nil?(false)
      default("User")
      public?(true)
    end

    attribute :phone, :string do
      public?(true)
    end

    attribute :role, :atom do
      constraints(one_of: [:platform_admin, :gym_operator, :trainer, :member])
      allow_nil?(false)
      default(:member)
      public?(true)
    end

    attribute :is_active, :boolean do
      allow_nil?(false)
      default(true)
      public?(true)
    end

    attribute :hashed_password, :string do
      allow_nil?(true)
      sensitive?(true)
    end

    timestamps()
  end

  identities do
    identity(:unique_email, [:email])
  end
end
