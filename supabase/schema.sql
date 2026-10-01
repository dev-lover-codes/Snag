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

-- E-hardening: members may only move their own read marker. Without this,
-- the row-level update policy above would also let a user rewrite
-- conversation_id on their own membership row and join another chat.
revoke update on public.conversation_members from authenticated, anon;
grant update (last_read_at) on public.conversation_members to authenticated;

-- Chat list for the signed-in user. SECURITY INVOKER: every read below goes
-- through the RLS policies above, so it can only ever see the caller's chats.
create or replace function public.my_chats()
returns table (
  conversation_id uuid,
  other_user_id uuid,
  other_username text,
  last_body text,
  last_at timestamptz,
  last_sender_id uuid,
  unread integer
)
language sql
stable
security invoker
set search_path = ''
as $$
  select
    me.conversation_id,
    other.user_id,
    p.username,
    last_msg.body,
    coalesce(last_msg.created_at, c.created_at),
    last_msg.sender_id,
    (
      select count(*)::integer
      from public.messages m
      where m.conversation_id = me.conversation_id
        and m.created_at > me.last_read_at
        and m.sender_id <> me.user_id
    )
  from public.conversation_members me
  join public.conversations c on c.id = me.conversation_id
  join public.conversation_members other
    on other.conversation_id = me.conversation_id and other.user_id <> me.user_id
  left join public.profiles p on p.id = other.user_id
  left join lateral (
    select m.body, m.created_at, m.sender_id
    from public.messages m
    where m.conversation_id = me.conversation_id
    order by m.created_at desc
    limit 1
  ) last_msg on true
  where me.user_id = (select auth.uid())
  order by coalesce(last_msg.created_at, c.created_at) desc;
$$;

revoke all on function public.my_chats() from public, anon;
grant execute on function public.my_chats() to authenticated;

-- E-hardening: clients choose only the conversation and the text;
-- id, sender and time always come from the database defaults.
revoke insert on public.messages from authenticated, anon;
grant insert (conversation_id, body) on public.messages to authenticated;

-- =====================================================================
-- SECTION E2: 1:1 chat attachments + deleting your own messages
-- =====================================================================
alter table public.messages
  add column attachment_path text,
  add column attachment_mime text check (
    attachment_mime in ('image/jpeg', 'image/png', 'image/webp', 'application/pdf')
  ),
  add column attachment_name text check (char_length(attachment_name) between 1 and 200),
  add column attachment_size bigint check (attachment_size > 0 and attachment_size <= 10485760);

alter table public.messages alter column body set default '';
alter table public.messages drop constraint messages_body_check;
alter table public.messages add constraint messages_body_check
  check (char_length(body) <= 4000);
alter table public.messages add constraint messages_content_check
  check (char_length(body) >= 1 or attachment_path is not null);
alter table public.messages add constraint messages_attachment_complete_check
  check ((attachment_path is null) = (attachment_mime is null));

-- Attachments must live in the message's own conversation folder.
drop policy "messages: members can send as themselves" on public.messages;
create policy "messages: members can send as themselves"
  on public.messages for insert
  to authenticated
  with check (sender_id = (select auth.uid())
              and public.is_conversation_member(conversation_id)
              and (attachment_path is null
                   or split_part(attachment_path, '/', 1) = conversation_id::text));

create policy "messages: senders can delete their own"
  on public.messages for delete
  to authenticated
  using (sender_id = (select auth.uid()));

revoke insert on public.messages from authenticated, anon;
grant insert (conversation_id, body, attachment_path, attachment_mime, attachment_name, attachment_size)
  on public.messages to authenticated;
grant delete on public.messages to authenticated;

-- Folder check for storage: "<conversation_id>/..." where the caller is a member.
-- Text input so a malformed folder name is simply "not a member", never an error.
create or replace function public.is_conversation_folder_member(p_folder text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_folder ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
     and exists (
       select 1
       from public.conversation_members m
       where m.conversation_id = p_folder::uuid
         and m.user_id = (select auth.uid())
     );
$$;

revoke all on function public.is_conversation_folder_member(text) from public, anon;
grant execute on function public.is_conversation_folder_member(text) to authenticated;

-- Private bucket for chat attachments. Path: <conversation_id>/<uuid>/<file_name>
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'direct-files', 'direct-files', false, 10485760,
  array['image/jpeg', 'image/png', 'image/webp', 'application/pdf']
)
on conflict (id) do nothing;

create policy "direct-files: members can read"
  on storage.objects for select
  to authenticated
  using (bucket_id = 'direct-files'
         and public.is_conversation_folder_member((storage.foldername(name))[1]));

create policy "direct-files: members can upload"
  on storage.objects for insert
  to authenticated
  with check (bucket_id = 'direct-files'
              and public.is_conversation_folder_member((storage.foldername(name))[1]));

-- Only the uploader can remove their file (used when deleting a message).
create policy "direct-files: uploader can delete"
  on storage.objects for delete
  to authenticated
  using (bucket_id = 'direct-files' and owner_id = (select auth.uid())::text);

-- Chat list preview: show "📎 name" for attachment-only messages.
create or replace function public.my_chats()
returns table (
  conversation_id uuid,
  other_user_id uuid,
  other_username text,
  last_body text,
  last_at timestamptz,
  last_sender_id uuid,
  unread integer
)
language sql
stable
security invoker
set search_path = ''
as $$
  select
    me.conversation_id,
    other.user_id,
    p.username,
    case
      when last_msg.id is null then null
      when last_msg.body <> '' then last_msg.body
      else '📎 ' || coalesce(last_msg.attachment_name, 'Attachment')
    end,
    coalesce(last_msg.created_at, c.created_at),
    last_msg.sender_id,
    (
      select count(*)::integer
      from public.messages m
      where m.conversation_id = me.conversation_id
        and m.created_at > me.last_read_at
        and m.sender_id <> me.user_id
    )
  from public.conversation_members me
  join public.conversations c on c.id = me.conversation_id
  join public.conversation_members other
    on other.conversation_id = me.conversation_id and other.user_id <> me.user_id
  left join public.profiles p on p.id = other.user_id
  left join lateral (
    select m.id, m.body, m.attachment_name, m.created_at, m.sender_id
    from public.messages m
    where m.conversation_id = me.conversation_id
    order by m.created_at desc
    limit 1
  ) last_msg on true
  where me.user_id = (select auth.uid())
  order by coalesce(last_msg.created_at, c.created_at) desc;
$$;
