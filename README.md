# Snag

**Snag it now, find it later.** Snag is a personal save-for-later app for Android. Its Messenger tab has a pinned **Saved Messages** chat where every note, link, image or PDF you save becomes a bubble. Items sync to your account, so they're the same on every device you sign in on. The **Drive** tab shows your chat attachments in one place.

<img src="docs/screenshots/login.png" width="260" alt="Snag login screen">

**Download:** [latest APK from GitHub Releases](https://github.com/dev-lover-codes/Snag/releases/latest) · **Website:** [snag-teal.vercel.app](https://snag-teal.vercel.app)

## Stage reached

Stage 3 + Mission C (the guaranteed scope), plus all four extras: P1 Drive "My Files", P2 Calendar, P3 Mission D reminders and P4 1:1 chats.

## Features by tab

**Messenger**
- **Saved Messages** (pinned): notes, links, images and PDFs; create, view, open, edit, delete, archive and restore; tags; search; type, tag and archive filters; date separators; drafts.
- **Remind me** on any saved item (Tomorrow / In 3 days / In 7 days at 9:00, or a custom time). The notification opens the item. Reminders live on this device only and never appear in Calendar.
- **1:1 chats** (text only): start a chat by username; live delivery through Supabase Realtime; unread counts; tappable links.
- **Share into Snag** from Android's share menu, whether the app is closed or already open.

**Drive**
- **From Chats:** every image and PDF attached in Saved Messages. Read-only.
- **My Files:** a private drive. Upload images and PDFs (up to 10 MB), preview, rename, delete, and see "X MB used". Kept completely separate from chats.

**Calendar**
- Upcoming events grouped by Today, Tomorrow, then dates, with a "Show past events" toggle.
- Events have a title, date, start time, optional end time, note and reminder (none, at start, 10 min, 1 hour or 1 day before).
- Reminders are inexact local notifications that survive a reboot. They're rescheduled after login for the next 30 days and cancelled on logout. Tapping one opens the event.

## Tech stack

| Layer | Choice | Why |
|---|---|---|
| App | Flutter + Material 3 | One codebase, fast UI work, a good Android share-intent plugin |
| State | Riverpod | Testable providers; screens stay free of data code |
| Navigation | go_router | Auth redirect, deep links (`/item/:id`), one stack per tab |
| Local cache | drift (SQLite) | Typed queries and reactive streams; the inbox opens instantly and works offline |
| Backend | Supabase (Auth, Postgres + RLS, Storage) | Free plan; privacy enforced in the database, so no custom server |

## How to run

1. Flutter 3.47 (stable) and an Android device or emulator.
2. Copy `env.example.json` to `env.json` and fill in the Supabase **Project URL** and **anon / publishable key**. `env.json` is gitignored.
3. `flutter pub get`
4. `flutter run --dart-define-from-file=env.json`

Release APK: `flutter build apk --release --dart-define-from-file=env.json`.

Website (same codebase, hosted on Vercel): every push to `main` builds and deploys it automatically. The settings are in [docs/vercel-setup.md](docs/vercel-setup.md). To try it locally:

```bash
flutter run -d chrome --dart-define-from-file=env.json
```

The website shares the same account, data and privacy rules as the app. Browsers have no share sheet or local notifications, so share-into-Snag and "Remind me" are Android-only. Calendar reminders set on the website ring on your phone. Attachments upload straight from the browser, and the offline cache runs in SQLite compiled to WebAssembly (`web/sqlite3.wasm`, `web/drift_worker.js`). On wide screens the app is centered at phone width. The anon key ends up inside the APK. That key is public by design; Row Level Security protects the data.

If either value is missing, the app shows an "App not configured" screen instead of crashing.

## Architecture

```text
Android Share Sheet ──(shared text / URL)──┐
                                            ▼
FLUTTER APP (Snag)
 ├─ Screens ....... Auth · Messenger · Saved · Chats · Detail · Editor · Share · Drive · Calendar · Profile
 ├─ State ......... Riverpod providers
 ├─ Repositories .. the ONLY door to data
 │    ├─ Local .... drift: per-user cache, drafts, item reminders
 │    └─ Remote ... supabase_flutter
 └─ Services ...... Share intent · Connectivity · Notifications
          │  HTTPS + the signed-in user's JWT (anon key only)
          ▼
SUPABASE (free plan)
 ├─ Auth ......... email + password; username in profiles
 ├─ Postgres ..... profiles, items, drive_files, events,
 │                 conversations, members, messages, heartbeat   [RLS on every table]
 ├─ Storage ...... chat-files, drive (private)                   [user-ID folder policy]
 └─ Realtime ..... new messages, members only                    [respects RLS]
          ▲
UptimeRobot ── reads the heartbeat table every 5 minutes (stops the free-plan pause)
```

Screens never touch drift or Supabase directly. Supabase is the source of truth, and drift is a cache for the signed-in user. The UI always renders from drift streams.

## How authentication works

- Supabase email + password. Sign-up also asks for a username (`^[a-z0-9_]{3,20}$`), checked live with the `is_username_available` RPC. A database trigger stores it in `profiles`.
- The session is kept on the device by `supabase_flutter`, so you stay signed in after restarting the app.
- Email confirmation is **off**, so reviewers can sign up and use the app right away. Trade-off: email addresses are not verified.

## Where data is stored

| Where | What |
|---|---|
| Postgres `items` | Every saved item: id, type, title, content/URL, tags, created/updated dates, archived, version, owner |
| Postgres `profiles` | Username per user |
| Storage `chat-files` (private) | Attachments at `<user_id>/<item_id>/<file_name>`; shown through signed URLs valid for 1 hour |
| Postgres `drive_files` + Storage `drive` (private) | Drive "My Files" records and files at `<user_id>/<file_id>/<file_name>` |
| Postgres `events` | Calendar events |
| Postgres `conversations`, `conversation_members`, `messages` | 1:1 chats; Realtime publishes new `messages` to members only |
| drift on the phone | Cache of the signed-in user's items, unsaved drafts and item reminders; **wiped on logout** |
| Android notification scheduler | Pending event and item reminders; **cancelled on logout** |

## How one user's data is protected

- **Row Level Security** on every table: a user can only select, insert, update or delete rows where `owner_id = auth.uid()`.
- **Storage policies** on `chat-files` and `drive`: the first folder of the path must equal the caller's user id. A `drive_files` row can't point into another user's folder.
- **Chats:** only members can read or send messages, and only as themselves. Conversations can only be created through `start_direct_chat`. Members can update nothing on their membership row except their own read marker.
- The app ships only the anon key, never the service-role key.
- A deleted item and someone else's item look the same: **"This item no longer exists."** The same applies to events and chats.
- **Proof:** [`supabase/tests/rls_check.sql`](supabase/tests/rls_check.sql) creates throw-away accounts A, B and C, acts as each through RLS, and rolls everything back. Last run on the live project: B gets 0 of A's items, files, stored objects and events; every write attempt by B is blocked; C can't read, send to or join A and B's chat; anonymous requests get nothing. The REST tests for Account A vs B are in plan.md §12.2, with screenshots in `docs/screenshots/`.

## Key decisions

- **Repository pattern:** `ItemsRepository` is the only way into data, which keeps screens simple and makes the conflict logic unit-testable with a fake remote.
- **Cache + conflict policy:** updates are conditional on `version`. If another device saved first, you choose **Overwrite** or **Keep theirs**. The most recently saved version wins, but never silently.
- **Offline:** cached items stay readable; writes are disabled with "You're offline — your draft is saved."
- **Stage 1 → 2 migration** clears local-only items, since they had no owner.
- **Saved Messages is the brief's inbox.** Tabs keep separate data; Drive → From Chats only *shows* chat attachments.
- **Keep-alive:** UptimeRobot pings `heartbeat` so the free Supabase project isn't paused.

## Known issues

- The release APK is signed with the default debug key (fine for sideloading). An update built on another machine may need the old version uninstalled first.
- My Files, Calendar and chats need a connection: they load from Supabase and aren't cached offline the way Saved Messages is.
- Item reminders are stored on the device where they were set.
- Android may deliver reminders a few minutes late, because they're scheduled inexactly (no exact-alarm permission).

## What's next

Group chats, push notifications, link previews, Drive folders, public share links, data export and account deletion, and sharing images into Snag. See plan.md §14.

## Demo video

_Link to be added._
