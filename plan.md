# Snag — Build Plan for Claude Code

> **Project:** BYTE (MAIT) App Development recruitment task — a personal save-for-later app.
> **Deadline:** submit before **Oct 13, 2026, 11:59 PM IST**.
> **Platform:** Android APK (Flutter). **Backend:** Supabase (free plan).
> **This file is the single source of truth.** Build exactly what it says, stage by stage.

---

## 0. How Claude Code must use this file

1. **Read the whole file before writing any code.**
2. **Work one stage at a time**, in the order of section 10. Never start a stage until the previous stage's acceptance checklist passes.
3. **Stop at the end of every stage.** Report what was built, what was tested, and anything that failed. Wait for the user to say "continue".
4. **Do not build anything marked "Later"** (section 14) and do not add features that are not in this file. If something seems missing, ask.
5. **Oct 11 pick:** exactly ONE of P1–P4 (section 10) gets built. **The user has not chosen yet — ask before starting any pick.**
6. **Packages:** use only the packages in section 4. Before adding each one, check its pub.dev page for the latest version compatible with the installed Flutter SDK, a recent publish date and a verified publisher. If a package looks unmaintained or incompatible, stop and ask.
7. **Secrets:** never write the Supabase URL or key into source code. Read them with `String.fromEnvironment` from `--dart-define-from-file=env.json`. `env.json` is gitignored. **Never use the service_role / secret key anywhere.**
8. **Before every commit:** run `dart format .`, `flutter analyze` (zero errors, zero warnings) and `flutter test`. Fix failures before committing.
9. **Commits:** small, frequent, Conventional Commits style (`feat: add archive/restore`, `fix: keep draft on network error`). The reviewers read the commit history.
10. **Never** run destructive git commands (force-push, history rewrite, `reset --hard` on shared branches).
11. **Never change the security rules** in `supabase/schema.sql` without asking.
12. When a step needs something only the human can do (Supabase dashboard, UptimeRobot, a physical phone), say so clearly and wait.

---

## 1. Product summary

**Snag** ("Snag it now, find it later") is a Telegram-inspired super-app with **three separate apps in one**:

| Tab | What it is |
|---|---|
| **Messenger** (default) | A chat list with a pinned **Saved Messages** chat: a private save-for-later inbox where every note, link or image is a bubble. |
| **Drive** | A private cloud drive. v1 shows **From Chats** (read-only view of Saved Messages attachments). |
| **Calendar** | Personal events (only if chosen as the Oct 11 pick). |

**The Saved Messages chat implements everything the BYTE brief grades.** Drive and Calendar are extras.

**Separation rule:** each tab keeps its own data. The only exception is Drive's read-only **From Chats** section, which *shows* chat attachments without copying them.

**Branding:** own name and icon, Material 3, one accent color (teal `#0F766E`), light/dark follows the system. **No Telegram names, logos or assets.**

---

## 2. Scope and release tiers

| Tier | Contents |
|---|---|
| **Oct 13 (guaranteed)** | Stage 1 (local Saved Messages) · Stage 2 (auth, cloud sync, RLS, security tests) · Stage 3 (Share into app) · Mission C (image/PDF attachments + Drive "From Chats") |
| **Oct 11 pick (exactly one)** | P1 Drive "My Files" · P2 Calendar v1 · P3 Mission D reminders · P4 1:1 chats (text only) |
| **Later (do not build)** | Everything in section 14 |

**Cut rule:** if time runs short, cut from the bottom (the pick first). **Never** cut Stages 1–3, Mission C or the security tests.

Tabs or sections that are not built show a clean **"Coming soon"** screen with an icon and one line of text. Nothing may look broken.

---

## 3. Non-negotiable rules

**From the brief:**
- Every item has: id, type, title, content or URL, tags, created/updated dates, archived state.
- Create, view, open, edit, delete, archive, restore; tags; search and filter.
- Data survives closing and reopening the app.
- An inbox/home screen and a create/edit screen (plus a detail screen).
- Sign-up and sign-in with email/username + password.
- Same data on a second device/emulator after signing in.
- **Privacy enforced by the backend.** Changing an item ID, request, URL, route or deep link must never expose another user's item. Client-side filtering alone does not count.
- Clear feedback + retry for loading, request failures, lost internet and wrong credentials.
- Share text/URLs into the app from Android's Share menu; malformed or unsupported shares never crash.

**Security:**
- RLS on every table. Storage policies on every bucket. Both are in section 7.2 and are already tested.
- The app ships only the anon/publishable key.
- A "not found" and a "belongs to someone else" item look identical to the user: **"This item no longer exists."** Never reveal that another user's item exists.
- Logout deletes all local data (database rows, drafts, cached files) for that user.

**Quality:**
- No crashes on empty input, very long input, emoji-only input, no internet, or a deleted item.
- Every async action shows a loading state; every failure shows a message and a **Retry** where retry makes sense.

---

## 4. Tech stack and packages

| Layer | Choice |
|---|---|
| App | Flutter (latest stable) + Dart, Material 3 |
| State | flutter_riverpod |
| Navigation | go_router (auth redirect + deep links such as `/item/:id`) |
| Local database | drift (SQLite) |
| Backend | Supabase: Auth, Postgres + RLS, Storage, Realtime (P4 only) |
| Keep-alive | UptimeRobot pinging the `heartbeat` table (human sets it up) |

| Need | Package | Verification status |
|---|---|---|
| Share into the app | `receive_sharing_intent` (1.9.0 at time of writing, Apache-2.0) | Verified on pub.dev |
| Local database | `drift` (+ `drift_flutter` or `sqlite3_flutter_libs`, `drift_dev`, `build_runner`) | Verified (drift); ⚠️ check the setup packages drift's docs currently recommend |
| Supabase client | `supabase_flutter` | ⚠️ UNVERIFIED — check pub.dev |
| State | `flutter_riverpod` | ⚠️ UNVERIFIED |
| Navigation | `go_router` | ⚠️ UNVERIFIED |
| Images | `image_picker` (with `maxWidth` / `imageQuality` compression) | ⚠️ UNVERIFIED |
| PDFs | `file_picker` | ⚠️ UNVERIFIED |
| App folders | `path_provider` | ⚠️ UNVERIFIED |
| Open links / files | `url_launcher` | ⚠️ UNVERIFIED |
| Offline detection | `connectivity_plus` | ⚠️ UNVERIFIED |
| IDs | `uuid` | ⚠️ UNVERIFIED |
| Notifications (P2/P3 only) | `flutter_local_notifications` + `timezone` (+ `flutter_timezone` if needed for the device zone) | ⚠️ UNVERIFIED |

**Not used (decided):** Firebase (Storage needs a billing account), Render (no custom server needed), Cloudflare Pages/R2, Google Calendar API, any package not listed above without asking.

---

## 5. Project structure

```text
snag/
├─ lib/
│  ├─ main.dart                      # init Supabase (Stage 2+), drift, services; runApp
│  ├─ app/
│  │  ├─ app.dart                    # MaterialApp.router, theme
│  │  ├─ router.dart                 # go_router: routes, auth redirect, deep links
│  │  └─ theme.dart                  # Material 3, seed #0F766E, light + dark
│  ├─ core/
│  │  ├─ env.dart                    # String.fromEnvironment('SUPABASE_URL' / 'SUPABASE_ANON_KEY')
│  │  ├─ result.dart                 # success/failure type for repository calls
│  │  ├─ errors.dart                 # map Supabase/network errors to user messages
│  │  └─ utils/
│  │     ├─ url_utils.dart           # extract first URL, validate, domain name
│  │     ├─ title_utils.dart         # auto-title rules
│  │     └─ tag_utils.dart           # normalise tags
│  ├─ data/
│  │  ├─ local/
│  │  │  ├─ app_database.dart        # drift database + migrations
│  │  │  └─ tables.dart              # drift tables (section 7.1)
│  │  ├─ remote/
│  │  │  ├─ items_remote.dart        # Supabase queries for items
│  │  │  ├─ storage_remote.dart      # uploads, signed URLs, deletes
│  │  │  └─ auth_remote.dart
│  │  └─ repositories/
│  │     ├─ items_repository.dart    # THE ONLY door to item data (local + remote)
│  │     ├─ auth_repository.dart
│  │     ├─ drive_repository.dart    # From Chats (+ My Files if P1)
│  │     ├─ events_repository.dart   # P2 only
│  │     └─ chat_repository.dart     # P4 only
│  ├─ features/
│  │  ├─ auth/                       # login, sign-up
│  │  ├─ messenger/
│  │  │  ├─ chat_list/               # list with pinned Saved Messages
│  │  │  ├─ saved/                   # Saved Messages chat, bubbles, composer, search, filters
│  │  │  ├─ item_editor/             # full create/edit screen
│  │  │  ├─ item_detail/
│  │  │  ├─ share/                   # share confirm screen
│  │  │  └─ direct_chat/             # P4 only
│  │  ├─ drive/
│  │  ├─ calendar/
│  │  ├─ profile/
│  │  └─ common/                     # coming_soon, error_view, offline_banner, loading
│  └─ services/
│     ├─ share_intent_service.dart
│     ├─ connectivity_service.dart
│     └─ notification_service.dart   # P2/P3 only
├─ supabase/
│  └─ schema.sql                     # exact copy of section 7.2
├─ test/                             # unit tests for utils + repository logic
├─ docs/
│  └─ screenshots/                   # security-test and app screenshots for the README
├─ env.example.json                  # {"SUPABASE_URL": "", "SUPABASE_ANON_KEY": ""}
├─ .gitignore                        # must include env.json
└─ README.md
```

**App id:** `com.snag.snag` (what `flutter create --org com.snag snag` produces) · **App label:** `Snag`.

---

## 6. Architecture

```text
Android Share Sheet ──(shared text / URL)──┐
                                            ▼
FLUTTER APP (Snag)
 ├─ Screens ....... Auth · Messenger · Saved · Detail · Editor · Share · Drive · Calendar · Profile
 ├─ State ......... Riverpod providers
 ├─ Repositories .. the ONLY door to data
 │    ├─ Local .... drift: cache, drafts, (P3) reminders
 │    └─ Remote ... supabase_flutter
 └─ Services ...... Share intent · Connectivity · Notifications (P2/P3)
          │  HTTPS + the signed-in user's JWT (anon key only)
          ▼
SUPABASE (free plan)
 ├─ Auth ......... email + password; username in profiles
 ├─ Postgres ..... profiles, items, heartbeat (+ pick tables)   [RLS on every table]
 ├─ Storage ...... chat-files (+ drive if P1)                   [user-ID folder policy]
 └─ Realtime ..... messages (P4 only)                           [respects RLS]
          ▲
UptimeRobot ── reads the heartbeat table every 5 minutes (prevents the free-plan pause)
```

### 6.1 Rules
- **Screens never talk to drift or Supabase directly.** They call repositories through Riverpod providers.
- **Stage 1:** repositories use drift only.
- **Stage 2+:** Supabase is the source of truth; drift is a per-user cache. The UI always renders from drift streams, so the inbox opens instantly and stays readable offline.

### 6.2 Read path (Stage 2+)
`ItemsRepository.refresh()` runs after login, on app resume, on pull-to-refresh, and when connectivity returns:
1. Fetch all of the user's items from Supabase (newest `updated_at` first).
2. In one drift transaction: upsert every fetched row and delete local rows for this user that are no longer remote.
3. On failure, keep the cache, show a banner with **Retry**.

### 6.3 Write path (Stage 2+)
- **Create:** validate → upload the attachment first (if any) → insert the row → on success upsert into drift and delete the draft. If the insert fails after an upload, delete the uploaded file. On failure keep the form open, show the error and **Retry**; the draft stays saved.
- **Update / archive / restore:** conditional update `where id = :id and version = :loadedVersion`, returning the row.
  - 1 row returned → upsert into drift.
  - 0 rows → re-fetch the item. If it is gone: "This item no longer exists." If it has a newer version: dialog **"Changed on another device — Overwrite / Keep theirs"**. Overwrite repeats the update with the new version.
- **Delete:** confirm dialog → delete the row → then delete its storage file (best effort; log failures) → remove from drift.
- **Offline:** writes are disabled with the message "You're offline — your draft is saved." Drafts persist. (A full offline sync queue is out of scope; the brief does not require one.)

### 6.4 Conflict policy (for the README)
The most recently saved version wins. Before replacing a newer server version, the user sees a warning and chooses.

### 6.5 Logout
Sign out → delete all drift rows, drafts and cached attachment files → go to login.

---

## 7. Data model

### 7.1 Local database (drift)

**Stage 1 — schema version 1**

| Table | Columns |
|---|---|
| `items` | `id` TEXT PK (uuid v4) · `type` TEXT (`note`/`link`/`image`) · `title` TEXT · `content` TEXT? · `url` TEXT? · `localAttachmentPath` TEXT? · `attachmentMime` TEXT? · `tags` TEXT (JSON array) · `archived` BOOL · `createdAt` DATETIME · `updatedAt` DATETIME |
| `drafts` | `key` TEXT PK (`new`, `share`, or an item id) · `payload` TEXT (JSON of the form) · `updatedAt` DATETIME |

**Stage 2 — schema version 2 (migration)**
- `items`: add `ownerId` TEXT, `remotePath` TEXT?, `version` INT (default 1).
- The migration **deletes Stage 1 local-only items** (they have no owner). Record this in the README under "Known decisions".
- All queries filter by the signed-in user's `ownerId`.

**P3 only — schema version 3**
| Table | Columns |
|---|---|
| `reminders` | `id` INT PK (also the notification id) · `itemId` TEXT · `remindAt` DATETIME |

### 7.2 Supabase setup script (`supabase/schema.sql`)

Copy this **exactly** into `supabase/schema.sql`. The human runs **Section A** in the Supabase SQL Editor during Stage 2, and only the chosen pick's section (B, C or E) later. This script was tested on PostgreSQL 16 with Supabase-style `auth`/`storage` stand-ins: owners can read and write their own rows and files; other users get zero rows or a permission error for items, events, drive files, storage objects and chats.

```sql
-- =====================================================================
-- Snag: Supabase setup script
-- Run in Supabase Dashboard -> SQL Editor.
-- Section A is required (Stages 2-3 + Mission C + Drive "From Chats").
-- Sections B, C, E are OPTIONAL: run only the one chosen as the Oct 11 pick.
-- (Mission D reminders are device-local and need no SQL.)
-- =====================================================================

-- =====================================================================
-- SECTION A: CORE (required)
-- =====================================================================

-- A1. Keep updated_at current on any table that uses this trigger.
create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

-- A2. Profiles: one row per user, holds the unique username.
create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  username text not null unique check (username ~ '^[a-z0-9_]{3,20}$'),
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

create policy "profiles: signed-in users can read usernames"
  on public.profiles for select
  to authenticated
  using (true);

create policy "profiles: users update only their own row"
  on public.profiles for update
  to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

-- A3. Create the profile automatically at sign-up.
-- The app passes the username in sign-up metadata: data: {'username': 'ayaz_01'}
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, username)
  values (new.id, lower(new.raw_user_meta_data ->> 'username'));
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- A4. Username availability check (callable before sign-up).
create or replace function public.is_username_available(p_username text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select not exists (
    select 1 from public.profiles where username = lower(p_username)
  );
$$;

revoke all on function public.is_username_available(text) from public;
grant execute on function public.is_username_available(text) to anon, authenticated;

-- A5. Items: everything saved in the "Saved Messages" chat.
create table public.items (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  type text not null check (type in ('note', 'link', 'image')),
  title text not null default '' check (char_length(title) <= 200),
  content text check (char_length(content) <= 20000),
  url text check (char_length(url) <= 2048),
  attachment_path text,
  attachment_mime text check (
    attachment_mime in ('image/jpeg', 'image/png', 'image/webp', 'application/pdf')
  ),
  tags text[] not null default '{}' check (cardinality(tags) <= 10),
  archived boolean not null default false,
  version integer not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index items_owner_updated_idx on public.items (owner_id, updated_at desc);

-- Every update: refresh updated_at and bump version (used for conflict detection).
create or replace function public.items_before_update()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  new.version := old.version + 1;
  return new;
end;
$$;

create trigger items_before_update
  before update on public.items
  for each row execute function public.items_before_update();

alter table public.items enable row level security;

create policy "items: owner can read"
  on public.items for select
  to authenticated
  using (owner_id = (select auth.uid()));

create policy "items: owner can insert"
  on public.items for insert
  to authenticated
  with check (
    owner_id = (select auth.uid())
    and (attachment_path is null
         or split_part(attachment_path, '/', 1) = (select auth.uid())::text)
  );

create policy "items: owner can update"
  on public.items for update
  to authenticated
  using (owner_id = (select auth.uid()))
  with check (
    owner_id = (select auth.uid())
    and (attachment_path is null
         or split_part(attachment_path, '/', 1) = (select auth.uid())::text)
  );

create policy "items: owner can delete"
  on public.items for delete
  to authenticated
  using (owner_id = (select auth.uid()));

-- A6. Heartbeat: a one-row public table that UptimeRobot reads to keep the project active.
create table public.heartbeat (
  id smallint primary key check (id = 1),
  note text not null default 'UptimeRobot keep-alive'
);

insert into public.heartbeat (id) values (1);

alter table public.heartbeat enable row level security;

create policy "heartbeat: anyone can read"
  on public.heartbeat for select
  to anon, authenticated
  using (true);

-- A7. Private bucket for Saved Messages attachments. Path: <user_id>/<item_id>/<file_name>
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'chat-files', 'chat-files', false, 10485760,
  array['image/jpeg', 'image/png', 'image/webp', 'application/pdf']
)
on conflict (id) do nothing;

create policy "chat-files: owner can read"
  on storage.objects for select
  to authenticated
  using (bucket_id = 'chat-files'
         and (storage.foldername(name))[1] = (select auth.uid())::text);

create policy "chat-files: owner can upload"
  on storage.objects for insert
  to authenticated
  with check (bucket_id = 'chat-files'
              and (storage.foldername(name))[1] = (select auth.uid())::text);

create policy "chat-files: owner can update"
  on storage.objects for update
  to authenticated
  using (bucket_id = 'chat-files'
         and (storage.foldername(name))[1] = (select auth.uid())::text)
  with check (bucket_id = 'chat-files'
              and (storage.foldername(name))[1] = (select auth.uid())::text);

create policy "chat-files: owner can delete"
  on storage.objects for delete
  to authenticated
  using (bucket_id = 'chat-files'
         and (storage.foldername(name))[1] = (select auth.uid())::text);

-- =====================================================================
-- SECTION B (OPTIONAL PICK): Drive "My Files"
-- =====================================================================

create table public.drive_files (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  name text not null check (char_length(name) between 1 and 200),
  storage_path text not null unique,
  mime_type text not null check (
    mime_type in ('image/jpeg', 'image/png', 'image/webp', 'application/pdf')
  ),
  size_bytes bigint not null check (size_bytes > 0 and size_bytes <= 10485760),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index drive_files_owner_created_idx on public.drive_files (owner_id, created_at desc);

create trigger drive_files_set_updated_at
  before update on public.drive_files
  for each row execute function public.set_updated_at();

alter table public.drive_files enable row level security;

create policy "drive_files: owner can read"
  on public.drive_files for select
  to authenticated
  using (owner_id = (select auth.uid()));

create policy "drive_files: owner can insert"
  on public.drive_files for insert
  to authenticated
  with check (owner_id = (select auth.uid())
              and split_part(storage_path, '/', 1) = (select auth.uid())::text);

create policy "drive_files: owner can update"
  on public.drive_files for update
  to authenticated
  using (owner_id = (select auth.uid()))
  with check (owner_id = (select auth.uid())
              and split_part(storage_path, '/', 1) = (select auth.uid())::text);

create policy "drive_files: owner can delete"
  on public.drive_files for delete
  to authenticated
  using (owner_id = (select auth.uid()));

-- Private bucket for Drive uploads. Path: <user_id>/<file_id>/<file_name>
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'drive', 'drive', false, 10485760,
  array['image/jpeg', 'image/png', 'image/webp', 'application/pdf']
)
on conflict (id) do nothing;

create policy "drive: owner can read"
  on storage.objects for select
  to authenticated
  using (bucket_id = 'drive'
         and (storage.foldername(name))[1] = (select auth.uid())::text);

create policy "drive: owner can upload"
  on storage.objects for insert
  to authenticated
  with check (bucket_id = 'drive'
              and (storage.foldername(name))[1] = (select auth.uid())::text);

create policy "drive: owner can update"
  on storage.objects for update
  to authenticated
  using (bucket_id = 'drive'
         and (storage.foldername(name))[1] = (select auth.uid())::text)
  with check (bucket_id = 'drive'
              and (storage.foldername(name))[1] = (select auth.uid())::text);

create policy "drive: owner can delete"
  on storage.objects for delete
  to authenticated
  using (bucket_id = 'drive'
         and (storage.foldername(name))[1] = (select auth.uid())::text);

-- =====================================================================
-- SECTION C (OPTIONAL PICK): Calendar v1
-- =====================================================================

create table public.events (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  title text not null check (char_length(title) between 1 and 200),
  note text check (char_length(note) <= 5000),
  starts_at timestamptz not null,
  ends_at timestamptz,
  remind_minutes_before integer check (remind_minutes_before between 0 and 10080),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (ends_at is null or ends_at >= starts_at)
);

create index events_owner_starts_idx on public.events (owner_id, starts_at);

create trigger events_set_updated_at
  before update on public.events
  for each row execute function public.set_updated_at();

alter table public.events enable row level security;

create policy "events: owner can read"
  on public.events for select
  to authenticated
  using (owner_id = (select auth.uid()));

create policy "events: owner can insert"
  on public.events for insert
  to authenticated
  with check (owner_id = (select auth.uid()));

create policy "events: owner can update"
  on public.events for update
  to authenticated
  using (owner_id = (select auth.uid()))
  with check (owner_id = (select auth.uid()));

create policy "events: owner can delete"
  on public.events for delete
  to authenticated
  using (owner_id = (select auth.uid()));

-- =====================================================================
-- SECTION E (OPTIONAL PICK): 1:1 chats (text only in v1)
-- =====================================================================

create table public.conversations (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now()
);

create table public.conversation_members (
  conversation_id uuid not null references public.conversations (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  joined_at timestamptz not null default now(),
  last_read_at timestamptz not null default now(),
  primary key (conversation_id, user_id)
);

create index conversation_members_user_idx on public.conversation_members (user_id);

create table public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations (id) on delete cascade,
  sender_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  body text not null check (char_length(body) between 1 and 4000),
  created_at timestamptz not null default now()
);

create index messages_conversation_created_idx on public.messages (conversation_id, created_at);

-- Membership check used by every chat policy. SECURITY DEFINER avoids
-- recursive RLS on conversation_members.
create or replace function public.is_conversation_member(p_conversation_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.conversation_members m
    where m.conversation_id = p_conversation_id
      and m.user_id = (select auth.uid())
  );
$$;

revoke all on function public.is_conversation_member(uuid) from public, anon;
grant execute on function public.is_conversation_member(uuid) to authenticated;

alter table public.conversations enable row level security;
alter table public.conversation_members enable row level security;
alter table public.messages enable row level security;

create policy "conversations: members can read"
  on public.conversations for select
  to authenticated
  using (public.is_conversation_member(id));

create policy "conversation_members: members can read"
  on public.conversation_members for select
  to authenticated
  using (public.is_conversation_member(conversation_id));

create policy "conversation_members: update own read marker"
  on public.conversation_members for update
  to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

create policy "messages: members can read"
  on public.messages for select
  to authenticated
  using (public.is_conversation_member(conversation_id));

create policy "messages: members can send as themselves"
  on public.messages for insert
  to authenticated
  with check (sender_id = (select auth.uid())
              and public.is_conversation_member(conversation_id));

-- Start (or reopen) a 1:1 chat by username. The only way to create conversations.
create or replace function public.start_direct_chat(p_username text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := (select auth.uid());
  v_other uuid;
  v_conversation uuid;
begin
  if v_me is null then
    raise exception 'Not signed in';
  end if;

  select p.id into v_other
  from public.profiles p
  where p.username = lower(p_username);

  if v_other is null then
    raise exception 'No user with that username';
  end if;

  if v_other = v_me then
    raise exception 'You cannot start a chat with yourself';
  end if;

  select m1.conversation_id into v_conversation
  from public.conversation_members m1
  join public.conversation_members m2 on m2.conversation_id = m1.conversation_id
  where m1.user_id = v_me and m2.user_id = v_other
  limit 1;

  if v_conversation is not null then
    return v_conversation;
  end if;

  insert into public.conversations default values returning id into v_conversation;

  insert into public.conversation_members (conversation_id, user_id)
  values (v_conversation, v_me), (v_conversation, v_other);

  return v_conversation;
end;
$$;

revoke all on function public.start_direct_chat(text) from public, anon;
grant execute on function public.start_direct_chat(text) to authenticated;

-- Live delivery of new messages to members (Realtime respects the RLS above).
alter publication supabase_realtime add table public.messages;
```

### 7.3 Storage paths
| Bucket | Path | Used by |
|---|---|---|
| `chat-files` | `<user_id>/<item_id>/<file_name>` | Saved Messages attachments (Mission C), shown read-only in Drive "From Chats" |
| `drive` (P1) | `<user_id>/<file_id>/<file_name>` | Drive "My Files" |

- Both buckets are **private**, max **10 MB** per file, types: JPEG, PNG, WebP, PDF.
- Show files with **signed URLs valid for 1 hour**, created on demand and cached in memory for the session.
- Keep a local copy of attachments the user added on this device (`<app documents>/attachments/<item_id>.<ext>`) so they display offline.

---

## 8. Screens, routes and UX

### 8.1 Navigation
- Bottom bar (after login): **Messenger** (default) · **Drive** · **Calendar**. Use a go_router `StatefulShellRoute` so each tab keeps its own navigation stack.
- Top bar on each tab: title + avatar button → Profile.
- **Stage 1 has no login**: the app opens straight to Messenger.

| Route | Screen |
|---|---|
| `/login`, `/signup` | Auth (Stage 2+) |
| `/messenger` | Chat list: **Saved Messages pinned first** (+ direct chats if P4) |
| `/messenger/saved` | Saved Messages chat |
| `/item/new` | Full create screen (query `type=note|link|image`) |
| `/item/:id` | Item detail |
| `/item/:id/edit` | Full edit screen |
| `/share` | Share confirm screen |
| `/drive` | Drive: **From Chats** section + **My Files** (P1, otherwise "Coming soon") |
| `/calendar` | Calendar (P2, otherwise "Coming soon") |
| `/chat/:conversationId` | Direct chat (P4) |
| `/profile` | Username, email, app version, log out |

**Auth redirect (Stage 2+):** signed out → `/login` (remember the target route and pending share); signed in on `/login` → `/messenger`.

**Deep links:** `/item/:id` must handle an id that is deleted or belongs to someone else by showing **"This item no longer exists"** with a button back to Saved Messages.

### 8.2 Saved Messages chat
- Bubbles in a chat layout, **newest at the bottom**, auto-scrolled to the latest. **Date separators:** Today, Yesterday, then `Oct 3`.
- **Note bubble:** text; notes that look like code (contain `{`, `;` or start with 4 spaces) use a monospace font.
- **Link bubble:** title, domain, URL; tap opens the link externally.
- **Image bubble:** thumbnail (local file if present, else signed URL); tap opens full screen.
- **PDF (Mission C):** file chip with name and size; tap opens it externally via a signed URL.
- Tags show as small chips under the bubble; the time shows in the corner.
- **Composer** at the bottom: text field + send, 📎 (attach image; PDF from Mission C), and an expand button that opens `/item/new` with the typed text. Send rule: if the text contains a URL → create a **link** item; otherwise a **note**.
- **Long-press menu:** Edit · Tags · Archive (or Restore) · Delete · Copy · (P3) Remind me.
- **Top bar:** search field; filter chips **All · Notes · Links · Images**; tag filter (bottom sheet listing the user's tags); **Archived** toggle.
- **Empty states:** no items → "Nothing snagged yet — share a link from Chrome to start." No results → "No matches. Try another word or clear the filters."
- Pull to refresh (Stage 2+).

### 8.3 Create / edit screen (required by the brief)
Type selector (Note / Link / Image), title, content or URL, tag chips with suggestions (`dsa`, `placement`, `project`, `notes` plus the user's existing tags), attachment picker, Save. Unsaved changes are stored in `drafts` on every change (debounced 500 ms) and restored when the screen reopens. Leaving with unsaved changes asks "Discard changes?".

### 8.4 Detail screen
Full content, large preview, tags, created and updated dates, and actions: Open link · Edit · Archive/Restore · Delete (· Remind me in P3).

### 8.5 Share confirm screen
Prefilled from the share: type, title, URL or text, tags. **Save** creates the item and opens Saved Messages scrolled to it; **Cancel** returns to where the user was.

### 8.6 Drive tab
- **From Chats (Mission C):** grid of non-archived items that have an attachment, newest first. Image tiles show thumbnails; PDF tiles show a PDF icon and name. Tap → preview with **"Go to message"** (→ `/item/:id`). **Read-only: no rename, no delete.**
- **My Files:** P1, otherwise "Coming soon".

### 8.7 Profile
Username, email, app version, **Log out** (with confirmation).

---

## 9. Validation and edge-case rules

| Field / case | Rule |
|---|---|
| Username | `^[a-z0-9_]{3,20}$`, input lowercased; checked with `is_username_available` before sign-up |
| Password | at least 8 characters; show/hide toggle |
| Email | basic format check before calling Supabase |
| Title | trimmed, max 200 chars; if empty → auto-title |
| Auto-title | link → domain without `www.` (e.g. `github.com`); note → first line, max 60 chars + `…`; image → `Image · Oct 3, 14:05` |
| Note content | required for notes, max 20,000 chars; whitespace-only is empty |
| URL | must parse as `http` or `https` with a host; `www.site.com` → prepend `https://`; max 2,048 chars |
| Tags | trim, strip a leading `#`, lowercase, allowed `[a-z0-9_-]`, 1–30 chars, deduplicated, max 10 per item |
| Image | required for image items; compress on pick (`maxWidth: 1600`, `imageQuality: 80`); max 10 MB |
| PDF | `.pdf` only, max 10 MB, else "PDF must be 10 MB or smaller" |
| Very long text | never overflows the layout; bubbles clamp to 12 lines with "Show more" |
| Deleted / foreign item | "This item no longer exists" (identical for both) |
| No internet | offline banner; reads from cache; writes disabled with the draft kept |
| Wrong credentials | "Wrong email or password." |
| Email already used | "An account with this email already exists." |
| Server error / timeout | "Couldn't reach Snag's server." + Retry |

---

## 10. Build stages

Each stage lists tasks, then an **acceptance checklist**. Commit after every task. Tag the repo at the end of each stage.

### Stage 0 — Project setup (Oct 1)
1. `flutter create --org com.snag --platforms android snag`; set the Android app label to **Snag**.
2. Add Stage 1 packages only: flutter_riverpod, go_router, drift (+ its current setup packages), path_provider, uuid, image_picker, url_launcher.
3. Create the folder structure from section 5, `env.example.json`, and add `env.json` to `.gitignore`.
4. Theme (Material 3, seed `#0F766E`, light + dark), router, bottom bar with **Messenger · Drive · Calendar**.
5. Messenger shows the chat list with the pinned **Saved Messages** tile. Drive and Calendar show "Coming soon".
6. README skeleton with the section headings from section 13.

**Checklist:** app runs on an emulator · three tabs work · `flutter analyze` is clean · first commits pushed to a **public** GitHub repo.

### Stage 1 — Saved Messages, local only (Oct 1–3)
1. drift tables `items` + `drafts` (schema v1) and queries: watch items with filters (search text, type, tag, archived), get by id, insert, update, delete, archive/restore, list distinct tags.
2. `url_utils`, `title_utils`, `tag_utils` implementing section 9, with unit tests.
3. `ItemsRepository` (local only).
4. Saved Messages chat UI (section 8.2): bubbles, date separators, composer + send rule, image attach (copy the picked file into `<app documents>/attachments/`), long-press menu, search, filters, tag filter, Archived toggle, empty states.
5. Create/edit screen with drafts (8.3) and detail screen (8.4).
6. Delete confirmation.

**Checklist (the brief's own tests):**
- [ ] Create a note, a link and an image item; each shows the right bubble.
- [ ] Add tags; search by title, content, URL and tag; filter by type and tag.
- [ ] Edit an item; `updatedAt` changes.
- [ ] Archive → disappears from the inbox; Restore from Archived → returns.
- [ ] Delete asks for confirmation, then removes the item.
- [ ] **Kill and relaunch the app: all items, tags, archived states and images are still there.**
- [ ] Empty note, whitespace, 20,000 characters, emoji-only text and an invalid URL are all handled without crashing.
- [ ] A half-typed item survives closing the editor and reopening it.

**Tag:** `v1-stage1`.

### Stage 2 — Accounts, cloud sync, security (Oct 4–7)
**Human first (section 11, steps 1–4):** Supabase project, run **Section A**, turn off email confirmation, create `env.json`.

1. Add supabase_flutter and connectivity_plus. Initialise Supabase in `main.dart` from `env.dart`. If either value is empty, show a clear "App not configured" screen instead of crashing.
2. Sign-up: username (live availability check via `is_username_available`), email, password → `signUp` with `data: {'username': ...}`. Login, logout, session persistence, auth redirect, error messages from section 9.
3. drift migration to schema v2 (section 7.1).
4. Remote items data source + repository read/write paths, conflict dialog and logout wipe (sections 6.2–6.5).
5. Image attachments upload to `chat-files` at `<user_id>/<item_id>/<file_name>`; display local copy first, else a signed URL.
6. Offline banner, loading states, error views with **Retry**, pull to refresh.
7. Profile screen.

**Checklist:**
- [ ] Sign up two accounts (A and B) on two emulators.
- [ ] A's items appear on a second device after signing in as A.
- [ ] Wrong password → "Wrong email or password."; taken username → blocked before sign-up.
- [ ] Airplane mode: cached items still show; saving shows the offline message; the draft survives; reconnect → Retry works.
- [ ] Editing the same item on two devices triggers the conflict dialog.
- [ ] Logout → local data gone → logging in as B shows only B's items.
- [ ] **Security tests in section 12.2 all return nothing for B.** Screenshots saved in `docs/screenshots/`.

**Tag:** `v2-stage2`.

### Stage 3 — Share into Snag (Oct 8–9)
1. `AndroidManifest.xml`: set `MainActivity` `android:launchMode="singleTask"`; add one intent filter for `android.intent.action.SEND` with `mimeType="text/*"`. (No image/file filters in v1.)
2. `ShareIntentService`: read the initial share (app was closed) **and** listen to the stream (app already open); call the package's reset after handling. Follow the package's current example for how shared text arrives (⚠️ confirm against the receive_sharing_intent docs for the installed version).
3. Parsing: first `http(s)` URL in the text → **link** (title = the remaining text if meaningful, else auto-title); no URL → **note**; empty or whitespace → snackbar "Nothing to save from this share"; any unexpected type or exception → the same snackbar, never a crash.
4. If signed out: store the share in `drafts` (key `share`), go to login, then continue to `/share`.
5. Share confirm screen (8.5).

**Checklist:**
- [ ] Share from **Chrome, YouTube, WhatsApp, Instagram** → correct link item saved.
- [ ] Works when Snag was closed (cold start) and when it was open (warm start); no duplicate saves.
- [ ] Plain text share → note. Empty share → message, no crash.
- [ ] Signed-out share → login → confirm screen → saved.

### Stage 3b — Mission C + Drive "From Chats" (Oct 10)
1. Attach PDFs (file_picker, PDF only, 10 MB max) on the create/edit screen; upload to `chat-files`; PDF chip in bubbles; open via signed URL.
2. Replace or remove an attachment: after a successful update, delete the old storage object.
3. Deleting an item deletes its file.
4. Drive tab **From Chats** grid (8.6), read-only, with "Go to message".

**Checklist:**
- [ ] Image and PDF attachments upload, display and open on a second device.
- [ ] B cannot get A's file (section 12.2, storage test).
- [ ] Deleting the item removes the file from the bucket (check in the Supabase dashboard).
- [ ] From Chats shows exactly the attachments from Saved Messages; nothing there can be renamed or deleted.

**Tag:** `v3-stage3` — **this completes the guaranteed scope.**

### Oct 11 pick — build exactly ONE (ask the user which)

**P1 · Drive "My Files"** (human runs **Section B**)
- Upload images/PDFs from Drive to `drive` at `<user_id>/<file_id>/<file_name>` + a `drive_files` row.
- List (newest first) with preview, download/open, **rename** (name only), **delete** (row + object), and "My Files: X MB used".
- Checklist: files sync across devices; B sees none of A's files; chat attachments never appear in My Files.

**P2 · Calendar v1** (human runs **Section C**)
- Add flutter_local_notifications + timezone. Request the Android 13+ notification permission when the user first sets a reminder. Use **inexact** scheduling (no exact-alarm permission). Follow the package's Android setup so scheduled notifications survive a reboot.
- Create/edit/delete events (title, date, start time, optional end time, note, reminder: none / at start / 10 min / 1 hour / 1 day before).
- **Upcoming** list grouped by Today, Tomorrow, then dates. Past events are hidden behind a "Show past" toggle.
- Notifications are scheduled on save, cancelled on edit/delete, and re-scheduled on login for events in the next 30 days. Tapping opens the event; if deleted → "This event no longer exists".
- Checklist: events sync across devices; B sees none of A's events; a reminder fires and opens the event.

**P3 · Mission D — reminders on saved items** (no SQL)
- Same notification setup as P2. drift table `reminders` (schema v3).
- "Remind me" from the long-press menu and the detail screen: Tomorrow 9:00 · In 3 days 9:00 · In 7 days 9:00 · Custom.
- Notification payload = `/item/<id>`. Tapping opens the item; deleted item → "This item no longer exists". Deleting an item cancels its reminders. The detail screen shows the active reminder with **Cancel**.
- README note: reminders are stored on the device where they were set.
- Checklist: a reminder fires and opens the item; after deleting the item, tapping an old notification shows the "no longer exists" screen.

**P4 · 1:1 chats, text only** (human runs **Section E**)
- Chat list: Saved Messages pinned first, then conversations with the other user's username, last message, time and unread count (messages after my `last_read_at` not sent by me).
- New chat button → username → `start_direct_chat` RPC → open the chat; show the RPC's error text for unknown users and self-chats.
- Chat screen: messages newest at the bottom, composer (1–4,000 chars), **Realtime** subscription for new messages in that conversation, links tappable, `last_read_at` updated when viewing.
- Images in direct chats are **Later**.
- Checklist: A and B chat live on two emulators; C cannot read the conversation (section 12.2); Saved Messages stays private.

### Stage 4 — Ship (Oct 12–13): no new features
1. App icon (the human can create one with Android Studio → Image Asset).
2. Build: `flutter build apk --release --dart-define-from-file=env.json`. (The anon key ends up inside the APK — expected, it is public by design; RLS protects the data.) ⚠️ Check how the release build is signed in `android/app/build.gradle(.kts)`; the default template signing is acceptable for a sideloaded APK.
3. Install on a **physical phone** and re-run every checklist above.
4. Create GitHub Release `v1.0.0` with the APK attached.
5. Finish the README (section 13), add the architecture diagram and the demo-video link.
6. Confirm the UptimeRobot monitor is green.

**Tag:** `v1.0.0`.

---

## 11. Manual steps for the human (Claude Code cannot do these)

1. **Create the Supabase project** (free plan) in the region closest to you. Save the database password somewhere safe.
2. **Authentication → Providers → Email:** enabled. **Turn off "Confirm email"** so reviewers can sign up instantly (note this trade-off in the README).
3. **SQL Editor:** paste and run **Section A** of `supabase/schema.sql`. Later, run only the section for your Oct 11 pick (B, C or E).
4. **Project Settings → API:** copy the **Project URL** and the **anon / publishable key** into `env.json`:
   ```json
   { "SUPABASE_URL": "paste Project URL", "SUPABASE_ANON_KEY": "paste anon key" }
   ```
   Never copy the service_role / secret key.
5. **UptimeRobot** (free, personal/non-commercial use): add an **HTTP(s)** monitor with a 5-minute interval and this URL (with your real values):
   `SUPABASE_URL/rest/v1/heartbeat?select=id&apikey=SUPABASE_ANON_KEY`
   - Open the URL in a browser first. Expected result: `[{"id":1}]`.
   - ⚠️ UNVERIFIED: that Supabase accepts the key as a URL parameter. If the browser shows a missing-API-key error, ask Claude Code for a GitHub Actions workflow that runs the same request with an `apikey` header every 3 days instead.
6. **GitHub:** public repository; confirm `env.json` is **not** committed (`git status` must not list it).
7. **Devices:** two Android emulators (Account A and B) and one physical Android phone for share-sheet and release testing.

---

## 12. Testing

### 12.1 Stage checklists
Run the checklist at the end of every stage in section 10. Record anything that fails under "Known issues" in the README.

### 12.2 Security tests (Stage 2, 3b and P4) — the brief's "Account A vs Account B" scenario

Run in a terminal with `curl` (and `jq` for reading JSON; without jq, copy values by hand). Take a screenshot of each result for `docs/screenshots/`.

```bash
# Values from env.json
SUPABASE_URL=$(jq -r .SUPABASE_URL env.json)
ANON_KEY=$(jq -r .SUPABASE_ANON_KEY env.json)

# Account B's login (use B's real email and password)
EMAIL_B="b.test@example.com"
read -s -p "Password for B: " PASSWORD_B; echo
TOKEN_B=$(curl -s "$SUPABASE_URL/auth/v1/token?grant_type=password" \
  -H "apikey: $ANON_KEY" -H "Content-Type: application/json" \
  -d "{\"email\":\"$EMAIL_B\",\"password\":\"$PASSWORD_B\"}" | jq -r .access_token)

# An item id and file path that belong to Account A (copy from Supabase → Table Editor → items)
read -p "Account A item id: " A_ITEM_ID
read -p "Account A attachment_path: " A_FILE_PATH

# 1. B reads A's item by id → expect []
curl -s "$SUPABASE_URL/rest/v1/items?id=eq.$A_ITEM_ID&select=*" \
  -H "apikey: $ANON_KEY" -H "Authorization: Bearer $TOKEN_B"

# 2. B edits A's item → expect []
curl -s -X PATCH "$SUPABASE_URL/rest/v1/items?id=eq.$A_ITEM_ID" \
  -H "apikey: $ANON_KEY" -H "Authorization: Bearer $TOKEN_B" \
  -H "Content-Type: application/json" -H "Prefer: return=representation" \
  -d '{"title":"hacked"}'

# 3. B deletes A's item → expect []
curl -s -X DELETE "$SUPABASE_URL/rest/v1/items?id=eq.$A_ITEM_ID" \
  -H "apikey: $ANON_KEY" -H "Authorization: Bearer $TOKEN_B" \
  -H "Prefer: return=representation"

# 4. No login at all → expect []
curl -s "$SUPABASE_URL/rest/v1/items?select=id" -H "apikey: $ANON_KEY"

# 5. B asks for a signed link to A's file → expect an error, no URL
curl -s -X POST "$SUPABASE_URL/storage/v1/object/sign/chat-files/$A_FILE_PATH" \
  -H "apikey: $ANON_KEY" -H "Authorization: Bearer $TOKEN_B" \
  -H "Content-Type: application/json" -d '{"expiresIn":60}'
```

- ⚠️ UNVERIFIED: the exact storage signing endpoint (test 5). If it returns a routing error rather than an access error, repeat the test inside the app instead: signed in as B, call `createSignedUrl` for A's path from a debug-only button and confirm it fails. Remove the button afterwards.
- Finally, confirm in the Table Editor that A's item is unchanged.
- **P4:** repeat test 1 against `messages?conversation_id=eq.<A and B's conversation id>` using a third account C → expect `[]`.

### 12.3 Automated tests
Unit tests for `url_utils`, `title_utils`, `tag_utils`, the share-text parser and the repository's conflict handling (with a fake remote).

---

## 13. README (what reviewers need)

1. **What Snag is** (2–3 sentences) + screenshots.
2. **Stage reached:** Stage 3 + Mission C (+ the pick).
3. **Tech stack** and why (Flutter, Supabase, drift, Riverpod).
4. **How to run:** Flutter version, `env.json` from `env.example.json`, `flutter run --dart-define-from-file=env.json`, plus the APK link.
5. **Architecture diagram** (draw.io): Share Sheet → Flutter app (screens → repositories → drift cache / Supabase client) → Supabase (Auth, Postgres with RLS, Storage) ← UptimeRobot.
6. **How authentication works:** Supabase email + password; username in `profiles`; session kept on the device; email confirmation off (and why).
7. **Where data is stored:** Postgres tables, the private `chat-files` bucket, the drift cache on the phone (wiped on logout).
8. **How one user's data is protected:** RLS policies (owner-only), storage folder policy, anon key only; the section 12.2 screenshots.
9. **Key decisions:** repository pattern, cache + conflict policy, Stage 1 → 2 migration clears local-only items, Saved Messages as the brief's inbox, tab separation, keep-alive.
10. **Known issues** and **what's next** (section 14).
11. **Demo video** link (60–90 s): share a YouTube link → it appears in Saved Messages → sign in on a second phone → it's there → Account B gets nothing.

---

## 14. Later (do NOT build before Oct 13)

Group chats, channels, voice notes, calls, typing indicators, online status, read receipts, push notifications, replies, forwarding, reactions, end-to-end encryption, images in direct chats · Drive folders, move, any file type, trash, file sharing · Calendar month/week grid, recurring events, invites · Google Calendar sync (first an "Add to Google Calendar" button, then a one-way "Also save to Google Calendar" toggle via the phone's calendar) · public share links (Mission B) · data export and account deletion (Mission E) · link preview cards · sharing images into Snag · iOS · Google/OAuth login.

---

## 15. Kickoff prompts (copy-paste into Claude Code)

1. **"Read plan.md completely. Then do Stage 0 only. Run its checklist, commit, and stop with a short report."**
2. **"Continue with Stage 1 from plan.md. Work task by task, commit after each task, run the Stage 1 checklist, tag v1-stage1, and stop."**
3. **"I've created the Supabase project, run Section A of supabase/schema.sql, turned off email confirmation and created env.json. Continue with Stage 2."**
4. **"Continue with Stage 3 (Share into Snag)."**
5. **"Continue with Stage 3b (Mission C + Drive From Chats). Tag v3-stage3 when the checklist passes."**
6. **"My Oct 11 pick is P1 / P2 / P3 / P4 (keep one). I've run its SQL section if it has one. Build only that pick."**
7. **"Continue with Stage 4 (ship). No new features."**

**If something breaks:** "Something is broken: [what you see]. Re-read the relevant sections of plan.md, find the cause, fix it with the smallest change, and re-run that stage's checklist."
