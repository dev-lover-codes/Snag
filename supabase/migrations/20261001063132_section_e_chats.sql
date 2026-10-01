-- Section E: 1:1 chats (copied from schema.sql, plus the hardening below)
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
