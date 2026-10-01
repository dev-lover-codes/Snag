-- Section C: Calendar v1 (copied from schema.sql)
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

