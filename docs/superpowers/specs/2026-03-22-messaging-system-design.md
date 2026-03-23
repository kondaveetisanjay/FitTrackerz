# Messaging System Design

**Date:** 2026-03-22
**Status:** Approved
**Branch:** feature/restore-trainer-role

## Overview

Add a real-time messaging system to FitTrackerz supporting 1-to-1 direct conversations and broadcast announcements. All messaging is scoped to a gym.

## Requirements

- **Direct messaging (1-to-1):** Operator <-> Member, Operator <-> Trainer, Trainer <-> assigned Member
- **Announcements:** Operator -> all gym members/trainers, Trainer -> all their assigned clients
- **Real-time** delivery via Phoenix PubSub
- **File attachments** (any type, max 10MB/file, 5 files/message)
- **Simple audience targeting now**, filterable later (by branch, status, etc.)
- Announcements are **read-only** for recipients (no replies)

## Data Model

### New Ash Domain: `FitTrackerz.Messaging`

Three Ash resources in `lib/fit_trackerz/messaging/`.

### Conversation

Table: `conversations`

| Field | Type | Notes |
|-------|------|-------|
| id | uuid | PK |
| type | atom | `:direct` or `:announcement` |
| title | string | Nullable. Used for announcements. Max 255 chars |
| gym_id | uuid | FK -> gyms. Required. on_delete: :delete |
| created_by_id | uuid | FK -> users. Required. on_delete: :delete |
| inserted_at | utc_datetime_usec | |
| updated_at | utc_datetime_usec | |

Indexes: `[gym_id]`, `[created_by_id]`

### ConversationParticipant

Table: `conversation_participants`

| Field | Type | Notes |
|-------|------|-------|
| id | uuid | PK |
| conversation_id | uuid | FK -> conversations. Required. on_delete: :delete |
| user_id | uuid | FK -> users. Required. on_delete: :delete |
| role | atom | `:owner` or `:participant` |
| last_read_at | utc_datetime_usec | Nullable. Tracks read status |
| inserted_at | utc_datetime_usec | |
| updated_at | utc_datetime_usec | |

Identity: unique on `[conversation_id, user_id]`
Indexes: `[user_id]`, `[conversation_id]`

### Message

Table: `messages`

| Field | Type | Notes |
|-------|------|-------|
| id | uuid | PK |
| conversation_id | uuid | FK -> conversations. Required. on_delete: :delete |
| sender_id | uuid | FK -> users. Required. on_delete: :delete |
| body | string | Max 5000 chars. Required |
| attachments | {:array, :map} | Default []. Each: %{filename, url, content_type, size} |
| inserted_at | utc_datetime_usec | |
| updated_at | utc_datetime_usec | |

Indexes: `[conversation_id, inserted_at]`, `[sender_id]`

## Conversation Rules

### Direct Conversations

- User picks a recipient from their gym contacts
- System checks for existing direct conversation between the two users in that gym
- If exists: open it. If not: create with 2 participants.
- Both participants can send messages

### Announcements

- Operator creates announcement -> system bulk-inserts participants for all gym members + trainers
- Trainer creates announcement -> system bulk-inserts participants for all their assigned clients
- Creator has role `:owner`, recipients have role `:participant`
- Only `:owner` can send messages (recipients read-only)

## Authorization (Ash Policies)

| Action | Allowed |
|--------|---------|
| Create direct conversation | operator, trainer, member (within their gym) |
| Create announcement | operator (whole gym), trainer (their clients) |
| Send message in direct | Both participants of the conversation |
| Send message in announcement | Only the conversation `:owner` |
| Read conversation/messages | Only participants of that conversation |

All resources bypass for `platform_admin` and `system_actor`.

### Relationship Validation

- Trainer <-> Member direct chat: member must be assigned to that trainer via `gym_members.assigned_trainer_id`
- All participants must belong to the same gym (via `gym_members` or `gym_trainers` or gym `owner_id`)

## Real-Time (PubSub)

### Topics

| Topic | Format | Subscribers |
|-------|--------|-------------|
| User inbox | `messaging:user:{user_id}` | User on messages page. For new conversations, unread count updates |
| Conversation | `messaging:conversation:{conversation_id}` | Users viewing that conversation. For live message append |

### Event Flow

**Sending a message:**
1. Message created via Ash action
2. Broadcast to `messaging:conversation:{id}` -> live append in open chat
3. Broadcast to `messaging:user:{recipient_id}` for each participant (except sender) -> unread badge update

**New conversation created:**
1. Conversation + participants created
2. Broadcast to `messaging:user:{user_id}` for each participant -> new conversation in list

**Read tracking:**
1. User opens conversation -> `last_read_at` updated on their participant record
2. Unread count = messages where `inserted_at > last_read_at`

## File Attachments

### Storage

- Local storage at `priv/static/uploads/messages/{conversation_id}/{uuid}-{filename}`
- Metadata stored in message `attachments` array field
- Migratable to S3 later without schema changes

### Upload Flow

1. Phoenix LiveView `allow_upload` with drag-and-drop support
2. Validation: max 10MB per file, max 5 files per message
3. On send: files consumed, saved to disk, metadata written to message

### Display

- Images (`image/*`): inline preview
- Other files: download link with filename and size

## Routes

| Role | Route | LiveView Module |
|------|-------|-----------------|
| Operator | `/gym/messages` | `FitTrackerzWeb.GymOperator.MessagesLive` |
| Trainer | `/trainer/messages` | `FitTrackerzWeb.Trainer.MessagesLive` |
| Member | `/member/messages` | `FitTrackerzWeb.Member.MessagesLive` |

## UI Layout

Single MessagesLive page per role with two-panel layout:

### Left Panel - Conversation List
- Tabs: "Direct" | "Announcements"
- Each item: recipient name/title, last message preview, timestamp, unread badge
- Sorted by most recent message
- "New Message" button -> recipient picker (filtered by gym role relationships)
- "New Announcement" button (operator/trainer only)

### Right Panel - Active Conversation
- Header: recipient name (direct) or announcement title
- Scrollable message history, oldest first, infinite scroll up for history
- Each message: sender name, body, attachments, timestamp
- Message input at bottom: text field + file upload button
- Announcements: input visible to `:owner` only

### Sidebar Navigation
- Unread message count badge next to "Messages" link in each role's sidebar
- Updated via PubSub subscription at layout level

## Migration

One migration adding three tables: `conversations`, `conversation_participants`, `messages`.

## Future Considerations (Not in scope now)

- Announcement filtering by branch, subscription status, active/inactive
- Group conversations
- Message reactions
- Typing indicators
- S3 file storage
- Message search
