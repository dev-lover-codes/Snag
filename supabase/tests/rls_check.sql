-- Snag privacy proof (Account A vs B vs C), safe to run on the live project.
-- Paste into Supabase → SQL Editor and run. It creates three throw-away users,
-- acts as each of them through RLS, then RAISES the results as an error so the
-- whole transaction is rolled back: nothing is left behind.
--
-- Expected: every "B ..." count is 0 except "B (member) msgs=1" and
-- "B my_chats=1"; every "C ..." count is 0; every write attempt is "blocked";
-- anon counts are 0.
do $$
declare
  a uuid := gen_random_uuid(); b uuid := gen_random_uuid(); c uuid := gen_random_uuid();
  item uuid := gen_random_uuid(); dfile uuid := gen_random_uuid();
  conv uuid; conv_ca uuid; n int; r text := '';
begin
  insert into auth.users (id, email, raw_user_meta_data, aud, role)
  values (a, 'rlsa@test.invalid', '{"username":"rls_test_a"}', 'authenticated', 'authenticated'),
         (b, 'rlsb@test.invalid', '{"username":"rls_test_b"}', 'authenticated', 'authenticated'),
         (c, 'rlsc@test.invalid', '{"username":"rls_test_c"}', 'authenticated', 'authenticated');
  insert into storage.objects (bucket_id, name, owner)
  values ('drive', a::text || '/' || dfile::text || '/f.pdf', a),
         ('chat-files', a::text || '/' || item::text || '/f.pdf', a);

  -- As A: create one of everything.
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  insert into public.items (id, type, title, content) values (item, 'note', 'secret', 'A only');
  insert into public.drive_files (id, name, storage_path, mime_type, size_bytes)
    values (dfile, 'f.pdf', a::text || '/' || dfile::text || '/f.pdf', 'application/pdf', 10);
  insert into public.events (title, starts_at) values ('A event', now() + interval '1 day');
  conv := public.start_direct_chat('rls_test_b');
  insert into public.messages (conversation_id, body) values (conv, 'hi B');
  begin insert into public.messages (conversation_id, body, sender_id) values (conv, 'forged', b);
    r := r || 'A forge sender: ALLOWED(BAD); ';
  exception when others then r := r || 'A forge sender: blocked; '; end;

  -- As B: try to reach A's data.
  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role', 'authenticated')::text, true);
  select count(*) into n from public.items where id = item; r := r || 'B read A item=' || n || '; ';
  update public.items set title = 'hacked' where id = item; get diagnostics n = row_count; r := r || 'B update A item=' || n || '; ';
  delete from public.items where id = item; get diagnostics n = row_count; r := r || 'B delete A item=' || n || '; ';
  select count(*) into n from public.drive_files; r := r || 'B drive rows=' || n || '; ';
  update public.drive_files set name = 'x' where id = dfile; get diagnostics n = row_count; r := r || 'B rename A file=' || n || '; ';
  select count(*) into n from storage.objects where owner = a; r := r || 'B sees A objects=' || n || '; ';
  begin insert into public.drive_files (name, storage_path, mime_type, size_bytes)
    values ('x', a::text || '/x/x.pdf', 'application/pdf', 1); r := r || 'B row in A folder: ALLOWED(BAD); ';
  exception when others then r := r || 'B row in A folder: blocked; '; end;
  select count(*) into n from public.events; r := r || 'B events=' || n || '; ';
  select count(*) into n from public.messages where conversation_id = conv; r := r || 'B (member) msgs=' || n || '; ';
  select count(*) into n from public.my_chats(); r := r || 'B my_chats=' || n || '; ';

  -- As C (outsider): try to read or join A and B's chat.
  perform set_config('request.jwt.claims', json_build_object('sub', c, 'role', 'authenticated')::text, true);
  select count(*) into n from public.messages where conversation_id = conv; r := r || 'C msgs in A-B=' || n || '; ';
  select count(*) into n from public.conversation_members where conversation_id = conv; r := r || 'C members of A-B=' || n || '; ';
  begin insert into public.messages (conversation_id, body) values (conv, 'intrude'); r := r || 'C send to A-B: ALLOWED(BAD); ';
  exception when others then r := r || 'C send to A-B: blocked; '; end;
  conv_ca := public.start_direct_chat('rls_test_a');
  begin update public.conversation_members set conversation_id = conv where conversation_id = conv_ca and user_id = c;
    r := r || 'C hijack membership: ALLOWED(BAD); ';
  exception when others then r := r || 'C hijack membership: blocked; '; end;
  begin perform public.start_direct_chat('rls_test_c'); r := r || 'self chat: ALLOWED(BAD); ';
  exception when others then r := r || 'self chat: ' || sqlerrm || '; '; end;

  -- Not signed in.
  perform set_config('role', 'anon', true);
  perform set_config('request.jwt.claims', '{"role":"anon"}', true);
  select count(*) into n from public.items; r := r || 'anon items=' || n || '; ';
  select count(*) into n from public.messages; r := r || 'anon msgs=' || n || '; ';
  select count(*) into n from public.events; r := r || 'anon events=' || n || '; ';
  select count(*) into n from public.drive_files; r := r || 'anon drive=' || n;

  raise exception 'RLS_RESULTS (rolled back): %', r;
end $$;
