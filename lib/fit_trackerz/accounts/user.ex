defmodule FitTrackerz.Accounts.User do
  use Ash.Resource,
    domain: FitTrackerz.Accounts,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAuthentication],
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("users")
    repo(FitTrackerz.Repo)
  end

  authentication do
    session_identifier(:jti)

    tokens do
      enabled?(true)
      token_resource(FitTrackerz.Accounts.Token)
      require_token_presence_for_authentication?(false)

      signing_secret(fn _, _ ->
        Application.fetch_env(:fit_trackerz, :token_signing_secret)
      end)
    end

    strategies do
      password :password do
        identity_field(:email)
        hash_provider(AshAuthentication.BcryptProvider)
        confirmation_required?(true)

        register_action_accept([:name])
      end
    end
  end

  policies do
    bypass actor_attribute_equals(:is_system_actor, true) do
      authorize_if always()
    end

    bypass actor_attribute_equals(:role, :platform_admin) do
      authorize_if always()
    end

    # Allow authentication actions (register/sign-in) without an actor
    bypass action(:register_with_password) do
      authorize_if always()
    end

    bypass action(:sign_in_with_password) do
      authorize_if always()
    end

    policy action_type(:read) do
      authorize_if always()
    end

    policy action_type(:update) do
      authorize_if expr(id == ^actor(:id))
    end
  end

  actions do
    defaults([:read, :destroy])

    read :get_by_id do
      get? true
      argument :id, :uuid, allow_nil?: false
      filter expr(id == ^arg(:id))
    end

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
      constraints(min_length: 1, max_length: 255)
    end

    attribute :phone, :string do
      public?(true)
      constraints(max_length: 20)
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
