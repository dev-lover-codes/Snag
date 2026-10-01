-- Section B: Drive "My Files" (copied from schema.sql)
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

