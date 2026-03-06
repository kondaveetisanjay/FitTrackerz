# Fit Trackerz Architecture Patterns

> Adopted from the NexProp Portal project architecture. This document serves as the reference guide for all backend coding patterns used in Fit Trackerz.

---

## Table of Contents

1. [Domain Functions via `define`](#1-domain-functions-via-define)
2. [Custom Read Actions with Built-in Filters](#2-custom-read-actions-with-built-in-filters)
3. [SystemActor Pattern](#3-systemactor-pattern)
4. [Universal Policy Bypass](#4-universal-policy-bypass)
5. [Domain-Level Authorization Config](#5-domain-level-authorization-config)
6. [No Bang Functions in Production](#6-no-bang-functions-in-production)
7. [Actor Passing in LiveViews](#7-actor-passing-in-liveviews)
8. [AshErrorHelpers](#8-asherrorhelpers)
9. [Load Option Helpers](#9-load-option-helpers)
10. [Calculations](#10-calculations)
11. [Aggregates](#11-aggregates)
12. [Preparations](#12-preparations)
13. [AshPhoenix.Form](#13-ashphoenixform)
14. [Fragment-Based Resource Organization](#14-fragment-based-resource-organization)
15. [State Machines](#15-state-machines)
16. [PubSub / Real-Time Notifications](#16-pubsub--real-time-notifications)
17. [Structured Logging](#17-structured-logging)
18. [PermissionCache (ETS)](#18-permissioncache-ets)

---

## 1. Domain Functions via `define`

**Rule**: LiveViews NEVER call `Ash.read()`, `Ash.Query.filter()`, `Ash.get()` directly. All data access goes through domain-defined functions.

### How It Works

Domains declare typed wrapper functions using `define` inside the `resources` block. These become the public API for the entire app.

### Example

```elixir
# lib/fit_trackerz/gym.ex (domain)
defmodule FitTrackerz.Gym do
  use Ash.Domain

  authorization do
    authorize :by_default
    require_actor? false
  end

  resources do
    resource FitTrackerz.Gym.Gym do
      define :list_gyms, action: :read
      define :get_gym, args: [:id], action: :get_by_id
      define :list_gyms_by_owner, args: [:owner_id], action: :list_by_owner
      define :create_gym, action: :create
      define :update_gym, action: :update
      define :destroy_gym, action: :destroy
    end

    resource FitTrackerz.Gym.GymMember do
      define :list_gym_members, action: :read
      define :list_members_by_gym, args: [:gym_id], action: :list_by_gym
      define :get_gym_member, args: [:id], action: :get_by_id
    end
  end
end
```

### LiveView Usage

```elixir
# CORRECT - Call domain function
case FitTrackerz.Gym.list_gyms_by_owner(user.id, actor: current_user) do
  {:ok, gyms} -> assign(socket, :gyms, gyms)
  {:error, _} -> assign(socket, :gyms, [])
end

# WRONG - Direct Ash call in LiveView
gyms = FitTrackerz.Gym.Gym
       |> Ash.Query.filter(owner_id == ^user.id)
       |> Ash.read!()
```

### Why

- Single source of truth for data access
- Authorization enforced consistently
- Easy to test, mock, and refactor
- LiveViews stay thin — only UI logic

---

## 2. Custom Read Actions with Built-in Filters

**Rule**: Resources define named read actions (`:list_by_gym`, `:get_by_id`, `:list_active`) with filters baked in. LiveViews do NOT construct `Ash.Query.filter()` calls.

### Example

```elixir
# In resource file:
actions do
  read :read do
    primary? true
  end

  read :get_by_id do
    get? true
    argument :id, :uuid, allow_nil?: false
    filter expr(id == ^arg(:id))
  end

  read :list_by_gym do
    argument :gym_id, :uuid, allow_nil?: false
    filter expr(gym_id == ^arg(:gym_id))
    prepare build(load: [:user, :branch])
  end

  read :list_by_owner do
    argument :owner_id, :uuid, allow_nil?: false
    filter expr(owner_id == ^arg(:owner_id))
    prepare build(load: [:branches, :gym_members, :gym_trainers])
  end

  read :list_active do
    filter expr(is_active == true)
  end

  read :list_pending do
    filter expr(status == :pending)
  end
end
```

### Why

- Filters are validated at compile time
- Preparations (preloading) are tied to the action
- Authorization policies can target specific actions
- Reusable across LiveViews, tests, and background jobs

---

## 3. SystemActor Pattern

**Rule**: Use a SystemActor module instead of `authorize?: false`. System operations pass `actor: SystemActor.system_actor()` to Ash calls.

### Module

```elixir
# lib/fit_trackerz/accounts/system_actor.ex
defmodule FitTrackerz.Accounts.SystemActor do
  @moduledoc """
  System actor for internal operations that bypass user-level authorization.
  Used in change callbacks, background jobs, and system-level data access.
  """

  def system_actor do
    %{
      id: "00000000-0000-0000-0000-000000000000",
      role: :platform_admin,
      email: "system@fit_trackerz.com",
      is_system_actor: true
    }
  end

  def system_actor?(%{is_system_actor: true}), do: true
  def system_actor?(_), do: false
end
```

### Usage in Change Callbacks

```elixir
# CORRECT - Use system actor
alias FitTrackerz.Accounts.SystemActor

case Ash.get(FitTrackerz.Accounts.User, email: email, actor: SystemActor.system_actor()) do
  {:ok, user} -> ...
end

# WRONG - authorize?: false
case Ash.get(FitTrackerz.Accounts.User, email: email, authorize?: false) do
  {:ok, user} -> ...
end
```

### Why

- Auditable: system operations have a traceable actor
- Consistent: same authorization flow for all calls
- Secure: system actor is explicitly defined, not a blanket bypass

---

## 4. Universal Policy Bypass

**Rule**: Every resource's `policies` block MUST start with a bypass for system actors and platform admins.

### Pattern

```elixir
policies do
  # MUST be first — system actors bypass everything
  bypass actor_attribute_equals(:is_system_actor, true) do
    authorize_if always()
  end

  # Platform admin bypass
  bypass actor_attribute_equals(:role, :platform_admin) do
    authorize_if always()
  end

  # Then normal policies...
  policy action_type(:read) do
    authorize_if always()
  end

  policy action_type([:create, :update, :destroy]) do
    authorize_if actor_attribute_equals(:role, :gym_operator)
  end
end
```

### Why

- System operations (change callbacks, background jobs) always succeed
- Platform admins have unrestricted access
- Regular users are governed by specific policies below the bypass

---

## 5. Domain-Level Authorization Config

**Rule**: Every domain must have `authorize :by_default` and `require_actor? false`.

```elixir
defmodule FitTrackerz.Gym do
  use Ash.Domain

  authorization do
    authorize :by_default
    require_actor? false
  end

  resources do
    # ...
  end
end
```

- `authorize :by_default` — All actions check policies automatically
- `require_actor? false` — Allows system actors and nil actors for background operations

---

## 6. No Bang Functions in Production

**Rule**: Never use `Ash.read!()`, `Ash.get!()`, `Ash.count!()`, `Ash.create!()`, `Ash.update!()`, `Ash.destroy!()` in production code. Bang functions are ONLY for tests.

### Production Code

```elixir
# CORRECT
case Ash.read(query, actor: actor) do
  {:ok, results} -> results
  {:error, error} ->
    Logger.error("Failed to load: #{inspect(error)}")
    []
end

# WRONG
results = Ash.read!(query)
```

### Test Code (bang is OK)

```elixir
test "lists gym members" do
  members = FitTrackerz.Gym.GymMember |> Ash.read!(actor: admin)
  assert length(members) > 0
end
```

---

## 7. Actor Passing in LiveViews

**Rule**: Every Ash call in a LiveView must include `actor: socket.assigns.current_user`.

### Mount

```elixir
def mount(_params, _session, socket) do
  current_user = socket.assigns.current_user

  case FitTrackerz.Gym.list_gyms_by_owner(current_user.id, actor: current_user) do
    {:ok, gyms} ->
      {:ok, assign(socket, :gyms, gyms)}
    {:error, _} ->
      {:ok,
       socket
       |> put_flash(:error, "Unable to load gyms")
       |> assign(:gyms, [])}
  end
end
```

### Handle Events

```elixir
def handle_event("delete", %{"id" => id}, socket) do
  actor = socket.assigns.current_user

  case FitTrackerz.Gym.get_gym(id, actor: actor) do
    {:ok, gym} ->
      case FitTrackerz.Gym.destroy_gym(gym, actor: actor) do
        :ok -> {:noreply, put_flash(socket, :info, "Gym deleted")}
        {:error, _} -> {:noreply, put_flash(socket, :error, "Failed to delete")}
      end
    {:error, _} ->
      {:noreply, put_flash(socket, :error, "Gym not found")}
  end
end
```

---

## 8. AshErrorHelpers

**Rule**: Never show raw Ash errors to users. Use a shared helper module to translate errors into user-friendly messages.

```elixir
# lib/fit_trackerz_web/helpers/ash_error_helpers.ex
defmodule FitTrackerzWeb.AshErrorHelpers do
  @moduledoc "Translates Ash errors into user-friendly flash messages."

  def user_friendly_message(%Ash.Error.Invalid{errors: errors}) do
    errors
    |> Enum.map(&format_error/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
    |> case do
      [] -> "Validation failed. Please check your input."
      messages -> Enum.join(messages, ". ")
    end
  end

  def user_friendly_message(%Ash.Error.Forbidden{}) do
    "You don't have permission to perform this action."
  end

  def user_friendly_message(_), do: "Something went wrong. Please try again."

  defp format_error(%Ash.Error.Changes.InvalidAttribute{field: field, message: message}) do
    "#{Phoenix.Naming.humanize(field)} #{message}"
  end

  defp format_error(%Ash.Error.Changes.Required{field: field}) do
    "#{Phoenix.Naming.humanize(field)} is required"
  end

  defp format_error(_), do: nil
end
```

### Usage in LiveView

```elixir
{:error, error} ->
  {:noreply, put_flash(socket, :error, AshErrorHelpers.user_friendly_message(error))}
```

---

## 9. Load Option Helpers

**Rule**: Standardize what gets preloaded for each resource using helper modules. Don't scatter `load:` lists across LiveViews.

```elixir
# lib/fit_trackerz_web/helpers/load_options.ex
defmodule FitTrackerzWeb.LoadOptions do
  def gym_basic, do: [:branches, :owner]

  def gym_detailed do
    gym_basic() ++ [:gym_members, :gym_trainers, :member_invitations, :trainer_invitations]
  end

  def gym_member_basic, do: [:user, :branch, :assigned_trainer]

  def scheduled_class_basic, do: [:class_definition, :branch, :trainer, :bookings]
end

# Usage:
FitTrackerz.Gym.list_gyms(actor: actor, load: LoadOptions.gym_basic())
```

---

## 10. Calculations

**Rule**: Derived fields should be declared as `calculate` in the resource, not computed in LiveViews.

```elixir
calculations do
  calculate :member_count, :integer, expr(count(gym_members))

  calculate :is_verified, :boolean, expr(status == :verified)

  calculate :display_name, :string, expr(
    if(is_nil(name), slug, name)
  )
end
```

### Why

- Computed at DB level — efficient
- Available in filters, sorts, and policies
- Single source of truth

---

## 11. Aggregates

**Rule**: Use resource-level aggregates for counts and existence checks instead of `Ash.count!()` in LiveViews.

```elixir
aggregates do
  count :member_count, :gym_members do
    filter expr(is_active == true)
  end

  count :trainer_count, :gym_trainers do
    filter expr(is_active == true)
  end

  exists :has_active_subscription, :member_subscriptions do
    filter expr(status == :active)
  end
end
```

### Usage

```elixir
# Load aggregate like any other field:
FitTrackerz.Gym.get_gym(id, actor: actor, load: [:member_count, :trainer_count])
```

---

## 12. Preparations

**Rule**: Use `prepare` inside read actions to auto-load relationships, apply default sorting, and build queries at the resource level.

```elixir
read :list_by_gym do
  argument :gym_id, :uuid, allow_nil?: false
  filter expr(gym_id == ^arg(:gym_id))

  prepare build(load: [:user, :branch])
  prepare build(sort: [inserted_at: :desc])
end
```

---

## 13. AshPhoenix.Form

**Rule**: Use `AshPhoenix.Form` for all form handling instead of manual changesets.

```elixir
# Mount:
form = AshPhoenix.Form.for_create(FitTrackerz.Gym.Gym, :create, as: "gym")
{:ok, assign(socket, form: form)}

# Validate:
def handle_event("validate", %{"gym" => params}, socket) do
  form = AshPhoenix.Form.validate(socket.assigns.form, params)
  {:noreply, assign(socket, form: form)}
end

# Submit:
def handle_event("save", %{"gym" => params}, socket) do
  case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
    {:ok, gym} -> {:noreply, push_navigate(socket, to: ~p"/gym/#{gym.id}")}
    {:error, form} -> {:noreply, assign(socket, form: form)}
  end
end
```

---

## 14. Fragment-Based Resource Organization

**Rule**: For resources with 200+ lines, split into `Spark.Dsl.Fragment` modules. Not needed for small resources.

```
lib/fit_trackerz/gym/gym.ex (main)
  └── lib/fit_trackerz/gym/gym/fragments/
      ├── gym_policies.ex
      ├── gym_attributes.ex
      ├── gym_actions_read.ex
      └── gym_actions_write.ex
```

**Fit Trackerz status**: Resources are small enough — skip for now.

---

## 15. State Machines

**Rule**: Use `AshStateMachine` for resources with status workflows (invitations, subscriptions, bookings).

```elixir
state_machine do
  state_attribute(:status)
  initial_states([:pending])
  transitions do
    transition(:accept, from: :pending, to: :accepted)
    transition(:reject, from: :pending, to: :rejected)
    transition(:expire, from: :pending, to: :expired)
  end
end
```

**Fit Trackerz status**: Good candidate for invitations, bookings, subscriptions — implement later.

---

## 16. PubSub / Real-Time Notifications

**Rule**: Use `Ash.Notifier.PubSub` on resources for real-time updates. Subscribe in LiveView mount with `connected?(socket)` guard.

```elixir
# Resource:
use Ash.Resource, notifiers: [Ash.Notifier.PubSub]

# LiveView:
if connected?(socket) do
  Phoenix.PubSub.subscribe(FitTrackerz.PubSub, "gym:#{gym.id}")
end
```

**Fit Trackerz status**: Implement later for booking updates, invitation responses.

---

## 17. Structured Logging

**Rule**: Always log errors with context (module, action, details). Never silently swallow errors.

```elixir
Logger.error("Failed to load gym members",
  module: __MODULE__,
  action: :mount,
  gym_id: gym_id,
  error: inspect(error)
)
```

---

## 18. PermissionCache (ETS)

**Rule**: Cache full actor data in ETS to avoid repeated DB queries on every LiveView mount.

**Fit Trackerz status**: Not needed at current scale — implement when performance requires it.

---

## Implementation Priority

| Priority | Pattern | Status |
|----------|---------|--------|
| P1 | SystemActor module | TODO |
| P1 | Universal policy bypass on all resources | TODO |
| P1 | `require_actor? false` in domains | TODO |
| P1 | Domain `define` functions | TODO |
| P1 | Custom read actions with filters | TODO |
| P1 | Pass `actor:` in all LiveViews | TODO |
| P1 | Replace all bang functions | TODO |
| P2 | AshErrorHelpers | TODO |
| P2 | Load option helpers | TODO |
| P2 | Calculations & Aggregates | TODO |
| P3 | Preparations on read actions | TODO |
| P3 | AshPhoenix.Form | TODO |
| P4 | Fragments, State Machines, PubSub | Future |
