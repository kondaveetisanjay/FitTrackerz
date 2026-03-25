# Messaging System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add real-time messaging to FitTrackerz — 1-to-1 direct conversations and broadcast announcements between gym operators, trainers, and members, with file attachments.

**Architecture:** New `FitTrackerz.Messaging` Ash domain with 3 resources (Conversation, ConversationParticipant, Message). Real-time via Phoenix PubSub. File uploads via LiveView `allow_upload` stored locally. One MessagesLive page per role with two-panel chat UI.

**Tech Stack:** Ash Framework 3.0, AshPostgres, Phoenix LiveView 1.1, Phoenix PubSub, DaisyUI/Tailwind CSS 4

---

## File Structure

### New Files

| File | Responsibility |
|------|---------------|
| `lib/fit_trackerz/messaging.ex` | Ash Domain — registers resources, defines domain functions |
| `lib/fit_trackerz/messaging/conversation.ex` | Conversation resource (direct/announcement) |
| `lib/fit_trackerz/messaging/conversation_participant.ex` | Join table with read tracking |
| `lib/fit_trackerz/messaging/message.ex` | Message resource with attachments |
| `priv/repo/migrations/TIMESTAMP_add_messaging.exs` | Migration for 3 tables |
| `lib/fit_trackerz_web/live/gym_operator/messages_live.ex` | Operator messaging page |
| `lib/fit_trackerz_web/live/trainer/messages_live.ex` | Trainer messaging page |
| `lib/fit_trackerz_web/live/member/messages_live.ex` | Member messaging page |

### Modified Files

| File | Change |
|------|--------|
| `config/config.exs` | Add `FitTrackerz.Messaging` to `ash_domains` |
| `lib/fit_trackerz_web/router.ex` | Add `/gym/messages`, `/trainer/messages`, `/member/messages` routes |
| `lib/fit_trackerz_web/components/layouts.ex` | Add "Messages" nav link for each role sidebar |

---

### Task 1: Database Migration

**Files:**
- Create: `priv/repo/migrations/TIMESTAMP_add_messaging.exs`

- [ ] **Step 1: Generate migration timestamp**

```bash
mix ecto.gen.migration add_messaging
```

- [ ] **Step 2: Write the migration**

Replace the generated file contents with:

```elixir
defmodule FitTrackerz.Repo.Migrations.AddMessaging do
  use Ecto.Migration

  def change do
    create table(:conversations, primary_key: false) do
      add :id, :uuid, primary_key: true, null: false, default: fragment("gen_random_uuid()")
      add :type, :text, null: false
      add :title, :text

      add :gym_id, references(:gyms, type: :uuid, on_delete: :delete_all), null: false
      add :created_by_id, references(:users, type: :uuid, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:conversations, [:gym_id])
    create index(:conversations, [:created_by_id])

    create table(:conversation_participants, primary_key: false) do
      add :id, :uuid, primary_key: true, null: false, default: fragment("gen_random_uuid()")
      add :role, :text, null: false, default: "participant"
      add :last_read_at, :utc_datetime_usec

      add :conversation_id, references(:conversations, type: :uuid, on_delete: :delete_all), null: false
      add :user_id, references(:users, type: :uuid, on_delete: :delete_all), null: false

      timestamps()
    end

    create unique_index(:conversation_participants, [:conversation_id, :user_id])
    create index(:conversation_participants, [:user_id])
    create index(:conversation_participants, [:conversation_id])

    create table(:messages, primary_key: false) do
      add :id, :uuid, primary_key: true, null: false, default: fragment("gen_random_uuid()")
      add :body, :text, null: false
      add :attachments, {:array, :map}, default: []

      add :conversation_id, references(:conversations, type: :uuid, on_delete: :delete_all), null: false
      add :sender_id, references(:users, type: :uuid, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:messages, [:conversation_id, :inserted_at])
    create index(:messages, [:sender_id])
  end
end
```

- [ ] **Step 3: Run migration**

```bash
mix ecto.migrate
```

- [ ] **Step 4: Verify tables exist**

```bash
mix run -e "FitTrackerz.Repo.query!(\"SELECT table_name FROM information_schema.tables WHERE table_name IN ('conversations', 'conversation_participants', 'messages')\") |> then(& &1.rows) |> IO.inspect()"
```

---

### Task 2: Ash Resources — Conversation, ConversationParticipant, Message

**Files:**
- Create: `lib/fit_trackerz/messaging/conversation.ex`
- Create: `lib/fit_trackerz/messaging/conversation_participant.ex`
- Create: `lib/fit_trackerz/messaging/message.ex`

- [ ] **Step 1: Create Conversation resource**

```elixir
# lib/fit_trackerz/messaging/conversation.ex
defmodule FitTrackerz.Messaging.Conversation do
  use Ash.Resource,
    domain: FitTrackerz.Messaging,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("conversations")
    repo(FitTrackerz.Repo)

    references do
      reference :gym, on_delete: :delete
      reference :created_by, on_delete: :delete
    end

    custom_indexes do
      index([:gym_id])
      index([:created_by_id])
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

    policy action_type(:create) do
      authorize_if actor_attribute_equals(:role, :gym_operator)
      authorize_if actor_attribute_equals(:role, :trainer)
      authorize_if actor_attribute_equals(:role, :member)
    end
  end

  actions do
    defaults([:read, :destroy])

    read :get_by_id do
      get? true
      argument :id, :uuid, allow_nil?: false
      filter expr(id == ^arg(:id))
    end

    read :list_by_participant do
      argument :user_id, :uuid, allow_nil?: false

      prepare fn query, _context ->
        require Ash.Query

        query
        |> Ash.Query.filter(
          expr(
            exists(participants, user_id == ^arg(:user_id))
          )
        )
        |> Ash.Query.sort(updated_at: :desc)
        |> Ash.Query.load([:participants, :messages, :created_by])
      end
    end

    read :list_direct_by_participant do
      argument :user_id, :uuid, allow_nil?: false

      prepare fn query, _context ->
        require Ash.Query

        query
        |> Ash.Query.filter(
          expr(
            type == :direct and exists(participants, user_id == ^arg(:user_id))
          )
        )
        |> Ash.Query.sort(updated_at: :desc)
        |> Ash.Query.load([:participants, :messages, :created_by])
      end
    end

    read :list_announcements_by_participant do
      argument :user_id, :uuid, allow_nil?: false

      prepare fn query, _context ->
        require Ash.Query

        query
        |> Ash.Query.filter(
          expr(
            type == :announcement and exists(participants, user_id == ^arg(:user_id))
          )
        )
        |> Ash.Query.sort(updated_at: :desc)
        |> Ash.Query.load([:participants, :messages, :created_by])
      end
    end

    read :find_direct_between do
      argument :user_id_1, :uuid, allow_nil?: false
      argument :user_id_2, :uuid, allow_nil?: false
      argument :gym_id, :uuid, allow_nil?: false

      prepare fn query, _context ->
        require Ash.Query

        query
        |> Ash.Query.filter(
          expr(
            type == :direct and
              gym_id == ^arg(:gym_id) and
              exists(participants, user_id == ^arg(:user_id_1)) and
              exists(participants, user_id == ^arg(:user_id_2))
          )
        )
        |> Ash.Query.load([:participants, :messages, :created_by])
      end
    end

    create :create do
      accept([:type, :title, :gym_id, :created_by_id])
    end

    update :update do
      accept([:title])
    end

    update :touch do
      accept([])
      change set_attribute(:updated_at, &DateTime.utc_now/0)
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute :type, :atom do
      constraints(one_of: [:direct, :announcement])
      allow_nil?(false)
    end

    attribute :title, :string do
      constraints(max_length: 255)
    end

    timestamps()
  end

  relationships do
    belongs_to :gym, FitTrackerz.Gym.Gym do
      allow_nil?(false)
    end

    belongs_to :created_by, FitTrackerz.Accounts.User do
      allow_nil?(false)
    end

    has_many :participants, FitTrackerz.Messaging.ConversationParticipant do
      destination_attribute(:conversation_id)
    end

    has_many :messages, FitTrackerz.Messaging.Message do
      destination_attribute(:conversation_id)
    end
  end
end
```

- [ ] **Step 2: Create ConversationParticipant resource**

```elixir
# lib/fit_trackerz/messaging/conversation_participant.ex
defmodule FitTrackerz.Messaging.ConversationParticipant do
  use Ash.Resource,
    domain: FitTrackerz.Messaging,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("conversation_participants")
    repo(FitTrackerz.Repo)

    references do
      reference :conversation, on_delete: :delete
      reference :user, on_delete: :delete
    end

    custom_indexes do
      index([:user_id])
      index([:conversation_id])
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

    policy action_type([:create, :update]) do
      authorize_if actor_attribute_equals(:role, :gym_operator)
      authorize_if actor_attribute_equals(:role, :trainer)
      authorize_if actor_attribute_equals(:role, :member)
    end
  end

  actions do
    defaults([:read, :destroy])

    read :list_by_conversation do
      argument :conversation_id, :uuid, allow_nil?: false
      filter expr(conversation_id == ^arg(:conversation_id))
      prepare build(load: [:user])
    end

    read :list_by_user do
      argument :user_id, :uuid, allow_nil?: false
      filter expr(user_id == ^arg(:user_id))
      prepare build(load: [:conversation])
    end

    create :create do
      accept([:conversation_id, :user_id, :role])
    end

    update :mark_read do
      accept([])
      change set_attribute(:last_read_at, &DateTime.utc_now/0)
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute :role, :atom do
      constraints(one_of: [:owner, :participant])
      allow_nil?(false)
      default(:participant)
    end

    attribute :last_read_at, :utc_datetime_usec

    timestamps()
  end

  relationships do
    belongs_to :conversation, FitTrackerz.Messaging.Conversation do
      allow_nil?(false)
    end

    belongs_to :user, FitTrackerz.Accounts.User do
      allow_nil?(false)
    end
  end

  identities do
    identity(:unique_participant, [:conversation_id, :user_id])
  end
end
```

- [ ] **Step 3: Create Message resource**

```elixir
# lib/fit_trackerz/messaging/message.ex
defmodule FitTrackerz.Messaging.Message do
  use Ash.Resource,
    domain: FitTrackerz.Messaging,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("messages")
    repo(FitTrackerz.Repo)

    references do
      reference :conversation, on_delete: :delete
      reference :sender, on_delete: :delete
    end

    custom_indexes do
      index([:conversation_id, :inserted_at])
      index([:sender_id])
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

    policy action_type(:create) do
      authorize_if actor_attribute_equals(:role, :gym_operator)
      authorize_if actor_attribute_equals(:role, :trainer)
      authorize_if actor_attribute_equals(:role, :member)
    end
  end

  actions do
    defaults([:read, :destroy])

    read :list_by_conversation do
      argument :conversation_id, :uuid, allow_nil?: false
      filter expr(conversation_id == ^arg(:conversation_id))
      prepare build(sort: [inserted_at: :asc], load: [:sender])
    end

    read :latest_by_conversation do
      argument :conversation_id, :uuid, allow_nil?: false
      filter expr(conversation_id == ^arg(:conversation_id))
      prepare build(sort: [inserted_at: :desc], limit: 1, load: [:sender])
    end

    create :create do
      accept([:body, :attachments, :conversation_id, :sender_id])
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute :body, :string do
      allow_nil?(false)
      constraints(max_length: 5000)
    end

    attribute :attachments, {:array, :map} do
      default([])
    end

    timestamps()
  end

  relationships do
    belongs_to :conversation, FitTrackerz.Messaging.Conversation do
      allow_nil?(false)
    end

    belongs_to :sender, FitTrackerz.Accounts.User do
      allow_nil?(false)
    end
  end
end
```

- [ ] **Step 4: Verify all 3 files compile**

```bash
mix compile --warnings-as-errors
```

---

### Task 3: Ash Domain & Config Registration

**Files:**
- Create: `lib/fit_trackerz/messaging.ex`
- Modify: `config/config.exs:13-21`

- [ ] **Step 1: Create the Messaging domain module**

```elixir
# lib/fit_trackerz/messaging.ex
defmodule FitTrackerz.Messaging do
  use Ash.Domain

  authorization do
    authorize :by_default
    require_actor? true
  end

  resources do
    resource FitTrackerz.Messaging.Conversation do
      define :get_conversation, args: [:id], action: :get_by_id
      define :list_conversations, args: [:user_id], action: :list_by_participant
      define :list_direct_conversations, args: [:user_id], action: :list_direct_by_participant
      define :list_announcements, args: [:user_id], action: :list_announcements_by_participant
      define :find_direct_conversation, args: [:user_id_1, :user_id_2, :gym_id], action: :find_direct_between
      define :create_conversation, action: :create
      define :update_conversation, action: :update
      define :touch_conversation, action: :touch
      define :destroy_conversation, action: :destroy
    end

    resource FitTrackerz.Messaging.ConversationParticipant do
      define :list_participants, args: [:conversation_id], action: :list_by_conversation
      define :list_user_participations, args: [:user_id], action: :list_by_user
      define :create_participant, action: :create
      define :mark_participant_read, action: :mark_read
      define :destroy_participant, action: :destroy
    end

    resource FitTrackerz.Messaging.Message do
      define :list_messages, args: [:conversation_id], action: :list_by_conversation
      define :get_latest_message, args: [:conversation_id], action: :latest_by_conversation
      define :create_message, action: :create
      define :destroy_message, action: :destroy
    end
  end
end
```

- [ ] **Step 2: Register domain in config**

In `config/config.exs`, add `FitTrackerz.Messaging` to the `ash_domains` list:

```elixir
ash_domains: [
    FitTrackerz.Accounts,
    FitTrackerz.Gym,
    FitTrackerz.Billing,
    FitTrackerz.Training,
    FitTrackerz.Scheduling,
    FitTrackerz.Health,
    FitTrackerz.Notifications,
    FitTrackerz.Messaging
  ]
```

- [ ] **Step 3: Verify compilation**

```bash
mix compile --warnings-as-errors
```

---

### Task 4: Routes & Sidebar Navigation

**Files:**
- Modify: `lib/fit_trackerz_web/router.ex:108-118` (gym operator scope)
- Modify: `lib/fit_trackerz_web/router.ex:128-141` (trainer scope)
- Modify: `lib/fit_trackerz_web/router.ex:150-168` (member scope)
- Modify: `lib/fit_trackerz_web/components/layouts.ex:193-219` (gym operator sidebar)
- Modify: `lib/fit_trackerz_web/components/layouts.ex:221-254` (trainer sidebar)
- Modify: `lib/fit_trackerz_web/components/layouts.ex:256-299` (member sidebar)

- [ ] **Step 1: Add routes for all 3 roles**

In the gym operator scope (after `live "/notifications", NotificationsLive"`):
```elixir
live "/messages", MessagesLive
```

In the trainer scope (after `live "/attendance", AttendanceLive`):
```elixir
live "/messages", MessagesLive
```

In the member scope (after `live "/notifications", NotificationsLive`):
```elixir
live "/messages", MessagesLive
```

- [ ] **Step 2: Add "Messages" link to gym operator sidebar**

In `layouts.ex` gym_operator sidebar, add after the Notifications link:
```html
<.nav_link href="/gym/messages" icon="hero-chat-bubble-left-right-solid" label="Messages" />
```

- [ ] **Step 3: Add "Messages" link to trainer sidebar**

In `layouts.ex` trainer sidebar, add a new "Communication" section before the Schedule section:
```html
<div class="divider my-3"></div>
<p class="px-3 text-xs font-semibold text-base-content/40 uppercase tracking-wider mb-2">
  Communication
</p>
<.nav_link href="/trainer/messages" icon="hero-chat-bubble-left-right-solid" label="Messages" />
```

- [ ] **Step 4: Add "Messages" link to member sidebar**

In `layouts.ex` member sidebar, add in the Account section after Notifications:
```html
<.nav_link href="/member/messages" icon="hero-chat-bubble-left-right-solid" label="Messages" />
```

- [ ] **Step 5: Verify compilation**

```bash
mix compile --warnings-as-errors
```

---

### Task 5: Gym Operator MessagesLive

**Files:**
- Create: `lib/fit_trackerz_web/live/gym_operator/messages_live.ex`

This is the most complete implementation. Trainer and Member versions will follow the same pattern with role-specific contact loading.

- [ ] **Step 1: Create the full MessagesLive for gym operator**

```elixir
# lib/fit_trackerz_web/live/gym_operator/messages_live.ex
defmodule FitTrackerzWeb.GymOperator.MessagesLive do
  use FitTrackerzWeb, :live_view

  alias FitTrackerz.Messaging
  alias FitTrackerz.Gym

  @impl true
  def mount(_params, _session, socket) do
    actor = socket.assigns.current_user

    if connected?(socket) do
      Phoenix.PubSub.subscribe(FitTrackerz.PubSub, "messaging:user:#{actor.id}")
    end

    gym = load_gym(actor)
    conversations = load_conversations(actor, :all)

    {:ok,
     socket
     |> assign(
       page_title: "Messages",
       gym: gym,
       conversations: conversations,
       active_conversation: nil,
       active_messages: [],
       active_participants: [],
       message_body: "",
       tab: :all,
       show_new_direct: false,
       show_new_announcement: false,
       contacts: [],
       announcement_title: ""
     )
     |> allow_upload(:attachments,
       accept: :any,
       max_entries: 5,
       max_file_size: 10_000_000
     )}
  end

  @impl true
  def handle_params(%{"conversation_id" => id}, _uri, socket) do
    actor = socket.assigns.current_user

    case Messaging.get_conversation(id, actor: actor) do
      {:ok, conversation} ->
        open_conversation(socket, conversation, actor)

      _ ->
        {:noreply, put_flash(socket, :error, "Conversation not found.")}
    end
  end

  def handle_params(_params, _uri, socket), do: {:noreply, socket}

  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    tab = String.to_existing_atom(tab)
    actor = socket.assigns.current_user
    conversations = load_conversations(actor, tab)
    {:noreply, assign(socket, tab: tab, conversations: conversations)}
  end

  def handle_event("select_conversation", %{"id" => id}, socket) do
    actor = socket.assigns.current_user

    case Messaging.get_conversation(id, actor: actor) do
      {:ok, conversation} ->
        open_conversation(socket, conversation, actor)

      _ ->
        {:noreply, put_flash(socket, :error, "Conversation not found.")}
    end
  end

  def handle_event("show_new_direct", _params, socket) do
    actor = socket.assigns.current_user
    contacts = load_contacts(actor, socket.assigns.gym)
    {:noreply, assign(socket, show_new_direct: true, show_new_announcement: false, contacts: contacts)}
  end

  def handle_event("show_new_announcement", _params, socket) do
    {:noreply, assign(socket, show_new_announcement: true, show_new_direct: false, announcement_title: "")}
  end

  def handle_event("cancel_new", _params, socket) do
    {:noreply, assign(socket, show_new_direct: false, show_new_announcement: false)}
  end

  def handle_event("start_direct", %{"user_id" => user_id}, socket) do
    actor = socket.assigns.current_user
    gym = socket.assigns.gym

    # Check for existing conversation
    case Messaging.find_direct_conversation(actor.id, user_id, gym.id, actor: actor) do
      {:ok, [existing | _]} ->
        {:noreply,
         socket
         |> assign(show_new_direct: false)
         |> open_conversation_noreply(existing, actor)}

      _ ->
        # Create new conversation
        with {:ok, conversation} <-
               Messaging.create_conversation(
                 %{type: :direct, gym_id: gym.id, created_by_id: actor.id},
                 actor: actor
               ),
             {:ok, _} <-
               Messaging.create_participant(
                 %{conversation_id: conversation.id, user_id: actor.id, role: :owner},
                 actor: actor
               ),
             {:ok, _} <-
               Messaging.create_participant(
                 %{conversation_id: conversation.id, user_id: user_id, role: :participant},
                 actor: actor
               ) do
          # Notify the other user
          Phoenix.PubSub.broadcast(
            FitTrackerz.PubSub,
            "messaging:user:#{user_id}",
            {:new_conversation, %{conversation_id: conversation.id}}
          )

          conversations = load_conversations(actor, socket.assigns.tab)

          {:ok, conversation} = Messaging.get_conversation(conversation.id, actor: actor)

          {:noreply,
           socket
           |> assign(show_new_direct: false, conversations: conversations)
           |> open_conversation_noreply(conversation, actor)}
        else
          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Failed to create conversation.")}
        end
    end
  end

  def handle_event("create_announcement", %{"title" => title, "body" => body}, socket) do
    actor = socket.assigns.current_user
    gym = socket.assigns.gym

    with {:ok, conversation} <-
           Messaging.create_conversation(
             %{type: :announcement, title: title, gym_id: gym.id, created_by_id: actor.id},
             actor: actor
           ),
         {:ok, _} <-
           Messaging.create_participant(
             %{conversation_id: conversation.id, user_id: actor.id, role: :owner},
             actor: actor
           ),
         :ok <- add_announcement_recipients(conversation, gym, actor),
         {:ok, _message} <-
           Messaging.create_message(
             %{body: body, conversation_id: conversation.id, sender_id: actor.id},
             actor: actor
           ) do
      # Notify all participants
      broadcast_to_participants(conversation.id, actor, {:new_conversation, %{conversation_id: conversation.id}})

      conversations = load_conversations(actor, socket.assigns.tab)
      {:ok, conversation} = Messaging.get_conversation(conversation.id, actor: actor)

      {:noreply,
       socket
       |> assign(show_new_announcement: false, conversations: conversations)
       |> put_flash(:info, "Announcement sent!")
       |> open_conversation_noreply(conversation, actor)}
    else
      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to create announcement.")}
    end
  end

  def handle_event("send_message", %{"body" => body}, socket) when byte_size(body) > 0 do
    actor = socket.assigns.current_user
    conversation = socket.assigns.active_conversation

    # Handle file uploads
    attachment_data =
      consume_uploaded_entries(socket, :attachments, fn %{path: path}, entry ->
        dest_dir = Path.join(["priv/static/uploads/messages", conversation.id])
        File.mkdir_p!(dest_dir)

        filename = "#{Ecto.UUID.generate()}-#{entry.client_name}"
        dest = Path.join(dest_dir, filename)
        File.cp!(path, dest)

        {:ok,
         %{
           "filename" => entry.client_name,
           "url" => "/uploads/messages/#{conversation.id}/#{filename}",
           "content_type" => entry.client_type,
           "size" => entry.client_size
         }}
      end)

    attrs = %{
      body: body,
      conversation_id: conversation.id,
      sender_id: actor.id,
      attachments: attachment_data
    }

    case Messaging.create_message(attrs, actor: actor) do
      {:ok, message} ->
        # Touch conversation updated_at
        Messaging.touch_conversation(conversation, actor: actor)

        # Load sender for display
        message = %{message | sender: actor}

        # Broadcast to conversation channel
        Phoenix.PubSub.broadcast(
          FitTrackerz.PubSub,
          "messaging:conversation:#{conversation.id}",
          {:new_message, message}
        )

        # Broadcast to each participant's inbox (except sender)
        broadcast_to_participants(conversation.id, actor, {:conversation_updated, %{conversation_id: conversation.id}})

        {:noreply,
         socket
         |> assign(message_body: "")
         |> update(:active_messages, &(&1 ++ [message]))
         |> push_event("scroll_to_bottom", %{})}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to send message.")}
    end
  end

  def handle_event("send_message", _params, socket), do: {:noreply, socket}

  def handle_event("update_body", %{"body" => body}, socket) do
    {:noreply, assign(socket, message_body: body)}
  end

  def handle_event("cancel_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :attachments, ref)}
  end

  @impl true
  def handle_info({:new_message, message}, socket) do
    if socket.assigns.active_conversation &&
         socket.assigns.active_conversation.id == message.conversation_id &&
         message.sender_id != socket.assigns.current_user.id do
      # Mark as read
      mark_conversation_read(socket.assigns.active_conversation, socket.assigns.current_user)

      {:noreply,
       socket
       |> update(:active_messages, &(&1 ++ [message]))
       |> push_event("scroll_to_bottom", %{})}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:new_conversation, _payload}, socket) do
    conversations = load_conversations(socket.assigns.current_user, socket.assigns.tab)
    {:noreply, assign(socket, conversations: conversations)}
  end

  def handle_info({:conversation_updated, _payload}, socket) do
    conversations = load_conversations(socket.assigns.current_user, socket.assigns.tab)
    {:noreply, assign(socket, conversations: conversations)}
  end

  # Private helpers

  defp open_conversation(socket, conversation, actor) do
    if connected?(socket) && socket.assigns[:active_conversation] do
      Phoenix.PubSub.unsubscribe(
        FitTrackerz.PubSub,
        "messaging:conversation:#{socket.assigns.active_conversation.id}"
      )
    end

    if connected?(socket) do
      Phoenix.PubSub.subscribe(
        FitTrackerz.PubSub,
        "messaging:conversation:#{conversation.id}"
      )
    end

    messages = load_messages(conversation, actor)
    mark_conversation_read(conversation, actor)

    {:noreply,
     socket
     |> assign(
       active_conversation: conversation,
       active_messages: messages,
       message_body: "",
       show_new_direct: false,
       show_new_announcement: false
     )
     |> push_event("scroll_to_bottom", %{})}
  end

  defp open_conversation_noreply(socket, conversation, actor) do
    if socket.assigns[:active_conversation] do
      Phoenix.PubSub.unsubscribe(
        FitTrackerz.PubSub,
        "messaging:conversation:#{socket.assigns.active_conversation.id}"
      )
    end

    Phoenix.PubSub.subscribe(
      FitTrackerz.PubSub,
      "messaging:conversation:#{conversation.id}"
    )

    messages = load_messages(conversation, actor)
    mark_conversation_read(conversation, actor)

    socket
    |> assign(
      active_conversation: conversation,
      active_messages: messages,
      message_body: ""
    )
    |> push_event("scroll_to_bottom", %{})
  end

  defp load_gym(actor) do
    case Gym.list_gyms_by_owner(actor.id, actor: actor) do
      {:ok, [gym | _]} -> gym
      _ -> nil
    end
  end

  defp load_conversations(actor, :all) do
    case Messaging.list_conversations(actor.id, actor: actor) do
      {:ok, conversations} -> conversations
      _ -> []
    end
  end

  defp load_conversations(actor, :direct) do
    case Messaging.list_direct_conversations(actor.id, actor: actor) do
      {:ok, conversations} -> conversations
      _ -> []
    end
  end

  defp load_conversations(actor, :announcements) do
    case Messaging.list_announcements(actor.id, actor: actor) do
      {:ok, conversations} -> conversations
      _ -> []
    end
  end

  defp load_messages(conversation, actor) do
    case Messaging.list_messages(conversation.id, actor: actor) do
      {:ok, messages} -> messages
      _ -> []
    end
  end

  defp load_contacts(actor, gym) when not is_nil(gym) do
    members =
      case Gym.list_members_by_gym(gym.id, actor: actor) do
        {:ok, members} -> Enum.map(members, fn m -> %{id: m.user.id, name: m.user.name, role: :member} end)
        _ -> []
      end

    trainers =
      case Gym.list_trainers_by_gym(gym.id, actor: actor) do
        {:ok, trainers} -> Enum.map(trainers, fn t -> %{id: t.user.id, name: t.user.name, role: :trainer} end)
        _ -> []
      end

    (members ++ trainers)
    |> Enum.reject(&(&1.id == actor.id))
    |> Enum.uniq_by(& &1.id)
  end

  defp load_contacts(_actor, _gym), do: []

  defp add_announcement_recipients(conversation, gym, actor) do
    members =
      case Gym.list_members_by_gym(gym.id, actor: actor) do
        {:ok, members} -> members
        _ -> []
      end

    trainers =
      case Gym.list_trainers_by_gym(gym.id, actor: actor) do
        {:ok, trainers} -> trainers
        _ -> []
      end

    user_ids =
      (Enum.map(members, & &1.user_id) ++ Enum.map(trainers, & &1.user_id))
      |> Enum.uniq()
      |> Enum.reject(&(&1 == actor.id))

    Enum.each(user_ids, fn user_id ->
      Messaging.create_participant(
        %{conversation_id: conversation.id, user_id: user_id, role: :participant},
        actor: actor
      )
    end)

    :ok
  end

  defp mark_conversation_read(conversation, actor) do
    case Messaging.list_participants(conversation.id, actor: actor) do
      {:ok, participants} ->
        case Enum.find(participants, &(&1.user_id == actor.id)) do
          nil -> :ok
          participant -> Messaging.mark_participant_read(participant, actor: actor)
        end

      _ ->
        :ok
    end
  end

  defp broadcast_to_participants(conversation_id, sender, message) do
    system_actor = %{id: "system", is_system_actor: true}

    case Messaging.list_participants(conversation_id, actor: system_actor) do
      {:ok, participants} ->
        participants
        |> Enum.reject(&(&1.user_id == sender.id))
        |> Enum.each(fn p ->
          Phoenix.PubSub.broadcast(
            FitTrackerz.PubSub,
            "messaging:user:#{p.user_id}",
            message
          )
        end)

      _ ->
        :ok
    end
  end

  defp conversation_display_name(conversation, current_user_id) do
    case conversation.type do
      :announcement ->
        conversation.title || "Announcement"

      :direct ->
        case conversation.participants do
          participants when is_list(participants) ->
            other = Enum.find(participants, fn p -> p.user_id != current_user_id end)

            case other do
              %{user: %{name: name}} when not is_nil(name) -> name
              _ -> "Unknown"
            end

          _ ->
            "Direct Message"
        end
    end
  end

  defp last_message_preview(conversation) do
    case conversation.messages do
      messages when is_list(messages) and length(messages) > 0 ->
        msg = List.last(Enum.sort_by(messages, & &1.inserted_at))
        String.slice(msg.body, 0, 50) <> if(String.length(msg.body) > 50, do: "...", else: "")

      _ ->
        "No messages yet"
    end
  end

  defp last_message_time(conversation) do
    case conversation.messages do
      messages when is_list(messages) and length(messages) > 0 ->
        msg = List.last(Enum.sort_by(messages, & &1.inserted_at))
        format_relative_time(msg.inserted_at)

      _ ->
        ""
    end
  end

  defp unread_count(conversation, current_user_id) do
    participant =
      case conversation.participants do
        participants when is_list(participants) ->
          Enum.find(participants, &(&1.user_id == current_user_id))

        _ ->
          nil
      end

    last_read = participant && participant.last_read_at

    case conversation.messages do
      messages when is_list(messages) ->
        if last_read do
          Enum.count(messages, fn m ->
            DateTime.compare(m.inserted_at, last_read) == :gt and m.sender_id != current_user_id
          end)
        else
          Enum.count(messages, &(&1.sender_id != current_user_id))
        end

      _ ->
        0
    end
  end

  defp can_send_message?(conversation, current_user_id) do
    case conversation.type do
      :direct -> true
      :announcement -> conversation.created_by_id == current_user_id
    end
  end

  defp format_relative_time(datetime) do
    now = DateTime.utc_now()
    diff = DateTime.diff(now, datetime, :second)

    cond do
      diff < 60 -> "now"
      diff < 3600 -> "#{div(diff, 60)}m"
      diff < 86400 -> "#{div(diff, 3600)}h"
      diff < 604_800 -> "#{div(diff, 86400)}d"
      true -> Calendar.strftime(datetime, "%b %d")
    end
  end

  defp format_message_time(datetime) do
    Calendar.strftime(datetime, "%I:%M %p")
  end

  defp format_file_size(size) when size < 1024, do: "#{size} B"
  defp format_file_size(size) when size < 1_048_576, do: "#{Float.round(size / 1024, 1)} KB"
  defp format_file_size(size), do: "#{Float.round(size / 1_048_576, 1)} MB"

  defp is_image?(content_type), do: String.starts_with?(content_type || "", "image/")

  defp role_badge(:member), do: "badge-info"
  defp role_badge(:trainer), do: "badge-warning"
  defp role_badge(_), do: "badge-ghost"

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="flex flex-col h-[calc(100vh-8rem)]">
        <div class="flex items-center gap-3 mb-4">
          <Layouts.back_button />
          <div>
            <h1 class="text-2xl sm:text-3xl font-brand">Messages</h1>
            <p class="text-base-content/50 mt-0.5 text-sm">Chat with members and trainers.</p>
          </div>
        </div>

        <div class="flex flex-1 gap-4 min-h-0">
          <%!-- Left Panel: Conversation List --%>
          <div class="w-80 shrink-0 flex flex-col bg-base-200/50 rounded-xl border border-base-300/50">
            <%!-- Tabs --%>
            <div class="p-3 border-b border-base-300/50">
              <div class="tabs tabs-boxed tabs-sm">
                <button
                  phx-click="switch_tab"
                  phx-value-tab="all"
                  class={"tab #{if @tab == :all, do: "tab-active"}"}
                >
                  All
                </button>
                <button
                  phx-click="switch_tab"
                  phx-value-tab="direct"
                  class={"tab #{if @tab == :direct, do: "tab-active"}"}
                >
                  Direct
                </button>
                <button
                  phx-click="switch_tab"
                  phx-value-tab="announcements"
                  class={"tab #{if @tab == :announcements, do: "tab-active"}"}
                >
                  Announcements
                </button>
              </div>
            </div>

            <%!-- Action Buttons --%>
            <div class="p-3 border-b border-base-300/50 flex gap-2">
              <button phx-click="show_new_direct" class="btn btn-sm btn-primary flex-1 gap-1">
                <.icon name="hero-chat-bubble-left-right-mini" class="size-4" /> New Chat
              </button>
              <button phx-click="show_new_announcement" class="btn btn-sm btn-secondary flex-1 gap-1">
                <.icon name="hero-megaphone-mini" class="size-4" /> Announce
              </button>
            </div>

            <%!-- Conversation List --%>
            <div class="flex-1 overflow-y-auto" id="conversation-list">
              <%= if @conversations == [] do %>
                <div class="p-6 text-center text-base-content/40 text-sm">
                  No conversations yet
                </div>
              <% else %>
                <div
                  :for={conv <- @conversations}
                  id={"conv-#{conv.id}"}
                  phx-click="select_conversation"
                  phx-value-id={conv.id}
                  class={"flex items-center gap-3 p-3 cursor-pointer hover:bg-base-300/50 transition-colors border-b border-base-300/30 #{if @active_conversation && @active_conversation.id == conv.id, do: "bg-base-300/70"}"}
                >
                  <div class={"w-10 h-10 rounded-full flex items-center justify-center shrink-0 #{if conv.type == :announcement, do: "bg-secondary/15", else: "bg-primary/15"}"}>
                    <%= if conv.type == :announcement do %>
                      <.icon name="hero-megaphone-solid" class="size-5 text-secondary" />
                    <% else %>
                      <span class="text-sm font-bold text-primary">
                        {String.first(conversation_display_name(conv, @current_user.id))}
                      </span>
                    <% end %>
                  </div>
                  <div class="flex-1 min-w-0">
                    <div class="flex items-center justify-between">
                      <span class="font-semibold text-sm truncate">
                        {conversation_display_name(conv, @current_user.id)}
                      </span>
                      <span class="text-xs text-base-content/40 shrink-0">
                        {last_message_time(conv)}
                      </span>
                    </div>
                    <p class="text-xs text-base-content/50 truncate mt-0.5">
                      {last_message_preview(conv)}
                    </p>
                  </div>
                  <% count = unread_count(conv, @current_user.id) %>
                  <%= if count > 0 do %>
                    <span class="badge badge-primary badge-xs">{count}</span>
                  <% end %>
                </div>
              <% end %>
            </div>
          </div>

          <%!-- Right Panel: Active Conversation / New Forms --%>
          <div class="flex-1 flex flex-col bg-base-200/30 rounded-xl border border-base-300/50">
            <%= cond do %>
              <% @show_new_direct -> %>
                <%!-- New Direct Message Form --%>
                <div class="p-4 border-b border-base-300/50 flex items-center justify-between">
                  <h2 class="font-bold">New Conversation</h2>
                  <button phx-click="cancel_new" class="btn btn-ghost btn-sm btn-circle">
                    <.icon name="hero-x-mark-mini" class="size-5" />
                  </button>
                </div>
                <div class="flex-1 overflow-y-auto p-4">
                  <p class="text-sm text-base-content/50 mb-3">Select a person to message:</p>
                  <%= if @contacts == [] do %>
                    <p class="text-center text-base-content/40 text-sm py-8">No contacts found in your gym.</p>
                  <% else %>
                    <div class="space-y-2">
                      <div
                        :for={contact <- @contacts}
                        phx-click="start_direct"
                        phx-value-user_id={contact.id}
                        class="flex items-center gap-3 p-3 rounded-lg cursor-pointer hover:bg-base-300/50 transition-colors"
                      >
                        <div class="w-9 h-9 rounded-full bg-primary/15 flex items-center justify-center">
                          <span class="text-sm font-bold text-primary">{String.first(contact.name)}</span>
                        </div>
                        <div class="flex-1">
                          <span class="font-medium text-sm">{contact.name}</span>
                        </div>
                        <span class={"badge badge-sm #{role_badge(contact.role)}"}>{contact.role}</span>
                      </div>
                    </div>
                  <% end %>
                </div>

              <% @show_new_announcement -> %>
                <%!-- New Announcement Form --%>
                <div class="p-4 border-b border-base-300/50 flex items-center justify-between">
                  <h2 class="font-bold">New Announcement</h2>
                  <button phx-click="cancel_new" class="btn btn-ghost btn-sm btn-circle">
                    <.icon name="hero-x-mark-mini" class="size-5" />
                  </button>
                </div>
                <div class="flex-1 p-4">
                  <form phx-submit="create_announcement" class="space-y-4">
                    <div class="form-control">
                      <label class="label"><span class="label-text font-medium">Title</span></label>
                      <input
                        type="text"
                        name="title"
                        class="input input-bordered"
                        placeholder="e.g., Gym closed Monday"
                        required
                      />
                    </div>
                    <div class="form-control">
                      <label class="label"><span class="label-text font-medium">Message</span></label>
                      <textarea
                        name="body"
                        class="textarea textarea-bordered h-32"
                        placeholder="Write your announcement..."
                        required
                      ></textarea>
                    </div>
                    <p class="text-xs text-base-content/40">
                      This will be sent to all members and trainers of your gym.
                    </p>
                    <button type="submit" class="btn btn-secondary gap-2">
                      <.icon name="hero-megaphone-mini" class="size-4" /> Send Announcement
                    </button>
                  </form>
                </div>

              <% @active_conversation != nil -> %>
                <%!-- Active Conversation --%>
                <div class="p-4 border-b border-base-300/50 flex items-center gap-3">
                  <div class={"w-10 h-10 rounded-full flex items-center justify-center #{if @active_conversation.type == :announcement, do: "bg-secondary/15", else: "bg-primary/15"}"}>
                    <%= if @active_conversation.type == :announcement do %>
                      <.icon name="hero-megaphone-solid" class="size-5 text-secondary" />
                    <% else %>
                      <span class="text-sm font-bold text-primary">
                        {String.first(conversation_display_name(@active_conversation, @current_user.id))}
                      </span>
                    <% end %>
                  </div>
                  <div>
                    <h2 class="font-bold text-sm">
                      {conversation_display_name(@active_conversation, @current_user.id)}
                    </h2>
                    <%= if @active_conversation.type == :announcement do %>
                      <span class="text-xs text-base-content/40">Announcement</span>
                    <% end %>
                  </div>
                </div>

                <%!-- Messages --%>
                <div class="flex-1 overflow-y-auto p-4 space-y-3" id="message-list" phx-hook="ScrollToBottom">
                  <%= if @active_messages == [] do %>
                    <div class="text-center text-base-content/40 text-sm py-8">
                      No messages yet. Start the conversation!
                    </div>
                  <% else %>
                    <div
                      :for={msg <- @active_messages}
                      id={"msg-#{msg.id}"}
                      class={"flex #{if msg.sender_id == @current_user.id, do: "justify-end", else: "justify-start"}"}
                    >
                      <div class={"max-w-[70%] #{if msg.sender_id == @current_user.id, do: "bg-primary text-primary-content", else: "bg-base-300"} rounded-2xl px-4 py-2.5"}>
                        <%= if msg.sender_id != @current_user.id do %>
                          <p class="text-xs font-semibold opacity-70 mb-1">
                            {if msg.sender, do: msg.sender.name, else: "Unknown"}
                          </p>
                        <% end %>
                        <p class="text-sm whitespace-pre-wrap">{msg.body}</p>
                        <%!-- Attachments --%>
                        <%= if msg.attachments != [] do %>
                          <div class="mt-2 space-y-1">
                            <div :for={att <- msg.attachments}>
                              <%= if is_image?(att["content_type"]) do %>
                                <img src={att["url"]} alt={att["filename"]} class="rounded-lg max-w-full max-h-48 mt-1" />
                              <% else %>
                                <a
                                  href={att["url"]}
                                  target="_blank"
                                  class={"flex items-center gap-2 text-xs underline #{if msg.sender_id == @current_user.id, do: "text-primary-content/80", else: "text-base-content/60"}"}
                                >
                                  <.icon name="hero-paper-clip-mini" class="size-3" />
                                  {att["filename"]} ({format_file_size(att["size"])})
                                </a>
                              <% end %>
                            </div>
                          </div>
                        <% end %>
                        <p class={"text-[10px] mt-1 #{if msg.sender_id == @current_user.id, do: "text-primary-content/50", else: "text-base-content/30"}"}>
                          {format_message_time(msg.inserted_at)}
                        </p>
                      </div>
                    </div>
                  <% end %>
                </div>

                <%!-- Message Input --%>
                <%= if can_send_message?(@active_conversation, @current_user.id) do %>
                  <div class="p-3 border-t border-base-300/50">
                    <%!-- Upload previews --%>
                    <%= if @uploads.attachments.entries != [] do %>
                      <div class="flex flex-wrap gap-2 mb-2">
                        <div
                          :for={entry <- @uploads.attachments.entries}
                          class="flex items-center gap-1 bg-base-300 rounded-lg px-2 py-1 text-xs"
                        >
                          <span class="truncate max-w-[120px]">{entry.client_name}</span>
                          <button
                            type="button"
                            phx-click="cancel_upload"
                            phx-value-ref={entry.ref}
                            class="btn btn-ghost btn-xs btn-circle"
                          >
                            <.icon name="hero-x-mark-mini" class="size-3" />
                          </button>
                        </div>
                      </div>
                    <% end %>

                    <form phx-submit="send_message" phx-change="update_body" class="flex items-end gap-2">
                      <label class="btn btn-ghost btn-sm btn-circle cursor-pointer shrink-0">
                        <.icon name="hero-paper-clip" class="size-5" />
                        <.live_file_input upload={@uploads.attachments} class="hidden" />
                      </label>
                      <textarea
                        name="body"
                        value={@message_body}
                        class="textarea textarea-bordered flex-1 min-h-[2.5rem] max-h-32 resize-none text-sm"
                        placeholder="Type a message..."
                        rows="1"
                        phx-hook="AutoResize"
                        id="message-input"
                      ></textarea>
                      <button type="submit" class="btn btn-primary btn-sm btn-circle shrink-0">
                        <.icon name="hero-paper-airplane-mini" class="size-4" />
                      </button>
                    </form>
                  </div>
                <% else %>
                  <div class="p-3 border-t border-base-300/50 text-center text-sm text-base-content/40">
                    This is a read-only announcement.
                  </div>
                <% end %>

              <% true -> %>
                <%!-- Empty State --%>
                <div class="flex-1 flex items-center justify-center">
                  <div class="text-center">
                    <div class="w-16 h-16 rounded-2xl bg-base-300/30 flex items-center justify-center mx-auto mb-4">
                      <.icon name="hero-chat-bubble-left-right" class="size-8 text-base-content/20" />
                    </div>
                    <h2 class="text-lg font-bold text-base-content/50">Select a conversation</h2>
                    <p class="text-sm text-base-content/30 mt-1">Or start a new one</p>
                  </div>
                </div>
            <% end %>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
```

- [ ] **Step 2: Verify compilation**

```bash
mix compile --warnings-as-errors
```

---

### Task 6: Trainer MessagesLive

**Files:**
- Create: `lib/fit_trackerz_web/live/trainer/messages_live.ex`

- [ ] **Step 1: Create Trainer MessagesLive**

Same structure as Operator MessagesLive but with these differences:
- `load_gym/1` — loads gym via trainer's `GymTrainer` records instead of ownership
- `load_contacts/2` — only loads assigned clients (via `list_members_by_trainer`) plus the gym operator
- `add_announcement_recipients/3` — only adds assigned clients, not all gym members
- Announcement description text: "This will be sent to all your assigned clients."

```elixir
# lib/fit_trackerz_web/live/trainer/messages_live.ex
defmodule FitTrackerzWeb.Trainer.MessagesLive do
  use FitTrackerzWeb, :live_view

  alias FitTrackerz.Messaging
  alias FitTrackerz.Gym

  @impl true
  def mount(_params, _session, socket) do
    actor = socket.assigns.current_user

    if connected?(socket) do
      Phoenix.PubSub.subscribe(FitTrackerz.PubSub, "messaging:user:#{actor.id}")
    end

    {gym, gym_trainer} = load_gym_and_trainer(actor)
    conversations = load_conversations(actor, :all)

    {:ok,
     socket
     |> assign(
       page_title: "Messages",
       gym: gym,
       gym_trainer: gym_trainer,
       conversations: conversations,
       active_conversation: nil,
       active_messages: [],
       message_body: "",
       tab: :all,
       show_new_direct: false,
       show_new_announcement: false,
       contacts: [],
       announcement_title: ""
     )
     |> allow_upload(:attachments,
       accept: :any,
       max_entries: 5,
       max_file_size: 10_000_000
     )}
  end

  @impl true
  def handle_params(%{"conversation_id" => id}, _uri, socket) do
    actor = socket.assigns.current_user

    case Messaging.get_conversation(id, actor: actor) do
      {:ok, conversation} -> open_conversation(socket, conversation, actor)
      _ -> {:noreply, put_flash(socket, :error, "Conversation not found.")}
    end
  end

  def handle_params(_params, _uri, socket), do: {:noreply, socket}

  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    tab = String.to_existing_atom(tab)
    conversations = load_conversations(socket.assigns.current_user, tab)
    {:noreply, assign(socket, tab: tab, conversations: conversations)}
  end

  def handle_event("select_conversation", %{"id" => id}, socket) do
    actor = socket.assigns.current_user

    case Messaging.get_conversation(id, actor: actor) do
      {:ok, conversation} -> open_conversation(socket, conversation, actor)
      _ -> {:noreply, put_flash(socket, :error, "Conversation not found.")}
    end
  end

  def handle_event("show_new_direct", _params, socket) do
    actor = socket.assigns.current_user
    contacts = load_contacts(actor, socket.assigns.gym, socket.assigns.gym_trainer)
    {:noreply, assign(socket, show_new_direct: true, show_new_announcement: false, contacts: contacts)}
  end

  def handle_event("show_new_announcement", _params, socket) do
    {:noreply, assign(socket, show_new_announcement: true, show_new_direct: false)}
  end

  def handle_event("cancel_new", _params, socket) do
    {:noreply, assign(socket, show_new_direct: false, show_new_announcement: false)}
  end

  def handle_event("start_direct", %{"user_id" => user_id}, socket) do
    actor = socket.assigns.current_user
    gym = socket.assigns.gym

    case Messaging.find_direct_conversation(actor.id, user_id, gym.id, actor: actor) do
      {:ok, [existing | _]} ->
        {:noreply,
         socket
         |> assign(show_new_direct: false)
         |> open_conversation_noreply(existing, actor)}

      _ ->
        with {:ok, conversation} <-
               Messaging.create_conversation(
                 %{type: :direct, gym_id: gym.id, created_by_id: actor.id},
                 actor: actor
               ),
             {:ok, _} <-
               Messaging.create_participant(
                 %{conversation_id: conversation.id, user_id: actor.id, role: :owner},
                 actor: actor
               ),
             {:ok, _} <-
               Messaging.create_participant(
                 %{conversation_id: conversation.id, user_id: user_id, role: :participant},
                 actor: actor
               ) do
          Phoenix.PubSub.broadcast(
            FitTrackerz.PubSub,
            "messaging:user:#{user_id}",
            {:new_conversation, %{conversation_id: conversation.id}}
          )

          conversations = load_conversations(actor, socket.assigns.tab)
          {:ok, conversation} = Messaging.get_conversation(conversation.id, actor: actor)

          {:noreply,
           socket
           |> assign(show_new_direct: false, conversations: conversations)
           |> open_conversation_noreply(conversation, actor)}
        else
          _ -> {:noreply, put_flash(socket, :error, "Failed to create conversation.")}
        end
    end
  end

  def handle_event("create_announcement", %{"title" => title, "body" => body}, socket) do
    actor = socket.assigns.current_user
    gym = socket.assigns.gym
    gym_trainer = socket.assigns.gym_trainer

    with {:ok, conversation} <-
           Messaging.create_conversation(
             %{type: :announcement, title: title, gym_id: gym.id, created_by_id: actor.id},
             actor: actor
           ),
         {:ok, _} <-
           Messaging.create_participant(
             %{conversation_id: conversation.id, user_id: actor.id, role: :owner},
             actor: actor
           ),
         :ok <- add_announcement_recipients(conversation, gym_trainer, actor),
         {:ok, _} <-
           Messaging.create_message(
             %{body: body, conversation_id: conversation.id, sender_id: actor.id},
             actor: actor
           ) do
      broadcast_to_participants(conversation.id, actor, {:new_conversation, %{conversation_id: conversation.id}})
      conversations = load_conversations(actor, socket.assigns.tab)
      {:ok, conversation} = Messaging.get_conversation(conversation.id, actor: actor)

      {:noreply,
       socket
       |> assign(show_new_announcement: false, conversations: conversations)
       |> put_flash(:info, "Announcement sent!")
       |> open_conversation_noreply(conversation, actor)}
    else
      _ -> {:noreply, put_flash(socket, :error, "Failed to create announcement.")}
    end
  end

  def handle_event("send_message", %{"body" => body}, socket) when byte_size(body) > 0 do
    actor = socket.assigns.current_user
    conversation = socket.assigns.active_conversation

    attachment_data =
      consume_uploaded_entries(socket, :attachments, fn %{path: path}, entry ->
        dest_dir = Path.join(["priv/static/uploads/messages", conversation.id])
        File.mkdir_p!(dest_dir)
        filename = "#{Ecto.UUID.generate()}-#{entry.client_name}"
        dest = Path.join(dest_dir, filename)
        File.cp!(path, dest)

        {:ok,
         %{
           "filename" => entry.client_name,
           "url" => "/uploads/messages/#{conversation.id}/#{filename}",
           "content_type" => entry.client_type,
           "size" => entry.client_size
         }}
      end)

    case Messaging.create_message(
           %{body: body, conversation_id: conversation.id, sender_id: actor.id, attachments: attachment_data},
           actor: actor
         ) do
      {:ok, message} ->
        Messaging.touch_conversation(conversation, actor: actor)
        message = %{message | sender: actor}

        Phoenix.PubSub.broadcast(
          FitTrackerz.PubSub,
          "messaging:conversation:#{conversation.id}",
          {:new_message, message}
        )

        broadcast_to_participants(conversation.id, actor, {:conversation_updated, %{conversation_id: conversation.id}})

        {:noreply,
         socket
         |> assign(message_body: "")
         |> update(:active_messages, &(&1 ++ [message]))
         |> push_event("scroll_to_bottom", %{})}

      _ ->
        {:noreply, put_flash(socket, :error, "Failed to send message.")}
    end
  end

  def handle_event("send_message", _params, socket), do: {:noreply, socket}

  def handle_event("update_body", %{"body" => body}, socket) do
    {:noreply, assign(socket, message_body: body)}
  end

  def handle_event("cancel_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :attachments, ref)}
  end

  @impl true
  def handle_info({:new_message, message}, socket) do
    if socket.assigns.active_conversation &&
         socket.assigns.active_conversation.id == message.conversation_id &&
         message.sender_id != socket.assigns.current_user.id do
      mark_conversation_read(socket.assigns.active_conversation, socket.assigns.current_user)

      {:noreply,
       socket
       |> update(:active_messages, &(&1 ++ [message]))
       |> push_event("scroll_to_bottom", %{})}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:new_conversation, _}, socket) do
    conversations = load_conversations(socket.assigns.current_user, socket.assigns.tab)
    {:noreply, assign(socket, conversations: conversations)}
  end

  def handle_info({:conversation_updated, _}, socket) do
    conversations = load_conversations(socket.assigns.current_user, socket.assigns.tab)
    {:noreply, assign(socket, conversations: conversations)}
  end

  # Private helpers

  defp open_conversation(socket, conversation, actor) do
    if connected?(socket) && socket.assigns[:active_conversation] do
      Phoenix.PubSub.unsubscribe(FitTrackerz.PubSub, "messaging:conversation:#{socket.assigns.active_conversation.id}")
    end

    if connected?(socket) do
      Phoenix.PubSub.subscribe(FitTrackerz.PubSub, "messaging:conversation:#{conversation.id}")
    end

    messages = load_messages(conversation, actor)
    mark_conversation_read(conversation, actor)

    {:noreply,
     socket
     |> assign(active_conversation: conversation, active_messages: messages, message_body: "", show_new_direct: false, show_new_announcement: false)
     |> push_event("scroll_to_bottom", %{})}
  end

  defp open_conversation_noreply(socket, conversation, actor) do
    if socket.assigns[:active_conversation] do
      Phoenix.PubSub.unsubscribe(FitTrackerz.PubSub, "messaging:conversation:#{socket.assigns.active_conversation.id}")
    end

    Phoenix.PubSub.subscribe(FitTrackerz.PubSub, "messaging:conversation:#{conversation.id}")

    messages = load_messages(conversation, actor)
    mark_conversation_read(conversation, actor)

    socket
    |> assign(active_conversation: conversation, active_messages: messages, message_body: "")
    |> push_event("scroll_to_bottom", %{})
  end

  defp load_gym_and_trainer(actor) do
    case Gym.list_active_trainerships(actor.id, actor: actor) do
      {:ok, [gt | _]} ->
        case Gym.get_gym(gt.gym_id, actor: actor) do
          {:ok, gym} -> {gym, gt}
          _ -> {nil, gt}
        end

      _ ->
        {nil, nil}
    end
  end

  defp load_conversations(actor, :all) do
    case Messaging.list_conversations(actor.id, actor: actor) do
      {:ok, convs} -> convs
      _ -> []
    end
  end

  defp load_conversations(actor, :direct) do
    case Messaging.list_direct_conversations(actor.id, actor: actor) do
      {:ok, convs} -> convs
      _ -> []
    end
  end

  defp load_conversations(actor, :announcements) do
    case Messaging.list_announcements(actor.id, actor: actor) do
      {:ok, convs} -> convs
      _ -> []
    end
  end

  defp load_messages(conversation, actor) do
    case Messaging.list_messages(conversation.id, actor: actor) do
      {:ok, messages} -> messages
      _ -> []
    end
  end

  defp load_contacts(actor, gym, gym_trainer) when not is_nil(gym) and not is_nil(gym_trainer) do
    # Trainer can message: assigned clients + gym operator
    clients =
      case Gym.list_members_by_trainer([gym_trainer.id], actor: actor) do
        {:ok, members} -> Enum.map(members, fn m -> %{id: m.user.id, name: m.user.name, role: :member} end)
        _ -> []
      end

    # Add gym owner
    operator =
      if gym.owner_id != actor.id do
        case FitTrackerz.Accounts.get_user(gym.owner_id, actor: actor) do
          {:ok, user} -> [%{id: user.id, name: user.name, role: :gym_operator}]
          _ -> []
        end
      else
        []
      end

    (clients ++ operator) |> Enum.uniq_by(& &1.id)
  end

  defp load_contacts(_actor, _gym, _trainer), do: []

  defp add_announcement_recipients(conversation, gym_trainer, actor) when not is_nil(gym_trainer) do
    case Gym.list_members_by_trainer([gym_trainer.id], actor: actor) do
      {:ok, members} ->
        Enum.each(members, fn m ->
          Messaging.create_participant(
            %{conversation_id: conversation.id, user_id: m.user_id, role: :participant},
            actor: actor
          )
        end)

        :ok

      _ ->
        :ok
    end
  end

  defp add_announcement_recipients(_conversation, _gym_trainer, _actor), do: :ok

  defp mark_conversation_read(conversation, actor) do
    case Messaging.list_participants(conversation.id, actor: actor) do
      {:ok, participants} ->
        case Enum.find(participants, &(&1.user_id == actor.id)) do
          nil -> :ok
          participant -> Messaging.mark_participant_read(participant, actor: actor)
        end

      _ ->
        :ok
    end
  end

  defp broadcast_to_participants(conversation_id, sender, message) do
    system_actor = %{id: "system", is_system_actor: true}

    case Messaging.list_participants(conversation_id, actor: system_actor) do
      {:ok, participants} ->
        participants
        |> Enum.reject(&(&1.user_id == sender.id))
        |> Enum.each(fn p ->
          Phoenix.PubSub.broadcast(FitTrackerz.PubSub, "messaging:user:#{p.user_id}", message)
        end)

      _ ->
        :ok
    end
  end

  defp conversation_display_name(conversation, current_user_id) do
    case conversation.type do
      :announcement -> conversation.title || "Announcement"
      :direct ->
        case conversation.participants do
          participants when is_list(participants) ->
            other = Enum.find(participants, fn p -> p.user_id != current_user_id end)
            case other do
              %{user: %{name: name}} when not is_nil(name) -> name
              _ -> "Unknown"
            end
          _ -> "Direct Message"
        end
    end
  end

  defp last_message_preview(conversation) do
    case conversation.messages do
      messages when is_list(messages) and length(messages) > 0 ->
        msg = List.last(Enum.sort_by(messages, & &1.inserted_at))
        String.slice(msg.body, 0, 50) <> if(String.length(msg.body) > 50, do: "...", else: "")
      _ -> "No messages yet"
    end
  end

  defp last_message_time(conversation) do
    case conversation.messages do
      messages when is_list(messages) and length(messages) > 0 ->
        msg = List.last(Enum.sort_by(messages, & &1.inserted_at))
        format_relative_time(msg.inserted_at)
      _ -> ""
    end
  end

  defp unread_count(conversation, current_user_id) do
    participant =
      case conversation.participants do
        ps when is_list(ps) -> Enum.find(ps, &(&1.user_id == current_user_id))
        _ -> nil
      end

    last_read = participant && participant.last_read_at

    case conversation.messages do
      messages when is_list(messages) ->
        if last_read do
          Enum.count(messages, fn m -> DateTime.compare(m.inserted_at, last_read) == :gt and m.sender_id != current_user_id end)
        else
          Enum.count(messages, &(&1.sender_id != current_user_id))
        end
      _ -> 0
    end
  end

  defp can_send_message?(conversation, current_user_id) do
    case conversation.type do
      :direct -> true
      :announcement -> conversation.created_by_id == current_user_id
    end
  end

  defp format_relative_time(datetime) do
    diff = DateTime.diff(DateTime.utc_now(), datetime, :second)
    cond do
      diff < 60 -> "now"
      diff < 3600 -> "#{div(diff, 60)}m"
      diff < 86400 -> "#{div(diff, 3600)}h"
      diff < 604_800 -> "#{div(diff, 86400)}d"
      true -> Calendar.strftime(datetime, "%b %d")
    end
  end

  defp format_message_time(datetime), do: Calendar.strftime(datetime, "%I:%M %p")

  defp format_file_size(size) when size < 1024, do: "#{size} B"
  defp format_file_size(size) when size < 1_048_576, do: "#{Float.round(size / 1024, 1)} KB"
  defp format_file_size(size), do: "#{Float.round(size / 1_048_576, 1)} MB"

  defp is_image?(ct), do: String.starts_with?(ct || "", "image/")

  defp role_badge(:member), do: "badge-info"
  defp role_badge(:gym_operator), do: "badge-accent"
  defp role_badge(_), do: "badge-ghost"

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="flex flex-col h-[calc(100vh-8rem)]">
        <div class="flex items-center gap-3 mb-4">
          <Layouts.back_button />
          <div>
            <h1 class="text-2xl sm:text-3xl font-brand">Messages</h1>
            <p class="text-base-content/50 mt-0.5 text-sm">Chat with your clients and gym operator.</p>
          </div>
        </div>

        <div class="flex flex-1 gap-4 min-h-0">
          <%!-- Left Panel --%>
          <div class="w-80 shrink-0 flex flex-col bg-base-200/50 rounded-xl border border-base-300/50">
            <div class="p-3 border-b border-base-300/50">
              <div class="tabs tabs-boxed tabs-sm">
                <button phx-click="switch_tab" phx-value-tab="all" class={"tab #{if @tab == :all, do: "tab-active"}"}>All</button>
                <button phx-click="switch_tab" phx-value-tab="direct" class={"tab #{if @tab == :direct, do: "tab-active"}"}>Direct</button>
                <button phx-click="switch_tab" phx-value-tab="announcements" class={"tab #{if @tab == :announcements, do: "tab-active"}"}>Announcements</button>
              </div>
            </div>

            <div class="p-3 border-b border-base-300/50 flex gap-2">
              <button phx-click="show_new_direct" class="btn btn-sm btn-primary flex-1 gap-1">
                <.icon name="hero-chat-bubble-left-right-mini" class="size-4" /> New Chat
              </button>
              <button phx-click="show_new_announcement" class="btn btn-sm btn-secondary flex-1 gap-1">
                <.icon name="hero-megaphone-mini" class="size-4" /> Announce
              </button>
            </div>

            <div class="flex-1 overflow-y-auto" id="conversation-list">
              <%= if @conversations == [] do %>
                <div class="p-6 text-center text-base-content/40 text-sm">No conversations yet</div>
              <% else %>
                <div
                  :for={conv <- @conversations}
                  id={"conv-#{conv.id}"}
                  phx-click="select_conversation"
                  phx-value-id={conv.id}
                  class={"flex items-center gap-3 p-3 cursor-pointer hover:bg-base-300/50 transition-colors border-b border-base-300/30 #{if @active_conversation && @active_conversation.id == conv.id, do: "bg-base-300/70"}"}
                >
                  <div class={"w-10 h-10 rounded-full flex items-center justify-center shrink-0 #{if conv.type == :announcement, do: "bg-secondary/15", else: "bg-primary/15"}"}>
                    <%= if conv.type == :announcement do %>
                      <.icon name="hero-megaphone-solid" class="size-5 text-secondary" />
                    <% else %>
                      <span class="text-sm font-bold text-primary">{String.first(conversation_display_name(conv, @current_user.id))}</span>
                    <% end %>
                  </div>
                  <div class="flex-1 min-w-0">
                    <div class="flex items-center justify-between">
                      <span class="font-semibold text-sm truncate">{conversation_display_name(conv, @current_user.id)}</span>
                      <span class="text-xs text-base-content/40 shrink-0">{last_message_time(conv)}</span>
                    </div>
                    <p class="text-xs text-base-content/50 truncate mt-0.5">{last_message_preview(conv)}</p>
                  </div>
                  <% count = unread_count(conv, @current_user.id) %>
                  <%= if count > 0 do %>
                    <span class="badge badge-primary badge-xs">{count}</span>
                  <% end %>
                </div>
              <% end %>
            </div>
          </div>

          <%!-- Right Panel --%>
          <div class="flex-1 flex flex-col bg-base-200/30 rounded-xl border border-base-300/50">
            <%= cond do %>
              <% @show_new_direct -> %>
                <div class="p-4 border-b border-base-300/50 flex items-center justify-between">
                  <h2 class="font-bold">New Conversation</h2>
                  <button phx-click="cancel_new" class="btn btn-ghost btn-sm btn-circle"><.icon name="hero-x-mark-mini" class="size-5" /></button>
                </div>
                <div class="flex-1 overflow-y-auto p-4">
                  <p class="text-sm text-base-content/50 mb-3">Select a person to message:</p>
                  <%= if @contacts == [] do %>
                    <p class="text-center text-base-content/40 text-sm py-8">No contacts available.</p>
                  <% else %>
                    <div class="space-y-2">
                      <div :for={contact <- @contacts} phx-click="start_direct" phx-value-user_id={contact.id} class="flex items-center gap-3 p-3 rounded-lg cursor-pointer hover:bg-base-300/50 transition-colors">
                        <div class="w-9 h-9 rounded-full bg-primary/15 flex items-center justify-center">
                          <span class="text-sm font-bold text-primary">{String.first(contact.name)}</span>
                        </div>
                        <div class="flex-1"><span class="font-medium text-sm">{contact.name}</span></div>
                        <span class={"badge badge-sm #{role_badge(contact.role)}"}>{contact.role}</span>
                      </div>
                    </div>
                  <% end %>
                </div>

              <% @show_new_announcement -> %>
                <div class="p-4 border-b border-base-300/50 flex items-center justify-between">
                  <h2 class="font-bold">New Announcement</h2>
                  <button phx-click="cancel_new" class="btn btn-ghost btn-sm btn-circle"><.icon name="hero-x-mark-mini" class="size-5" /></button>
                </div>
                <div class="flex-1 p-4">
                  <form phx-submit="create_announcement" class="space-y-4">
                    <div class="form-control">
                      <label class="label"><span class="label-text font-medium">Title</span></label>
                      <input type="text" name="title" class="input input-bordered" placeholder="e.g., Schedule change" required />
                    </div>
                    <div class="form-control">
                      <label class="label"><span class="label-text font-medium">Message</span></label>
                      <textarea name="body" class="textarea textarea-bordered h-32" placeholder="Write your announcement..." required></textarea>
                    </div>
                    <p class="text-xs text-base-content/40">This will be sent to all your assigned clients.</p>
                    <button type="submit" class="btn btn-secondary gap-2"><.icon name="hero-megaphone-mini" class="size-4" /> Send Announcement</button>
                  </form>
                </div>

              <% @active_conversation != nil -> %>
                <div class="p-4 border-b border-base-300/50 flex items-center gap-3">
                  <div class={"w-10 h-10 rounded-full flex items-center justify-center #{if @active_conversation.type == :announcement, do: "bg-secondary/15", else: "bg-primary/15"}"}>
                    <%= if @active_conversation.type == :announcement do %>
                      <.icon name="hero-megaphone-solid" class="size-5 text-secondary" />
                    <% else %>
                      <span class="text-sm font-bold text-primary">{String.first(conversation_display_name(@active_conversation, @current_user.id))}</span>
                    <% end %>
                  </div>
                  <div>
                    <h2 class="font-bold text-sm">{conversation_display_name(@active_conversation, @current_user.id)}</h2>
                    <%= if @active_conversation.type == :announcement do %>
                      <span class="text-xs text-base-content/40">Announcement</span>
                    <% end %>
                  </div>
                </div>

                <div class="flex-1 overflow-y-auto p-4 space-y-3" id="message-list" phx-hook="ScrollToBottom">
                  <%= if @active_messages == [] do %>
                    <div class="text-center text-base-content/40 text-sm py-8">No messages yet. Start the conversation!</div>
                  <% else %>
                    <div :for={msg <- @active_messages} id={"msg-#{msg.id}"} class={"flex #{if msg.sender_id == @current_user.id, do: "justify-end", else: "justify-start"}"}>
                      <div class={"max-w-[70%] #{if msg.sender_id == @current_user.id, do: "bg-primary text-primary-content", else: "bg-base-300"} rounded-2xl px-4 py-2.5"}>
                        <%= if msg.sender_id != @current_user.id do %>
                          <p class="text-xs font-semibold opacity-70 mb-1">{if msg.sender, do: msg.sender.name, else: "Unknown"}</p>
                        <% end %>
                        <p class="text-sm whitespace-pre-wrap">{msg.body}</p>
                        <%= if msg.attachments != [] do %>
                          <div class="mt-2 space-y-1">
                            <div :for={att <- msg.attachments}>
                              <%= if is_image?(att["content_type"]) do %>
                                <img src={att["url"]} alt={att["filename"]} class="rounded-lg max-w-full max-h-48 mt-1" />
                              <% else %>
                                <a href={att["url"]} target="_blank" class={"flex items-center gap-2 text-xs underline #{if msg.sender_id == @current_user.id, do: "text-primary-content/80", else: "text-base-content/60"}"}>
                                  <.icon name="hero-paper-clip-mini" class="size-3" /> {att["filename"]} ({format_file_size(att["size"])})
                                </a>
                              <% end %>
                            </div>
                          </div>
                        <% end %>
                        <p class={"text-[10px] mt-1 #{if msg.sender_id == @current_user.id, do: "text-primary-content/50", else: "text-base-content/30"}"}>{format_message_time(msg.inserted_at)}</p>
                      </div>
                    </div>
                  <% end %>
                </div>

                <%= if can_send_message?(@active_conversation, @current_user.id) do %>
                  <div class="p-3 border-t border-base-300/50">
                    <%= if @uploads.attachments.entries != [] do %>
                      <div class="flex flex-wrap gap-2 mb-2">
                        <div :for={entry <- @uploads.attachments.entries} class="flex items-center gap-1 bg-base-300 rounded-lg px-2 py-1 text-xs">
                          <span class="truncate max-w-[120px]">{entry.client_name}</span>
                          <button type="button" phx-click="cancel_upload" phx-value-ref={entry.ref} class="btn btn-ghost btn-xs btn-circle"><.icon name="hero-x-mark-mini" class="size-3" /></button>
                        </div>
                      </div>
                    <% end %>
                    <form phx-submit="send_message" phx-change="update_body" class="flex items-end gap-2">
                      <label class="btn btn-ghost btn-sm btn-circle cursor-pointer shrink-0">
                        <.icon name="hero-paper-clip" class="size-5" />
                        <.live_file_input upload={@uploads.attachments} class="hidden" />
                      </label>
                      <textarea name="body" value={@message_body} class="textarea textarea-bordered flex-1 min-h-[2.5rem] max-h-32 resize-none text-sm" placeholder="Type a message..." rows="1" phx-hook="AutoResize" id="message-input"></textarea>
                      <button type="submit" class="btn btn-primary btn-sm btn-circle shrink-0"><.icon name="hero-paper-airplane-mini" class="size-4" /></button>
                    </form>
                  </div>
                <% else %>
                  <div class="p-3 border-t border-base-300/50 text-center text-sm text-base-content/40">This is a read-only announcement.</div>
                <% end %>

              <% true -> %>
                <div class="flex-1 flex items-center justify-center">
                  <div class="text-center">
                    <div class="w-16 h-16 rounded-2xl bg-base-300/30 flex items-center justify-center mx-auto mb-4">
                      <.icon name="hero-chat-bubble-left-right" class="size-8 text-base-content/20" />
                    </div>
                    <h2 class="text-lg font-bold text-base-content/50">Select a conversation</h2>
                    <p class="text-sm text-base-content/30 mt-1">Or start a new one</p>
                  </div>
                </div>
            <% end %>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
```

- [ ] **Step 2: Verify compilation**

```bash
mix compile --warnings-as-errors
```

---

### Task 7: Member MessagesLive

**Files:**
- Create: `lib/fit_trackerz_web/live/member/messages_live.ex`

- [ ] **Step 1: Create Member MessagesLive**

Same structure but with member-specific differences:
- No "New Announcement" button (members cannot create announcements)
- `load_gym/1` — loads gym via member's `GymMember` records
- `load_contacts/2` — loads assigned trainer + gym operator only
- No `add_announcement_recipients` needed

```elixir
# lib/fit_trackerz_web/live/member/messages_live.ex
defmodule FitTrackerzWeb.Member.MessagesLive do
  use FitTrackerzWeb, :live_view

  alias FitTrackerz.Messaging
  alias FitTrackerz.Gym

  @impl true
  def mount(_params, _session, socket) do
    actor = socket.assigns.current_user

    if connected?(socket) do
      Phoenix.PubSub.subscribe(FitTrackerz.PubSub, "messaging:user:#{actor.id}")
    end

    gym = load_gym(actor)
    conversations = load_conversations(actor, :all)

    {:ok,
     socket
     |> assign(
       page_title: "Messages",
       gym: gym,
       conversations: conversations,
       active_conversation: nil,
       active_messages: [],
       message_body: "",
       tab: :all,
       show_new_direct: false,
       contacts: []
     )
     |> allow_upload(:attachments,
       accept: :any,
       max_entries: 5,
       max_file_size: 10_000_000
     )}
  end

  @impl true
  def handle_params(%{"conversation_id" => id}, _uri, socket) do
    actor = socket.assigns.current_user

    case Messaging.get_conversation(id, actor: actor) do
      {:ok, conversation} -> open_conversation(socket, conversation, actor)
      _ -> {:noreply, put_flash(socket, :error, "Conversation not found.")}
    end
  end

  def handle_params(_params, _uri, socket), do: {:noreply, socket}

  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    tab = String.to_existing_atom(tab)
    conversations = load_conversations(socket.assigns.current_user, tab)
    {:noreply, assign(socket, tab: tab, conversations: conversations)}
  end

  def handle_event("select_conversation", %{"id" => id}, socket) do
    actor = socket.assigns.current_user

    case Messaging.get_conversation(id, actor: actor) do
      {:ok, conversation} -> open_conversation(socket, conversation, actor)
      _ -> {:noreply, put_flash(socket, :error, "Conversation not found.")}
    end
  end

  def handle_event("show_new_direct", _params, socket) do
    actor = socket.assigns.current_user
    contacts = load_contacts(actor, socket.assigns.gym)
    {:noreply, assign(socket, show_new_direct: true, contacts: contacts)}
  end

  def handle_event("cancel_new", _params, socket) do
    {:noreply, assign(socket, show_new_direct: false)}
  end

  def handle_event("start_direct", %{"user_id" => user_id}, socket) do
    actor = socket.assigns.current_user
    gym = socket.assigns.gym

    case Messaging.find_direct_conversation(actor.id, user_id, gym.id, actor: actor) do
      {:ok, [existing | _]} ->
        {:noreply,
         socket
         |> assign(show_new_direct: false)
         |> open_conversation_noreply(existing, actor)}

      _ ->
        with {:ok, conversation} <-
               Messaging.create_conversation(
                 %{type: :direct, gym_id: gym.id, created_by_id: actor.id},
                 actor: actor
               ),
             {:ok, _} <-
               Messaging.create_participant(
                 %{conversation_id: conversation.id, user_id: actor.id, role: :owner},
                 actor: actor
               ),
             {:ok, _} <-
               Messaging.create_participant(
                 %{conversation_id: conversation.id, user_id: user_id, role: :participant},
                 actor: actor
               ) do
          Phoenix.PubSub.broadcast(
            FitTrackerz.PubSub,
            "messaging:user:#{user_id}",
            {:new_conversation, %{conversation_id: conversation.id}}
          )

          conversations = load_conversations(actor, socket.assigns.tab)
          {:ok, conversation} = Messaging.get_conversation(conversation.id, actor: actor)

          {:noreply,
           socket
           |> assign(show_new_direct: false, conversations: conversations)
           |> open_conversation_noreply(conversation, actor)}
        else
          _ -> {:noreply, put_flash(socket, :error, "Failed to create conversation.")}
        end
    end
  end

  def handle_event("send_message", %{"body" => body}, socket) when byte_size(body) > 0 do
    actor = socket.assigns.current_user
    conversation = socket.assigns.active_conversation

    attachment_data =
      consume_uploaded_entries(socket, :attachments, fn %{path: path}, entry ->
        dest_dir = Path.join(["priv/static/uploads/messages", conversation.id])
        File.mkdir_p!(dest_dir)
        filename = "#{Ecto.UUID.generate()}-#{entry.client_name}"
        dest = Path.join(dest_dir, filename)
        File.cp!(path, dest)

        {:ok,
         %{
           "filename" => entry.client_name,
           "url" => "/uploads/messages/#{conversation.id}/#{filename}",
           "content_type" => entry.client_type,
           "size" => entry.client_size
         }}
      end)

    case Messaging.create_message(
           %{body: body, conversation_id: conversation.id, sender_id: actor.id, attachments: attachment_data},
           actor: actor
         ) do
      {:ok, message} ->
        Messaging.touch_conversation(conversation, actor: actor)
        message = %{message | sender: actor}

        Phoenix.PubSub.broadcast(
          FitTrackerz.PubSub,
          "messaging:conversation:#{conversation.id}",
          {:new_message, message}
        )

        broadcast_to_participants(conversation.id, actor, {:conversation_updated, %{conversation_id: conversation.id}})

        {:noreply,
         socket
         |> assign(message_body: "")
         |> update(:active_messages, &(&1 ++ [message]))
         |> push_event("scroll_to_bottom", %{})}

      _ ->
        {:noreply, put_flash(socket, :error, "Failed to send message.")}
    end
  end

  def handle_event("send_message", _params, socket), do: {:noreply, socket}

  def handle_event("update_body", %{"body" => body}, socket) do
    {:noreply, assign(socket, message_body: body)}
  end

  def handle_event("cancel_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :attachments, ref)}
  end

  @impl true
  def handle_info({:new_message, message}, socket) do
    if socket.assigns.active_conversation &&
         socket.assigns.active_conversation.id == message.conversation_id &&
         message.sender_id != socket.assigns.current_user.id do
      mark_conversation_read(socket.assigns.active_conversation, socket.assigns.current_user)

      {:noreply,
       socket
       |> update(:active_messages, &(&1 ++ [message]))
       |> push_event("scroll_to_bottom", %{})}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:new_conversation, _}, socket) do
    conversations = load_conversations(socket.assigns.current_user, socket.assigns.tab)
    {:noreply, assign(socket, conversations: conversations)}
  end

  def handle_info({:conversation_updated, _}, socket) do
    conversations = load_conversations(socket.assigns.current_user, socket.assigns.tab)
    {:noreply, assign(socket, conversations: conversations)}
  end

  # Private helpers

  defp open_conversation(socket, conversation, actor) do
    if connected?(socket) && socket.assigns[:active_conversation] do
      Phoenix.PubSub.unsubscribe(FitTrackerz.PubSub, "messaging:conversation:#{socket.assigns.active_conversation.id}")
    end

    if connected?(socket) do
      Phoenix.PubSub.subscribe(FitTrackerz.PubSub, "messaging:conversation:#{conversation.id}")
    end

    messages = load_messages(conversation, actor)
    mark_conversation_read(conversation, actor)

    {:noreply,
     socket
     |> assign(active_conversation: conversation, active_messages: messages, message_body: "", show_new_direct: false)
     |> push_event("scroll_to_bottom", %{})}
  end

  defp open_conversation_noreply(socket, conversation, actor) do
    if socket.assigns[:active_conversation] do
      Phoenix.PubSub.unsubscribe(FitTrackerz.PubSub, "messaging:conversation:#{socket.assigns.active_conversation.id}")
    end

    Phoenix.PubSub.subscribe(FitTrackerz.PubSub, "messaging:conversation:#{conversation.id}")

    messages = load_messages(conversation, actor)
    mark_conversation_read(conversation, actor)

    socket
    |> assign(active_conversation: conversation, active_messages: messages, message_body: "")
    |> push_event("scroll_to_bottom", %{})
  end

  defp load_gym(actor) do
    case Gym.list_active_memberships(actor.id, actor: actor) do
      {:ok, [gm | _]} -> gm.gym
      _ -> nil
    end
  end

  defp load_conversations(actor, :all) do
    case Messaging.list_conversations(actor.id, actor: actor) do
      {:ok, convs} -> convs
      _ -> []
    end
  end

  defp load_conversations(actor, :direct) do
    case Messaging.list_direct_conversations(actor.id, actor: actor) do
      {:ok, convs} -> convs
      _ -> []
    end
  end

  defp load_conversations(actor, :announcements) do
    case Messaging.list_announcements(actor.id, actor: actor) do
      {:ok, convs} -> convs
      _ -> []
    end
  end

  defp load_messages(conversation, actor) do
    case Messaging.list_messages(conversation.id, actor: actor) do
      {:ok, messages} -> messages
      _ -> []
    end
  end

  defp load_contacts(actor, gym) when not is_nil(gym) do
    # Get member's gym_member record to find assigned trainer
    gm =
      case Gym.list_active_memberships(actor.id, actor: actor) do
        {:ok, memberships} -> Enum.find(memberships, &(&1.gym_id == gym.id))
        _ -> nil
      end

    # Assigned trainer
    trainer_contacts =
      if gm && gm.assigned_trainer_id do
        case Gym.list_trainers_by_gym(gym.id, actor: actor) do
          {:ok, trainers} ->
            trainers
            |> Enum.filter(&(&1.id == gm.assigned_trainer_id))
            |> Enum.map(fn t -> %{id: t.user.id, name: t.user.name, role: :trainer} end)

          _ ->
            []
        end
      else
        []
      end

    # Gym operator
    operator =
      if gym.owner_id != actor.id do
        case FitTrackerz.Accounts.get_user(gym.owner_id, actor: actor) do
          {:ok, user} -> [%{id: user.id, name: user.name, role: :gym_operator}]
          _ -> []
        end
      else
        []
      end

    (trainer_contacts ++ operator) |> Enum.uniq_by(& &1.id)
  end

  defp load_contacts(_actor, _gym), do: []

  defp mark_conversation_read(conversation, actor) do
    case Messaging.list_participants(conversation.id, actor: actor) do
      {:ok, participants} ->
        case Enum.find(participants, &(&1.user_id == actor.id)) do
          nil -> :ok
          participant -> Messaging.mark_participant_read(participant, actor: actor)
        end

      _ ->
        :ok
    end
  end

  defp broadcast_to_participants(conversation_id, sender, message) do
    system_actor = %{id: "system", is_system_actor: true}

    case Messaging.list_participants(conversation_id, actor: system_actor) do
      {:ok, participants} ->
        participants
        |> Enum.reject(&(&1.user_id == sender.id))
        |> Enum.each(fn p ->
          Phoenix.PubSub.broadcast(FitTrackerz.PubSub, "messaging:user:#{p.user_id}", message)
        end)

      _ ->
        :ok
    end
  end

  defp conversation_display_name(conversation, current_user_id) do
    case conversation.type do
      :announcement -> conversation.title || "Announcement"
      :direct ->
        case conversation.participants do
          participants when is_list(participants) ->
            other = Enum.find(participants, fn p -> p.user_id != current_user_id end)
            case other do
              %{user: %{name: name}} when not is_nil(name) -> name
              _ -> "Unknown"
            end
          _ -> "Direct Message"
        end
    end
  end

  defp last_message_preview(conversation) do
    case conversation.messages do
      messages when is_list(messages) and length(messages) > 0 ->
        msg = List.last(Enum.sort_by(messages, & &1.inserted_at))
        String.slice(msg.body, 0, 50) <> if(String.length(msg.body) > 50, do: "...", else: "")
      _ -> "No messages yet"
    end
  end

  defp last_message_time(conversation) do
    case conversation.messages do
      messages when is_list(messages) and length(messages) > 0 ->
        msg = List.last(Enum.sort_by(messages, & &1.inserted_at))
        format_relative_time(msg.inserted_at)
      _ -> ""
    end
  end

  defp unread_count(conversation, current_user_id) do
    participant =
      case conversation.participants do
        ps when is_list(ps) -> Enum.find(ps, &(&1.user_id == current_user_id))
        _ -> nil
      end

    last_read = participant && participant.last_read_at

    case conversation.messages do
      messages when is_list(messages) ->
        if last_read do
          Enum.count(messages, fn m -> DateTime.compare(m.inserted_at, last_read) == :gt and m.sender_id != current_user_id end)
        else
          Enum.count(messages, &(&1.sender_id != current_user_id))
        end
      _ -> 0
    end
  end

  defp can_send_message?(conversation, current_user_id) do
    case conversation.type do
      :direct -> true
      :announcement -> conversation.created_by_id == current_user_id
    end
  end

  defp format_relative_time(datetime) do
    diff = DateTime.diff(DateTime.utc_now(), datetime, :second)
    cond do
      diff < 60 -> "now"
      diff < 3600 -> "#{div(diff, 60)}m"
      diff < 86400 -> "#{div(diff, 3600)}h"
      diff < 604_800 -> "#{div(diff, 86400)}d"
      true -> Calendar.strftime(datetime, "%b %d")
    end
  end

  defp format_message_time(datetime), do: Calendar.strftime(datetime, "%I:%M %p")

  defp format_file_size(size) when size < 1024, do: "#{size} B"
  defp format_file_size(size) when size < 1_048_576, do: "#{Float.round(size / 1024, 1)} KB"
  defp format_file_size(size), do: "#{Float.round(size / 1_048_576, 1)} MB"

  defp is_image?(ct), do: String.starts_with?(ct || "", "image/")

  defp role_badge(:trainer), do: "badge-warning"
  defp role_badge(:gym_operator), do: "badge-accent"
  defp role_badge(_), do: "badge-ghost"

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="flex flex-col h-[calc(100vh-8rem)]">
        <div class="flex items-center gap-3 mb-4">
          <Layouts.back_button />
          <div>
            <h1 class="text-2xl sm:text-3xl font-brand">Messages</h1>
            <p class="text-base-content/50 mt-0.5 text-sm">Chat with your trainer and gym.</p>
          </div>
        </div>

        <div class="flex flex-1 gap-4 min-h-0">
          <%!-- Left Panel --%>
          <div class="w-80 shrink-0 flex flex-col bg-base-200/50 rounded-xl border border-base-300/50">
            <div class="p-3 border-b border-base-300/50">
              <div class="tabs tabs-boxed tabs-sm">
                <button phx-click="switch_tab" phx-value-tab="all" class={"tab #{if @tab == :all, do: "tab-active"}"}>All</button>
                <button phx-click="switch_tab" phx-value-tab="direct" class={"tab #{if @tab == :direct, do: "tab-active"}"}>Direct</button>
                <button phx-click="switch_tab" phx-value-tab="announcements" class={"tab #{if @tab == :announcements, do: "tab-active"}"}>Announcements</button>
              </div>
            </div>

            <div class="p-3 border-b border-base-300/50">
              <button phx-click="show_new_direct" class="btn btn-sm btn-primary w-full gap-1">
                <.icon name="hero-chat-bubble-left-right-mini" class="size-4" /> New Message
              </button>
            </div>

            <div class="flex-1 overflow-y-auto" id="conversation-list">
              <%= if @conversations == [] do %>
                <div class="p-6 text-center text-base-content/40 text-sm">No conversations yet</div>
              <% else %>
                <div
                  :for={conv <- @conversations}
                  id={"conv-#{conv.id}"}
                  phx-click="select_conversation"
                  phx-value-id={conv.id}
                  class={"flex items-center gap-3 p-3 cursor-pointer hover:bg-base-300/50 transition-colors border-b border-base-300/30 #{if @active_conversation && @active_conversation.id == conv.id, do: "bg-base-300/70"}"}
                >
                  <div class={"w-10 h-10 rounded-full flex items-center justify-center shrink-0 #{if conv.type == :announcement, do: "bg-secondary/15", else: "bg-primary/15"}"}>
                    <%= if conv.type == :announcement do %>
                      <.icon name="hero-megaphone-solid" class="size-5 text-secondary" />
                    <% else %>
                      <span class="text-sm font-bold text-primary">{String.first(conversation_display_name(conv, @current_user.id))}</span>
                    <% end %>
                  </div>
                  <div class="flex-1 min-w-0">
                    <div class="flex items-center justify-between">
                      <span class="font-semibold text-sm truncate">{conversation_display_name(conv, @current_user.id)}</span>
                      <span class="text-xs text-base-content/40 shrink-0">{last_message_time(conv)}</span>
                    </div>
                    <p class="text-xs text-base-content/50 truncate mt-0.5">{last_message_preview(conv)}</p>
                  </div>
                  <% count = unread_count(conv, @current_user.id) %>
                  <%= if count > 0 do %>
                    <span class="badge badge-primary badge-xs">{count}</span>
                  <% end %>
                </div>
              <% end %>
            </div>
          </div>

          <%!-- Right Panel --%>
          <div class="flex-1 flex flex-col bg-base-200/30 rounded-xl border border-base-300/50">
            <%= cond do %>
              <% @show_new_direct -> %>
                <div class="p-4 border-b border-base-300/50 flex items-center justify-between">
                  <h2 class="font-bold">New Conversation</h2>
                  <button phx-click="cancel_new" class="btn btn-ghost btn-sm btn-circle"><.icon name="hero-x-mark-mini" class="size-5" /></button>
                </div>
                <div class="flex-1 overflow-y-auto p-4">
                  <p class="text-sm text-base-content/50 mb-3">Select a person to message:</p>
                  <%= if @contacts == [] do %>
                    <p class="text-center text-base-content/40 text-sm py-8">No contacts available.</p>
                  <% else %>
                    <div class="space-y-2">
                      <div :for={contact <- @contacts} phx-click="start_direct" phx-value-user_id={contact.id} class="flex items-center gap-3 p-3 rounded-lg cursor-pointer hover:bg-base-300/50 transition-colors">
                        <div class="w-9 h-9 rounded-full bg-primary/15 flex items-center justify-center">
                          <span class="text-sm font-bold text-primary">{String.first(contact.name)}</span>
                        </div>
                        <div class="flex-1"><span class="font-medium text-sm">{contact.name}</span></div>
                        <span class={"badge badge-sm #{role_badge(contact.role)}"}>{contact.role}</span>
                      </div>
                    </div>
                  <% end %>
                </div>

              <% @active_conversation != nil -> %>
                <div class="p-4 border-b border-base-300/50 flex items-center gap-3">
                  <div class={"w-10 h-10 rounded-full flex items-center justify-center #{if @active_conversation.type == :announcement, do: "bg-secondary/15", else: "bg-primary/15"}"}>
                    <%= if @active_conversation.type == :announcement do %>
                      <.icon name="hero-megaphone-solid" class="size-5 text-secondary" />
                    <% else %>
                      <span class="text-sm font-bold text-primary">{String.first(conversation_display_name(@active_conversation, @current_user.id))}</span>
                    <% end %>
                  </div>
                  <div>
                    <h2 class="font-bold text-sm">{conversation_display_name(@active_conversation, @current_user.id)}</h2>
                    <%= if @active_conversation.type == :announcement do %>
                      <span class="text-xs text-base-content/40">Announcement</span>
                    <% end %>
                  </div>
                </div>

                <div class="flex-1 overflow-y-auto p-4 space-y-3" id="message-list" phx-hook="ScrollToBottom">
                  <%= if @active_messages == [] do %>
                    <div class="text-center text-base-content/40 text-sm py-8">No messages yet. Start the conversation!</div>
                  <% else %>
                    <div :for={msg <- @active_messages} id={"msg-#{msg.id}"} class={"flex #{if msg.sender_id == @current_user.id, do: "justify-end", else: "justify-start"}"}>
                      <div class={"max-w-[70%] #{if msg.sender_id == @current_user.id, do: "bg-primary text-primary-content", else: "bg-base-300"} rounded-2xl px-4 py-2.5"}>
                        <%= if msg.sender_id != @current_user.id do %>
                          <p class="text-xs font-semibold opacity-70 mb-1">{if msg.sender, do: msg.sender.name, else: "Unknown"}</p>
                        <% end %>
                        <p class="text-sm whitespace-pre-wrap">{msg.body}</p>
                        <%= if msg.attachments != [] do %>
                          <div class="mt-2 space-y-1">
                            <div :for={att <- msg.attachments}>
                              <%= if is_image?(att["content_type"]) do %>
                                <img src={att["url"]} alt={att["filename"]} class="rounded-lg max-w-full max-h-48 mt-1" />
                              <% else %>
                                <a href={att["url"]} target="_blank" class={"flex items-center gap-2 text-xs underline #{if msg.sender_id == @current_user.id, do: "text-primary-content/80", else: "text-base-content/60"}"}>
                                  <.icon name="hero-paper-clip-mini" class="size-3" /> {att["filename"]} ({format_file_size(att["size"])})
                                </a>
                              <% end %>
                            </div>
                          </div>
                        <% end %>
                        <p class={"text-[10px] mt-1 #{if msg.sender_id == @current_user.id, do: "text-primary-content/50", else: "text-base-content/30"}"}>{format_message_time(msg.inserted_at)}</p>
                      </div>
                    </div>
                  <% end %>
                </div>

                <%= if can_send_message?(@active_conversation, @current_user.id) do %>
                  <div class="p-3 border-t border-base-300/50">
                    <%= if @uploads.attachments.entries != [] do %>
                      <div class="flex flex-wrap gap-2 mb-2">
                        <div :for={entry <- @uploads.attachments.entries} class="flex items-center gap-1 bg-base-300 rounded-lg px-2 py-1 text-xs">
                          <span class="truncate max-w-[120px]">{entry.client_name}</span>
                          <button type="button" phx-click="cancel_upload" phx-value-ref={entry.ref} class="btn btn-ghost btn-xs btn-circle"><.icon name="hero-x-mark-mini" class="size-3" /></button>
                        </div>
                      </div>
                    <% end %>
                    <form phx-submit="send_message" phx-change="update_body" class="flex items-end gap-2">
                      <label class="btn btn-ghost btn-sm btn-circle cursor-pointer shrink-0">
                        <.icon name="hero-paper-clip" class="size-5" />
                        <.live_file_input upload={@uploads.attachments} class="hidden" />
                      </label>
                      <textarea name="body" value={@message_body} class="textarea textarea-bordered flex-1 min-h-[2.5rem] max-h-32 resize-none text-sm" placeholder="Type a message..." rows="1" phx-hook="AutoResize" id="message-input"></textarea>
                      <button type="submit" class="btn btn-primary btn-sm btn-circle shrink-0"><.icon name="hero-paper-airplane-mini" class="size-4" /></button>
                    </form>
                  </div>
                <% else %>
                  <div class="p-3 border-t border-base-300/50 text-center text-sm text-base-content/40">This is a read-only announcement.</div>
                <% end %>

              <% true -> %>
                <div class="flex-1 flex items-center justify-center">
                  <div class="text-center">
                    <div class="w-16 h-16 rounded-2xl bg-base-300/30 flex items-center justify-center mx-auto mb-4">
                      <.icon name="hero-chat-bubble-left-right" class="size-8 text-base-content/20" />
                    </div>
                    <h2 class="text-lg font-bold text-base-content/50">Select a conversation</h2>
                    <p class="text-sm text-base-content/30 mt-1">Or start a new one</p>
                  </div>
                </div>
            <% end %>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
```

- [ ] **Step 2: Verify compilation**

```bash
mix compile --warnings-as-errors
```

---

### Task 8: JavaScript Hooks for ScrollToBottom and AutoResize

**Files:**
- Modify: `assets/js/app.js`

- [ ] **Step 1: Add ScrollToBottom and AutoResize hooks**

Add these hooks to the `Hooks` object in `assets/js/app.js`:

```javascript
Hooks.ScrollToBottom = {
  mounted() {
    this.scrollToBottom()
    this.handleEvent("scroll_to_bottom", () => {
      this.scrollToBottom()
    })
  },
  updated() {
    this.scrollToBottom()
  },
  scrollToBottom() {
    this.el.scrollTop = this.el.scrollHeight
  }
}

Hooks.AutoResize = {
  mounted() {
    this.el.addEventListener("input", () => {
      this.el.style.height = "auto"
      this.el.style.height = this.el.scrollHeight + "px"
    })
  }
}
```

- [ ] **Step 2: Verify the hooks are registered with LiveSocket**

Ensure `let liveSocket = new LiveSocket("/live", Socket, {params: {...}, hooks: Hooks})` includes the Hooks object.

---

### Task 9: Static File Serving for Uploads

**Files:**
- Modify: `lib/fit_trackerz_web/endpoint.ex`

- [ ] **Step 1: Add uploads path to static file serving**

In the `Plug.Static` configuration in `endpoint.ex`, add `"uploads"` to the `only` list so that files at `/uploads/messages/...` are served correctly.

Find the existing `Plug.Static` plug and add `"uploads"` to the `only` list:

```elixir
plug Plug.Static,
  at: "/",
  from: :fit_trackerz,
  gzip: false,
  only: FitTrackerzWeb.static_paths() ++ ["uploads"]
```

- [ ] **Step 2: Verify compilation**

```bash
mix compile --warnings-as-errors
```

---

### Task 10: Accounts Domain — Add get_user

**Files:**
- Modify: `lib/fit_trackerz/accounts.ex` (if `get_user` is not already defined)

- [ ] **Step 1: Check if get_user exists in Accounts domain**

The Trainer MessagesLive and Member MessagesLive call `FitTrackerz.Accounts.get_user/2` to look up the gym operator. Check if this function is defined in `lib/fit_trackerz/accounts.ex`. If not, add it:

```elixir
define :get_user, args: [:id], action: :get_by_id
```

Add this inside the `resource FitTrackerz.Accounts.User do ... end` block.

- [ ] **Step 2: Verify compilation**

```bash
mix compile --warnings-as-errors
```

---

### Task 11: Full Compilation and Manual Smoke Test

- [ ] **Step 1: Full compilation check**

```bash
mix compile --warnings-as-errors
```

- [ ] **Step 2: Run migration**

```bash
mix ecto.migrate
```

- [ ] **Step 3: Start the server**

```bash
mix phx.server
```

- [ ] **Step 4: Manual smoke test**

1. Sign in as gym operator → check `/gym/messages` loads
2. Sign in as trainer → check `/trainer/messages` loads
3. Sign in as member → check `/member/messages` loads
4. As operator: create announcement → verify it appears for members
5. As operator: start direct chat with a member → send message → verify member sees it
6. Test file upload in a message
