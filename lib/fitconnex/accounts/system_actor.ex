defmodule Fitconnex.Accounts.SystemActor do
  @moduledoc """
  System actor for internal operations that bypass user-level authorization.

  Used in:
  - Change callbacks (e.g., creating gym member on invitation accept)
  - Background jobs
  - System-level data access

  The system actor is recognized by the `is_system_actor: true` flag
  and bypassed in all resource policies via the universal bypass rule.
  """

  def system_actor do
    %{
      id: "00000000-0000-0000-0000-000000000000",
      role: :platform_admin,
      email: "system@fitconnex.com",
      is_system_actor: true
    }
  end

  def system_actor?(%{is_system_actor: true}), do: true
  def system_actor?(_), do: false
end
