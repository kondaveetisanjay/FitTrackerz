defmodule FitTrackerz.Training.QrCheckIn do
  use Ash.Resource,
    domain: FitTrackerz.Training,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  import Ecto.Query, only: [from: 2]

  postgres do
    table("training_qr_check_ins")
    repo(FitTrackerz.Repo)

    references do
      reference :gym_member, on_delete: :delete
      reference :gym_branch, on_delete: :nilify
    end

    custom_indexes do
      index([:gym_member_id])
      index([:token])
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

    policy action(:generate) do
      authorize_if actor_attribute_equals(:role, :member)
    end

    policy action(:redeem) do
      authorize_if actor_attribute_equals(:role, :gym_operator)
      authorize_if actor_attribute_equals(:role, :trainer)
    end

    policy action_type(:destroy) do
      authorize_if actor_attribute_equals(:role, :gym_operator)
    end
  end

  actions do
    defaults([:read, :destroy])

    read :get_by_token do
      get? true
      argument :token, :string, allow_nil?: false
      filter expr(token == ^arg(:token))
    end

    read :list_by_member do
      argument :gym_member_id, :uuid, allow_nil?: false
      filter expr(gym_member_id == ^arg(:gym_member_id))
      prepare build(sort: [inserted_at: :desc], limit: 5)
    end

    create :generate do
      accept([:gym_member_id, :gym_branch_id])

      validate fn changeset, _context ->
        gym_member_id = Ash.Changeset.get_attribute(changeset, :gym_member_id)

        if gym_member_id do
          tier =
            from(g in FitTrackerz.Gym.Gym,
              join: m in FitTrackerz.Gym.GymMember,
              on: m.gym_id == g.id,
              where: m.id == ^gym_member_id,
              select: g.tier
            )
            |> FitTrackerz.Repo.one()

          cond do
            is_nil(tier) ->
              :ok

            tier == :premium ->
              :ok

            true ->
              {:error,
               field: :gym_member_id,
               message: "QR check-in is a Premium feature. Ask your gym operator to upgrade."}
          end
        else
          :ok
        end
      end

      change fn changeset, _context ->
        gym_member_id = Ash.Changeset.get_attribute(changeset, :gym_member_id)

        if gym_member_id do
          from(q in FitTrackerz.Training.QrCheckIn,
            where: q.gym_member_id == ^gym_member_id and q.status == :active
          )
          |> FitTrackerz.Repo.update_all(set: [status: :expired])
        end

        token = Ecto.UUID.generate()
        expires_at = DateTime.add(DateTime.utc_now(), 24 * 60 * 60, :second)

        changeset
        |> Ash.Changeset.change_attribute(:token, token)
        |> Ash.Changeset.change_attribute(:expires_at, expires_at)
        |> Ash.Changeset.change_attribute(:status, :active)
      end
    end

    update :redeem do
      accept([])
      require_atomic? false

      validate fn changeset, _context ->
        record = changeset.data

        cond do
          record.status != :active ->
            {:error, field: :status, message: "This QR code has already been used or expired."}

          DateTime.compare(record.expires_at, DateTime.utc_now()) == :lt ->
            {:error,
             field: :expires_at,
             message:
               "This QR code has expired. Ask the member to generate a new one."}

          true ->
            :ok
        end
      end

      change fn changeset, _context ->
        record = changeset.data

        gym_id =
          from(m in FitTrackerz.Gym.GymMember,
            where: m.id == ^record.gym_member_id,
            select: m.gym_id
          )
          |> FitTrackerz.Repo.one!()

        Ash.create!(
          FitTrackerz.Training.AttendanceRecord,
          %{
            member_id: record.gym_member_id,
            gym_id: gym_id,
            attended_at: DateTime.utc_now(),
            notes: "QR check-in"
          },
          authorize?: false
        )

        changeset
        |> Ash.Changeset.change_attribute(:used_at, DateTime.utc_now())
        |> Ash.Changeset.change_attribute(:status, :used)
      end
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute :token, :string do
      allow_nil?(false)
      constraints(max_length: 36)
    end

    attribute :expires_at, :utc_datetime do
      allow_nil?(false)
    end

    attribute :used_at, :utc_datetime

    attribute :status, :atom do
      constraints(one_of: [:active, :used, :expired])
      allow_nil?(false)
      default(:active)
    end

    timestamps()
  end

  relationships do
    belongs_to :gym_member, FitTrackerz.Gym.GymMember do
      allow_nil?(false)
    end

    belongs_to :gym_branch, FitTrackerz.Gym.GymBranch
  end

  identities do
    identity :unique_token, [:token]
  end
end
