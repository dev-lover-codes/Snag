-- 1:1 chats: image/PDF attachments and deleting your own messages.

-- A message is text, an attachment, or both.
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
