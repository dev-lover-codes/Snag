// Sign in with a username instead of an email.
//
// The username is resolved to the account's email on the server, so the
// email is never sent to the browser (no "look up someone's email" leak).
// Unknown usernames and wrong passwords get the same answer.
import { createClient } from 'npm:@supabase/supabase-js@2';

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, 'Content-Type': 'application/json' },
  });

const USERNAME = /^[a-z0-9_]{3,20}$/;
const url = Deno.env.get('SUPABASE_URL')!;
const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!;
const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const noSession = { auth: { persistSession: false, autoRefreshToken: false } };

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  if (req.method !== 'POST') return json(405, { error: 'method_not_allowed' });

  let username = '';
  let password = '';
  try {
    const body = await req.json();
    username = String(body?.username ?? '').trim().replace(/^@/, '').toLowerCase();
    password = String(body?.password ?? '');
  } catch {
    return json(400, { error: 'invalid_request' });
  }
  if (!USERNAME.test(username) || password.length < 1 || password.length > 72) {
    return json(400, { error: 'invalid_credentials' });
  }

  const admin = createClient(url, serviceKey, noSession);
  const { data: profile } = await admin
    .from('profiles')
    .select('id')
    .eq('username', username)
    .maybeSingle();
  if (!profile) return json(400, { error: 'invalid_credentials' });

  const { data: found } = await admin.auth.admin.getUserById(profile.id);
  const email = found?.user?.email;
  if (!email) return json(400, { error: 'invalid_credentials' });

  // Sign in with the normal password flow, so every Auth rule still applies.
  const anon = createClient(url, anonKey, noSession);
  const { data, error } = await anon.auth.signInWithPassword({ email, password });
  if (error || !data.session) {
    if (error?.code === 'email_not_confirmed') {
      return json(400, { error: 'email_not_confirmed' });
    }
    if (error?.status === 429) return json(429, { error: 'rate_limited' });
    return json(400, { error: 'invalid_credentials' });
  }
  return json(200, {
    access_token: data.session.access_token,
    refresh_token: data.session.refresh_token,
  });
});
