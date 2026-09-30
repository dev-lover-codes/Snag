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

