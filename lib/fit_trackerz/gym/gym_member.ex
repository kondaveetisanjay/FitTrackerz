defmodule FitTrackerz.Gym.GymMember do
  use Ash.Resource,
    domain: FitTrackerz.Gym,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  import Ecto.Query, only: [from: 2]

  postgres do
    table("gym_members")
    repo(FitTrackerz.Repo)

    references do
      reference :gym, on_delete: :delete
      reference :user, on_delete: :delete
      reference :branch, on_delete: :nilify
    end

    custom_indexes do
      index([:user_id])
      index([:gym_id])
      index([:branch_id])
    end
  end

  policies do
    bypass actor_attribute_equals(:is_system_actor, true) do
      authorize_if always()
    end

    bypass actor_attribute_equals(:role, :platform_admin) do
      authorize_if always()
    end

    policy action_type(:read) do
      authorize_if always()
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if actor_attribute_equals(:role, :gym_operator)
    end
  end

  actions do
    defaults([:read, :destroy])

    read :get_by_id do
      get? true
      argument :id, :uuid, allow_nil?: false
      filter expr(id == ^arg(:id))
    end

    read :list_active_by_user do
      argument :user_id, :uuid, allow_nil?: false
      filter expr(user_id == ^arg(:user_id) and is_active == true)
      prepare build(load: [:gym, :branch])
    end

    read :list_by_gym do
      argument :gym_id, :uuid, allow_nil?: false
      filter expr(gym_id == ^arg(:gym_id))
      prepare build(load: [:user])
    end

    read :list_by_assigned_trainer do
      argument :trainer_ids, {:array, :uuid}, allow_nil?: false
      filter expr(assigned_trainer_id in ^arg(:trainer_ids) and is_active == true)
      prepare build(load: [:user, :gym])
    end

    create :create do
      accept([:user_id, :gym_id, :branch_id, :joined_at])

      validate fn changeset, _context ->
        gym_id = Ash.Changeset.get_attribute(changeset, :gym_id)

        if gym_id do
          gym_tier =
            from(g in FitTrackerz.Gym.Gym, where: g.id == ^gym_id, select: g.tier)
            |> FitTrackerz.Repo.one()

          cond do
            is_nil(gym_tier) ->
              :ok

            gym_tier == :free ->
              count =
                from(m in FitTrackerz.Gym.GymMember,
                  where: m.gym_id == ^gym_id and m.is_active == true,
                  select: count(m.id)
                )
                |> FitTrackerz.Repo.one()

              if count >= 50 do
                {:error,
                 field: :gym_id,
                 message:
                   "This gym has reached its 50-member limit for the free tier. Upgrade to Premium to add more members."}
              else
                :ok
              end

            true ->
              :ok
          end
        else
          :ok
        end
      end
    end

    update :update do
      accept([:is_active, :branch_id, :assigned_trainer_id, :joined_at])
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute :is_active, :boolean do
      allow_nil?(false)
      default(true)
    end

    attribute :joined_at, :date do
      allow_nil?(true)
      default(&Date.utc_today/0)
    end

    timestamps()
  end

  relationships do
    belongs_to :user, FitTrackerz.Accounts.User do
      allow_nil?(false)
    end

    belongs_to :gym, FitTrackerz.Gym.Gym do
      allow_nil?(false)
    end

    belongs_to :branch, FitTrackerz.Gym.GymBranch

    belongs_to :assigned_trainer, FitTrackerz.Gym.GymTrainer
  end

  identities do
    identity(:unique_membership, [:user_id, :gym_id])
  end
end
