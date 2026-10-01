# 📋 Snag — Complete Project Report
### *"Snag it now, find it later"*
> **For someone with zero coding knowledge — everything explained in plain English.**

---

## Table of Contents

1. [What is Snag?](#1-what-is-snag)
2. [Why was it built?](#2-why-was-it-built)
3. [What does it look like to the user?](#3-what-does-it-look-like-to-the-user)
4. [Tech stack — tools & technologies used](#4-tech-stack--tools--technologies-used)
5. [Project folder structure — every file explained](#5-project-folder-structure--every-file-explained)
6. [The app's three tabs — features in detail](#6-the-apps-three-tabs--features-in-detail)
7. [How the app starts up](#7-how-the-app-starts-up)
8. [Screens and navigation](#8-screens-and-navigation)
9. [How data is stored](#9-how-data-is-stored)
10. [How data is protected (security)](#10-how-data-is-protected-security)
11. [The backend (Supabase database)](#11-the-backend-supabase-database)
12. [How sharing from other apps works](#12-how-sharing-from-other-apps-works)
13. [Notifications and reminders](#13-notifications-and-reminders)
14. [Internet connectivity handling](#14-internet-connectivity-handling)
15. [All the rules and validations](#15-all-the-rules-and-validations)
16. [Every code file explained in detail](#16-every-code-file-explained-in-detail)
17. [Third-party packages (external libraries)](#17-third-party-packages-external-libraries)
18. [Tests in the project](#18-tests-in-the-project)
19. [The deployment / shipping setup](#19-the-deployment--shipping-setup)
20. [Known limitations and future plans](#20-known-limitations-and-future-plans)

---

## 1. What is Snag?

**Snag** is a mobile app (built for Android, also runs in a web browser) that lets you **quickly save things you find on the internet** — links, notes, and images — so you can find them again later. Think of it as your personal private inbox for stuff you care about.

The name says it all: **"Snag it now, find it later."**

It is inspired by Telegram (a popular messaging app) in terms of design, but it is a completely original app with its own name, logo, and features. It has **three main sections**:

| Tab | What it does |
|---|---|
| **Messenger** | A chat-style inbox where your saved items appear as messages. Has a "Saved Messages" chat and supports real 1-to-1 chats with other users. |
| **Drive** | A file viewer where you can see all the images and PDFs you've attached to your saved items. You can also upload your own files ("My Files"). |
| **Calendar** | A calendar where you can create personal events, get reminders, and see public holidays. |

---

## 2. Why was it built?

This project was built as a **recruitment task** for a company called BYTE (part of MAIT). The deadline was **October 13, 2026, 11:59 PM IST**. The task was to build a "save-for-later" app — an app where you can save links, notes, and images from around the web and find them again.

The developer went beyond the basic requirement and built a full super-app with Messenger, Drive, and Calendar features.

---

## 3. What does it look like to the user?

### First launch (not logged in):
- You see a **Login screen** with the Snag logo (a teal bookmark icon), fields for email/username and password.
- There's a "New here? Create an account" link that takes you to sign-up.

### After logging in:
- You land on the **Messenger tab** which shows a list with "Saved Messages" pinned at the top.
- A **bottom navigation bar** lets you switch between Messenger, Drive, and Calendar.
- There is a **profile avatar button** in the top-right corner.

### Color scheme and design:
- The main color is **teal** (`#0F766E` — a dark teal/green).
- The app automatically uses **Light or Dark mode** based on your phone's system setting.
- Design follows **Material 3** (Google's modern design system), so it feels like a modern Android app.

---

## 4. Tech stack — tools & technologies used

Think of the "tech stack" as the set of tools the developer chose to build the app with.

| Layer | Tool | What it is in simple terms |
|---|---|---|
| **App framework** | Flutter | A tool made by Google that lets you write one codebase that works on Android, iOS, and web. |
| **Programming language** | Dart | The language Flutter uses. Similar to Java or JavaScript. |
| **UI design system** | Material 3 | Google's set of rules and components for how the app looks. |
| **State management** | Riverpod (flutter_riverpod) | A system that controls what data the app shows and when it updates. |
| **Navigation** | go_router | Manages which "page" or "screen" the app shows and handles URL links. |
| **Local database** | drift (SQLite) | A mini-database stored right on your phone — works even without internet. |
| **Backend / cloud** | Supabase | A cloud service that stores all your data online so you can access it from any device. |
| **Cloud database** | Supabase Postgres | A powerful database (like Excel but for software) in the cloud. |
| **Cloud file storage** | Supabase Storage | Like Google Drive but private — stores your images and PDFs. |
| **Real-time messaging** | Supabase Realtime | Makes 1-to-1 chat messages appear instantly without refreshing. |
| **Keep-alive** | UptimeRobot | A free service that "pings" the server every 5 minutes so it doesn't go to sleep (Supabase free plan pauses inactive projects). |

---

## 5. Project folder structure — every file explained

> **Think of this like a filing cabinet.** Each drawer (folder) has a purpose. Here is every file and what it does.

```
myapp/
├── lib/                        ← All the Dart (app) code lives here
│   ├── main.dart               ← The very first file that runs when you open the app
│   ├── app/                    ← App-wide setup
│   │   ├── app.dart            ← Creates the app widget and sets up listeners
│   │   ├── providers.dart      ← All the "data providers" (explained below)
│   │   ├── router.dart         ← All the screen routes (what URL goes to what screen)
│   │   ├── theme.dart          ← Colors, fonts, button styles for the whole app
│   │   └── web_frame.dart      ← Special wrapper when running in a web browser
│   ├── core/                   ← Shared tools used everywhere
│   │   ├── env.dart            ← Reads secret API keys from env.json
│   │   ├── errors.dart         ← Converts technical errors to friendly messages
│   │   ├── result.dart         ← A "success or failure" type used by data functions
│   │   └── utils/              ← Small helper tools
│   │       ├── date_utils.dart     ← Date formatting helpers
│   │       ├── share_parser.dart   ← Reads shared text to find URLs or notes
│   │       ├── tag_utils.dart      ← Cleans and normalizes tags
│   │       ├── title_utils.dart    ← Auto-generates titles for items
│   │       ├── url_utils.dart      ← Validates and normalizes URLs
│   │       └── validators.dart     ← Validates usernames, emails, passwords
│   ├── data/                   ← Everything to do with storing and fetching data
│   │   ├── local/              ← On-device (offline) database
│   │   │   ├── app_database.dart   ← The SQLite database definition and all queries
│   │   │   ├── app_database.g.dart ← Auto-generated code (don't edit this!)
│   │   │   └── tables.dart         ← Defines what columns the local database has
│   │   ├── remote/             ← Cloud (internet) data sources
│   │   │   ├── auth_remote.dart    ← Login/signup with Supabase
│   │   │   ├── chats_remote.dart   ← 1-to-1 chat messages from Supabase
│   │   │   ├── drive_remote.dart   ← Drive "My Files" from Supabase
│   │   │   ├── events_remote.dart  ← Calendar events from Supabase
│   │   │   ├── holidays_remote.dart ← Public holidays from Supabase
│   │   │   ├── items_remote.dart   ← Saved items from Supabase
│   │   │   └── storage_remote.dart ← File upload/download from Supabase Storage
│   │   └── repositories/       ← The "managers" that connect local + cloud data
│   │       ├── auth_repository.dart    ← Handles all login/signup logic
│   │       ├── chats_repository.dart   ← Handles chat data
│   │       ├── drive_repository.dart   ← Handles Drive file data
│   │       ├── events_repository.dart  ← Handles calendar events
│   │       ├── items_repository.dart   ← THE MAIN ONE: handles all saved items
│   │       └── reminders_repository.dart ← Handles item reminder notifications
│   ├── features/               ← Each screen/feature of the app
│   │   ├── auth/
│   │   │   └── auth_screens.dart   ← Login screen + Sign-up screen
│   │   ├── calendar/
│   │   │   ├── calendar_screen.dart    ← The full Calendar tab
│   │   │   ├── event_detail_screen.dart ← View a single calendar event
│   │   │   ├── event_editor_screen.dart ← Create or edit a calendar event
│   │   │   └── month_view.dart         ← The monthly grid calendar widget
│   │   ├── common/
│   │   │   └── common_widgets.dart ← Shared small UI pieces (loading spinner, error view, etc.)
│   │   ├── drive/
│   │   │   ├── drive_screen.dart   ← The Drive tab (From Chats + My Files)
│   │   │   └── my_files_tab.dart   ← The "My Files" section of Drive
│   │   ├── messenger/
│   │   │   ├── attachment_picker.dart  ← Lets you pick an image or PDF to attach
│   │   │   ├── attachment_views.dart   ← Displays images and PDF chips in bubbles
│   │   │   ├── item_actions.dart       ← Handles archive, delete, tag actions
│   │   │   ├── chat_list/
│   │   │   │   └── chat_list_screen.dart ← The main Messenger screen (list of chats)
│   │   │   ├── direct/
│   │   │   │   └── chat_screen.dart     ← A 1-to-1 chat screen
│   │   │   ├── item_detail/
│   │   │   │   └── item_detail_screen.dart ← Full-screen view of one saved item
│   │   │   ├── item_editor/
│   │   │   │   └── item_editor_screen.dart ← Create or edit a saved item
│   │   │   └── saved/
│   │   │       ├── message_bubble.dart  ← The chat bubble for each saved item
│   │   │       ├── saved_filter.dart    ← Filter/search logic for Saved Messages
│   │   │       └── saved_screen.dart    ← The "Saved Messages" chat screen
│   │   └── profile/
│   │       ├── profile_avatar.dart   ← The small circular profile icon in the top bar
│   │       └── profile_screen.dart   ← Your profile page (username, email, log out)
│   └── services/               ← Background services that run alongside the app
│       ├── connectivity_service.dart  ← Detects if you're online or offline
│       ├── notification_service.dart  ← Schedules and fires local notifications
│       └── share_intent_service.dart  ← Receives content shared from other apps
├── supabase/                   ← Backend database setup
│   ├── config.toml             ← Supabase project configuration
│   ├── schema.sql              ← The SQL script that creates all database tables
│   ├── functions/
│   │   └── login-with-username/ ← A server-side function for username login
│   │       └── index.ts
│   ├── migrations/             ← Database change history (what was added when)
│   │   ├── 20260930180000_section_a_core.sql      ← Core tables
│   │   ├── 20261001063058_section_b_drive.sql     ← Drive tables
│   │   ├── 20261001063102_section_c_calendar.sql  ← Calendar tables
│   │   ├── 20261001063132_section_e_chats.sql     ← Chat tables
│   │   ├── 20261001155853_chat_attachments.sql    ← Chat file attachments
│   │   ├── 20261001172509_holidays.sql            ← Holidays table
│   │   └── 20261001172528_refresh_holidays.sql    ← Holiday refresh function
│   └── tests/
│       └── rls_check.sql       ← Security tests for the database
├── test/                       ← Automated tests
│   ├── features_test.dart      ← Tests for app features
│   ├── holidays_login_test.dart ← Tests for holiday and login features
│   ├── items_repository_test.dart ← Tests for the items data manager
│   ├── month_view_test.dart    ← Tests for the calendar month view
│   ├── utils_test.dart         ← Tests for utility functions
│   └── widget_test.dart        ← Tests for UI widgets
├── web/                        ← Files needed for the web browser version
│   ├── index.html              ← The web page that loads the app
│   ├── manifest.json           ← Makes the web app installable (PWA)
│   ├── drift_worker.js         ← A web worker so the database runs in background
│   ├── sqlite3.wasm            ← SQLite compiled for the browser
│   └── icons/
│       ├── snag.svg            ← The app icon (SVG format)
│       └── snag-maskable.svg   ← A version of the icon that adapts to circles/squares
├── tool/
│   └── refresh_holidays.mjs   ← A script to update holiday data in the database
├── pubspec.yaml                ← The app's "recipe list" — lists all packages used
├── pubspec.lock                ← Exact versions of every package (auto-generated)
├── plan.md                     ← The full original build plan / spec document
├── README.md                   ← Instructions for anyone who wants to run the app
├── vercel.json                 ← Configuration for deploying the web version to Vercel
├── package.json                ← Node.js packages (for Supabase CLI tools)
└── env.example.json            ← Example of what env.json looks like (with empty values)
```

---

## 6. The app's three tabs — features in detail

### Tab 1: Messenger 💬

This is the **default tab** when you open the app. It shows a list of chats.

#### Chat List Screen (`chat_list_screen.dart`)
- Shows **"Saved Messages"** pinned at the very top (your private inbox).
- Shows any **1-to-1 chats** you have with other Snag users below.
- A **"New chat"** button lets you start a chat with someone by their username.
- Tapping "Saved Messages" takes you into your saved items inbox.

#### Saved Messages Screen (`saved_screen.dart`)
This is the **heart of the app**. It looks like a chat window but instead of messages from other people, it shows **your own saved items** as chat bubbles.

**What's in this screen:**
- **Chat bubbles** for every saved item — newest at the bottom (like a real chat app).
- **Date separators** between messages: "Today", "Yesterday", then dates like "Oct 3".
- **Filter chips** at the top: All / Notes / Links / Images — tap to filter by type.
- **Search bar**: tap the search icon to search by title, text, URL, or tag.
- **Tag filter**: tap the tag icon to filter by a specific tag (a bottom sheet pops up listing all your tags).
- **Archive toggle**: switch between inbox and archived items.
- **Sync banner**: shows if data is being refreshed or if there's a sync error.
- **Pull to refresh**: pull down to fetch latest data from the cloud.
- **Empty states**: friendly messages when there's nothing to show.
- **Composer at the bottom**: type a quick note or paste a link and tap send. Has three buttons:
  - 📎 Attach image or PDF
  - ↗️ Expand to full editor
  - ▶️ Send

**Long-press on a bubble gives a menu with:**
- Edit
- Tags
- Archive / Restore
- Delete (asks for confirmation)
- Copy
- Remind me

#### Message Bubble (`message_bubble.dart`)
Each saved item appears as a bubble. The bubble looks different depending on the type:

- **Note bubble**: Shows the text. If the note looks like code (contains `{`, `;` or starts with 4 spaces), it uses a monospace (code) font. Long notes are clamped to 12 lines with a "Show more" button.
- **Link bubble**: Shows the title, the website domain name, and the URL. Tapping opens the link in your browser.
- **Image bubble**: Shows a thumbnail of the image. Tapping opens the full-size image.
- **PDF bubble**: Shows a file chip with the filename and size. Tapping opens the PDF externally.
- Tags appear as small chips below the bubble.
- The time (e.g., "14:05") appears in the corner.

#### Item Editor Screen (`item_editor_screen.dart`)
Used for **creating new items**, **editing existing ones**, and the **share confirm screen**.

Has three modes:
1. **Create** (`/item/new`): blank form with type selector (Note / Link / Image).
2. **Edit** (`/item/:id/edit`): form prefilled with existing data.
3. **Share** (`/share`): form prefilled from content shared from another app.

**Form fields:**
- **Type selector**: a segmented button (Note / Link / Image).
- **Link field** (only for links): URL input with `https://…` hint.
- **Image section** (only for images): pick an image or replace/remove existing.
- **Title**: optional — auto-generated if left blank.
- **Note / Caption / Content**: text area.
- **PDF attachment** (for notes and links): attach a PDF file.
- **Tags**: add tags with suggestions (like autocomplete chips).
- **Save button**: validates everything and saves.

**Draft saving:**
Every time you type (after a 500ms pause), the form is automatically saved as a draft. If you close the app mid-edit, your work is not lost. When you reopen the editor, it restores the draft with a "Restored your unsaved changes" message and a "Discard" option.

**When you leave with unsaved changes**, a dialog appears:
- "Discard" — throws away changes.
- "Keep draft" — saves as draft and leaves.
- "Keep editing" — stays on the screen.

#### Item Detail Screen (`item_detail_screen.dart`)
A full-screen view of one saved item showing:
- Full content / large image preview / PDF chip.
- Tags displayed as chips.
- Created and updated dates.
- Action buttons: Open link, Edit, Archive/Restore, Delete, Remind me.

#### 1-to-1 Chat Screen (`chat_screen.dart`)
- Shows messages between you and one other Snag user.
- **Real-time**: new messages appear instantly without refreshing (Supabase Realtime).
- Composer at the bottom (1–4,000 characters).
- Links in messages are tappable and open in the browser.
- Updates your "last read" timestamp when you view the chat (for unread count).

---

### Tab 2: Drive 📁

The Drive tab shows all your files in one place. It has two sub-tabs:

#### From Chats (read-only)
- Shows a **folder** for your Saved Messages and a folder for each person you chat with.
- Each folder shows the number of files and the latest date.
- Tapping a folder opens a grid of image thumbnails and PDF chips.
- Tapping a file opens a **full preview screen** with:
  - For images: pinch-to-zoom interactive viewer.
  - For PDFs: PDF icon and an "Open" button that opens externally.
  - A "Go to message" button that takes you to that item in Saved Messages.
- **Read-only**: you cannot delete or rename files from here.

#### My Files
- Upload new images or PDFs directly to your private cloud drive.
- See a list of your uploaded files with preview, file name, size.
- Rename files (just the name, not the content).
- Delete files (removes from cloud storage too).
- Shows total storage used.

---

### Tab 3: Calendar 📅

#### Calendar Screen (`calendar_screen.dart`)
Has two view modes (toggle with a segmented button):

**Month View:**
- Shows a full month grid.
- Days with events have a dot indicator.
- Public holidays appear in a special color (red for public holidays, teal for festivals).
- Tapping a day shows that day's events below the calendar (or beside it on wider screens).
- A "Today" button jumps back to today.
- On wide screens (tablets/desktop), the calendar sits on the left and the day agenda on the right.

**Upcoming View:**
- A chronological list of future events grouped by date headers.
- A "Show past" toggle to include past events.
- Each event shows start/end time, title, optional note preview, and a bell icon if a reminder is set.

**Holiday Settings:**
- Tap the globe icon to open a settings panel.
- Toggle holidays on/off by country/region.
- Toggle "Include festivals & observances" on/off.
- Settings are saved on your device.

**Add events:**
- A floating "+ Event" button opens the event editor.

#### Event Editor Screen (`event_editor_screen.dart`)
- Title (required, max 200 chars).
- Date picker.
- Start time picker.
- Optional end time picker.
- Optional notes field (max 5,000 chars).
- Reminder options: None / At start / 10 min before / 1 hour before / 1 day before.
- Save creates the event in the cloud and schedules the notification.

#### Event Detail Screen (`event_detail_screen.dart`)
- Shows the full event: title, date/time, notes, reminder.
- Action buttons: Edit, Delete (with confirmation).
- If a reminder is set, shows it with a "Cancel reminder" button.

---

## 7. How the app starts up

This is what happens the moment you open Snag:

**File: `lib/main.dart`**

1. **`WidgetsFlutterBinding.ensureInitialized()`** — Prepares Flutter to run.
2. **Check if configured**: Reads the Supabase URL and API key from `env.json`. If the file is missing or empty, the app shows a clear "App not configured" screen instead of crashing.
3. **Initialize Supabase**: Connects to the cloud backend.
4. **Create the local database** (`AppDatabase`) — the on-device SQLite database.
5. **Initialize notifications** (`NotificationService`) — sets up local notifications and checks if the app was launched by tapping a notification.
6. **Run the app** inside a `ProviderScope` — this is Riverpod's container that holds all the app's data.

**If the app wasn't configured** (env.json missing/empty):
- `NotConfiguredApp` is shown — a simple screen saying "App not configured" with instructions.

---

## 8. Screens and navigation

**Navigation is managed by `go_router`** — a package that handles screen transitions and URLs.

### Route Table (every screen and its URL)

| URL / Route | Screen Shown |
|---|---|
| `/login` | Login screen |
| `/signup` | Sign-up screen |
| `/messenger` | Chat list (Saved Messages + direct chats) |
| `/messenger/saved` | Saved Messages chat |
| `/item/new` | Create new item screen |
| `/item/:id` | Item detail screen (`:id` is the item's unique ID) |
| `/item/:id/edit` | Edit item screen |
| `/share` | Share confirm screen (from Android share sheet) |
| `/drive` | Drive tab |
| `/calendar` | Calendar tab |
| `/calendar/event/new` | Create event screen |
| `/calendar/event/:id` | Event detail screen |
| `/calendar/event/:id/edit` | Edit event screen |
| `/chat/:conversationId` | 1-to-1 chat screen |
| `/profile` | Profile screen |

### Auth redirect logic (automatic screen selection):
- If you're **not logged in** → any protected route sends you to `/login` (remembering where you wanted to go).
- If you're **logged in** and go to `/login` or `/signup` → redirected to `/messenger`.
- If there's a **pending share** (you shared something from another app) → redirected to `/share`.
- After `/share` is cleared → redirected to `/messenger/saved`.

### Tab navigation (the bottom bar):
The three tabs — Messenger, Drive, Calendar — each maintain their own **navigation stack**. This means if you were deep inside a Messenger sub-screen, switch to Calendar, then come back to Messenger, you'll be right where you left off.

On wide screens (desktop/web), the bottom bar becomes a **side rail** on the left.

### The Home Shell (`_HomeShell` in `router.dart`):
- On **narrow screens** (phones): shows a `NavigationBar` at the bottom with three destinations.
- On **wide screens** (tablets/desktop/web): shows a `NavigationRail` on the left side with a small Snag logo at the top.

---

## 9. How data is stored

Data is stored in **two places simultaneously**:

### On your device (local database — drift/SQLite)

**Think of this like a notebook on your phone.** Even without internet, the app can read this.

**File: `lib/data/local/tables.dart` and `app_database.dart`**

There are two tables in the local database:

#### `Items` table (your saved items)
Every saved note, link, or image is one row in this table:

| Column | Type | What it stores |
|---|---|---|
| `id` | Text (UUID) | A unique ID like `"f7a3b2c1-..."` |
| `ownerId` | Text | The user ID of who owns this item |
| `type` | Text | `"note"`, `"link"`, or `"image"` |
| `title` | Text | The title of the item |
| `content` | Text (optional) | The note text or caption |
| `url` | Text (optional) | The URL for link items |
| `localAttachmentPath` | Text (optional) | Path to the image/PDF file on this device |
| `remotePath` | Text (optional) | Path to the file in Supabase cloud storage |
| `attachmentMime` | Text (optional) | File type: `"image/jpeg"`, `"image/png"`, `"image/webp"`, `"application/pdf"` |
| `tags` | Text (JSON array) | Tags stored as `["flutter", "notes"]` |
| `archived` | Boolean | `true` if archived, `false` if in inbox |
| `version` | Integer | Version number for conflict detection |
| `createdAt` | DateTime | When you saved it |
| `updatedAt` | DateTime | When you last changed it |

#### `Drafts` table (unsaved editor state)
Stores partially completed forms so your work isn't lost:

| Column | What it stores |
|---|---|
| `key` | `"new"` (new item), `"share"` (from share sheet), or an item ID (editing) |
| `payload` | The entire form data as JSON text |
| `updatedAt` | When it was last saved |

#### Database operations available:
- Watch all items for a user (live-updating stream).
- Watch a single item (live-updating stream).
- Get a single item.
- Get all items for a user.
- Upsert (insert or update) an item.
- Delete an item.
- Replace all items for a user (used after cloud sync).
- Save/get/delete drafts.
- **Wipe**: deletes EVERYTHING (called on logout).

### In the cloud (Supabase Postgres)

**Think of this like a shared server everyone can reach.** Your data stays here and syncs to every device you sign in on.

The cloud has:
- `profiles` table — your username linked to your user account.
- `items` table — all your saved items.
- `drive_files` table — files uploaded to "My Files".
- `events` table — calendar events.
- `conversations` and `conversation_members` tables — 1-to-1 chat metadata.
- `messages` table — chat messages.
- `heartbeat` table — a keep-alive row for UptimeRobot.
- `holidays` table — public holiday data by region.

### In Supabase Storage (cloud file storage)

Files (images and PDFs) are stored in private buckets:

| Bucket | Path format | Used for |
|---|---|---|
| `chat-files` | `<user_id>/<item_id>/<filename>` | Saved Messages attachments |
| `drive` | `<user_id>/<file_id>/<filename>` | My Files uploads |
| `direct-files` | `<user_id>/<message_id>/<filename>` | 1-to-1 chat attachments |

- Max file size: **10 MB**.
- Allowed types: JPEG, PNG, WebP, PDF.
- Files are accessed via **signed URLs** (temporary links that expire after 1 hour) for security.

### How sync works (cloud → device):

When you open the app, log in, return from background, pull to refresh, or regain internet:
1. The app asks Supabase for all your items.
2. In one database operation, it replaces the local cache with the cloud data.
3. The UI always reads from the local database (so it's always fast and works offline).
4. If sync fails, a banner shows "Retry".

### How writing works (device → cloud):

**Creating an item:**
1. Validate the form (check all rules).
2. Check if online (if offline, show error and keep draft).
3. Upload the attachment file to Supabase Storage (if any).
4. Insert the item row into Supabase database.
5. If insert fails, delete the uploaded file (cleanup).
6. On success, save to local cache and delete the draft.

**Updating an item:**
- Uses **conditional update**: only updates if the version number matches what you loaded.
- If the server version is newer (someone edited it on another device):
  - 0 rows updated → re-fetch the item.
  - If item is gone: shows "This item no longer exists."
  - If item has a newer version: shows a dialog — **"Changed on another device — Overwrite / Keep theirs"**.

**Deleting an item:**
1. Confirm dialog.
2. Delete the cloud database row.
3. Delete the cloud storage file (best effort — if this fails, it's logged but doesn't block you).
4. Delete the local cache row.
5. Delete the local file on your device.

---

## 10. How data is protected (security)

This is very important — every user's data is completely private.

### Row Level Security (RLS)

Every table in Supabase has **RLS enabled**. This means:
- The database itself enforces who can see what.
- Even if someone bypassed the app and sent a direct request to the database, they would only see their own data.
- It's not just client-side filtering — the server rejects unauthorized requests.

**For the `items` table:**
- You can only SELECT (read), INSERT (create), UPDATE (edit), and DELETE your own items.
- The check is: `owner_id = auth.uid()` — your user ID must match the item's owner ID.

**For storage files:**
- The file path must start with your own user ID.
- Example: only `abc123/...` files are accessible when logged in as user `abc123`.

### Secrets and API keys:
- The **anon (anonymous) key** is included in the app — this is by design and is safe. It only allows actions that RLS permits.
- The **service role / secret key** is NEVER used in the app (it bypasses RLS and would be dangerous).
- Supabase URL and anon key are never written in source code — they're read from `env.json` at build time.

### Security rule — "not found = same as forbidden":
If you try to view an item that doesn't exist OR that belongs to another user, the app shows:
> **"This item no longer exists."**

Both cases look identical. This prevents an attacker from discovering that another user's item exists.

### Security tests:
The project includes a test script (in `plan.md`) using `curl` (a command-line tool) to verify:
1. User B cannot read User A's item → expects empty result.
2. User B cannot edit User A's item → expects empty result.
3. User B cannot delete User A's item → expects empty result.
4. An unauthenticated request cannot read any items → expects empty result.
5. User B cannot get a signed URL for User A's file → expects an error.

### Logout wipes everything locally:
When you log out:
1. The local database is completely wiped (items and drafts deleted).
2. The local attachment files are deleted from the phone's storage.
3. The pending directory (staged files) is deleted.
4. Signed URL cache is cleared.
5. All scheduled notifications are cancelled.

---

## 11. The backend (Supabase database)

**File: `supabase/schema.sql`**

The database was set up by running SQL scripts in the Supabase dashboard. Here's what each section creates:

### Section A (Core — required):

**`set_updated_at` function**: Automatically updates the `updated_at` timestamp whenever a row is modified.

**`profiles` table**: One row per user.
- `id` — matches the Supabase auth user ID.
- `username` — unique, lowercase, 3–20 characters, only letters/numbers/underscores.
- `created_at` — when they signed up.
- **RLS**: Signed-in users can read any username (for the "start chat" feature). Users can only update their own profile.

**`handle_new_user` trigger**: Runs automatically when someone signs up. Takes the `username` from the signup data and creates their profile row. This is a `security definer` function meaning it runs with admin privileges.

**`is_username_available` function**: Returns true/false for whether a username is taken. Called before sign-up to show real-time availability.

**`items` table**: All saved items (see section 9 above for columns). Has:
- An index on `(owner_id, updated_at DESC)` for fast queries.
- A `version` field that increments on every update (for conflict detection).
- RLS: owner can do everything; others see nothing.

**`heartbeat` table**: A single row with ID=1. Anyone (even unauthenticated) can read it. Used by UptimeRobot to keep the project from sleeping.

**`chat-files` storage bucket**: Private bucket for Saved Messages attachments. Max 10 MB. Only JPEG/PNG/WebP/PDF.

### Section B (Optional — Drive "My Files"):

**`drive_files` table**: One row per file uploaded to My Files.
- `id`, `owner_id`, `name`, `storage_path`, `mime_type`, `size_bytes`, `created_at`, `updated_at`.
- RLS: owner only.

**`drive` storage bucket**: Private bucket for My Files uploads.

### Section C (Optional — Calendar):

**`events` table**: One row per calendar event.
- `id`, `owner_id`, `title`, `note`, `starts_at`, `ends_at`, `remind_minutes_before`, `created_at`, `updated_at`.
- Check constraint: `ends_at >= starts_at`.
- Check constraint: `remind_minutes_before between 0 and 10080` (max 1 week).
- RLS: owner only.

**`holidays` table** (from migration): Stores public holiday data from Google Calendar APIs, indexed by region code.

### Section E (Optional — 1-to-1 Chats):

**`conversations` table**: One row per conversation. Just has an ID and creation date.

**`conversation_members` table**: Maps which users are in which conversations. Has a `last_read_at` field for unread count calculations.

**`messages` table**: One row per message.
- `id`, `conversation_id`, `sender_id`, `body`, `created_at`.
- Body: 1–4,000 characters.
- RLS: only members of the conversation can read or send messages.

**`is_conversation_member` function**: A helper function that checks if the current user is in a conversation. Used by all chat RLS policies.

**`start_direct_chat` function**: Creates a new conversation between two users (or returns the existing one). Called by username. Validates:
- You must be signed in.
- The other username must exist.
- You can't chat with yourself.

**Realtime**: The `messages` table is added to Supabase's real-time feed, so new messages push to the app instantly.

---

## 12. How sharing from other apps works

**File: `lib/services/share_intent_service.dart`**

On Android, you can share a link from Chrome, YouTube, WhatsApp, etc. to Snag.

### How it works:
1. The `AndroidManifest.xml` (Android configuration file) tells the system: "Snag can receive text shares."
2. When you tap "Share" in another app and choose Snag, Android sends the text to Snag.
3. The `ShareIntentService` catches this in two cases:
   - **Cold start**: App was closed → app opens fresh, reads the shared text.
   - **Warm start**: App was already open → a stream receives the new share.
4. After reading, calls `reset()` to clear the intent so it's not processed twice.
5. Includes de-duplication: if the exact same text arrives twice within 3 seconds, the second one is ignored.

### What happens with the shared text:

**File: `lib/core/utils/share_parser.dart`**

The shared text is analyzed:
- If it contains an `http://` or `https://` URL → creates a **link** item. Any remaining text (minus the URL) becomes the title.
- If it's text without a URL → creates a **note** item.
- If it's empty or just whitespace → shows a snackbar "Nothing to save from this share". No crash.

### If you're not logged in when sharing:
1. The share text is saved as a draft (`key = "share_incoming"`).
2. You're redirected to `/login`.
3. After logging in, you're redirected to `/share` (the confirm screen).
4. The draft is restored.

### The Share Confirm Screen:
- Shows the prefilled form (type, title, URL/text, tags).
- "Save to Snag" creates the item and takes you to Saved Messages scrolled to it.
- "Cancel" clears the share and goes back.

---

## 13. Notifications and reminders

**File: `lib/services/notification_service.dart`**

### What notifications are used for:
1. **Calendar event reminders** — fires X minutes before an event (as configured by the user).
2. **Saved item reminders** — set via long-press menu → "Remind me". Options: Tomorrow 9:00 / In 3 days 9:00 / In 7 days 9:00 / Custom.

### How they work:
- Uses the `flutter_local_notifications` package.
- Notifications are **inexact** (no exact-alarm permission needed — better for battery).
- Notifications survive phone reboots (the plugin includes a boot receiver).
- The payload of each notification is an app route like `/item/abc123` or `/calendar/event/xyz`.

### When the app starts:
- Checks if the app was launched by tapping a notification.
- If yes, navigates to that route after the app is ready.

### While the app is running:
- A stream listens for notification taps and navigates to the appropriate screen.

### On login:
- Calendar events in the next 30 days are re-scheduled (in case you switched devices).

### On logout:
- All scheduled notifications are cancelled.

### Notification ID generation:
Uses **FNV-1a hash** algorithm to generate a stable 31-bit integer ID from a key like `"event:<uuid>"`. This ensures the same event always gets the same notification ID (so re-scheduling replaces the old one).

### Permission:
- Requests notification permission on Android 13+ only when the user first sets a reminder.

---

## 14. Internet connectivity handling

**File: `lib/services/connectivity_service.dart`**

### How it works:
- Uses the `connectivity_plus` package.
- Immediately checks current connectivity on startup.
- Watches for changes continuously.
- Emits `true` (online) or `false` (offline) whenever the status changes.

### What happens when you go offline:
- A **sync banner** appears in the Saved Messages and Drive screens showing a warning.
- The **item editor** shows a banner: *"You're offline — your draft is saved."*
- All **write operations** (create, edit, delete) are blocked and show an offline message.
- **Reading** still works perfectly — from the local cache.
- **Drafts are kept** so nothing is lost.

### What happens when you come back online:
- Automatic refresh is triggered.
- The sync banner disappears.
- Any drafts you created while offline are shown with the "Retry" button.

---

## 15. All the rules and validations

**File: `lib/core/utils/validators.dart` and `lib/data/repositories/items_repository.dart`**

### Username rules:
- Must match: `^[a-z0-9_]{3,20}$`
- Only lowercase letters (a–z), numbers (0–9), and underscores (`_`).
- 3 to 20 characters.
- Automatically converted to lowercase as you type.
- Checked for availability in real-time before sign-up (with a 450ms debounce).

### Password rules:
- At least 8 characters.
- Show/hide toggle on the field.

### Email rules:
- Must contain an `@` and a `.` with no spaces.
- Basic format check.

### Login field rules:
- Can be either an email address or a username.
- Auto-detects which format you're entering.

### Item title rules:
- Max 200 characters.
- Trimmed (leading/trailing spaces removed).
- If left empty, an **auto-title** is generated:
  - **Link**: the domain name without `www.` (e.g., `github.com`).
  - **Note**: first line of the content, max 60 characters + `…` if longer.
  - **Image**: `Image · Oct 3, 14:05` (the date and time).

### Item content rules:
- Max 20,000 characters.
- Whitespace-only content counts as empty.

### URL rules:
- Must be `http://` or `https://` with a hostname.
- If you type `www.site.com` (without `https://`), it automatically adds it.
- Max 2,048 characters.

### Tag rules:
- Leading `#` is stripped (so `#flutter` becomes `flutter`).
- Converted to lowercase.
- Only allows: letters, numbers, hyphens, underscores.
- 1–30 characters per tag.
- Duplicates are removed.
- Max 10 tags per item.

### Image rules:
- Required for "image" type items.
- Compressed on pick: max 1600px wide, 80% quality.
- Max 10 MB.
- Types: JPEG, PNG, WebP.

### PDF rules:
- File extension must be `.pdf`.
- Max 10 MB. Error message: *"PDF must be 10 MB or smaller"*.

### Error messages (user-facing):
| Error | Message shown |
|---|---|
| Wrong credentials | "Wrong email, username or password." |
| Email already exists | "An account with this email already exists." |
| Server unreachable | "Couldn't reach Snag's server." |
| Item missing/foreign | "This item no longer exists." |
| Offline and trying to write | "You're offline — your draft is saved." |
| File too large | "File must be 10 MB or smaller." |
| Username taken | "That username is already taken." |
| Email not confirmed | "Please confirm your email address first, then sign in." |
| Weak password | "Password is too weak. Use at least 8 characters." |
| Too many attempts | "Too many attempts. Please wait a minute and try again." |

---

## 16. Every code file explained in detail

### `lib/main.dart` (38 lines)
The **entry point** of the app. The very first function that runs is `main()`. It:
- Initializes Flutter bindings.
- Checks if `env.json` is set up (shows error screen if not).
- Connects to Supabase cloud.
- Creates the local database.
- Sets up notification service.
- Wraps the app in `ProviderScope` (Riverpod's container).
- Runs `SnagApp`.

---

### `lib/app/app.dart` (145 lines)
The **root widget** of the app. Manages:

`SnagApp` (main class):
- Creates the `ShareIntentService` and `AppLifecycleListener`.
- On startup: restores any pending share from drafts, starts listening for incoming shares, triggers an initial sync.
- Listens to auth state changes (sign in/out triggers sync and notification reschedule/cancel).
- Listens to connectivity changes (going online triggers sync).
- Renders `MaterialApp.router` with light/dark theme and the router.

`NotConfiguredApp` (shown when `env.json` is missing):
- A simple centered screen saying "App not configured" with instructions.

---

### `lib/app/providers.dart` (335 lines)
This is where **all Riverpod providers** are defined. Think of providers as "live data feeds" that the UI subscribes to.

Key providers:
- `databaseProvider` — the local SQLite database.
- `supabaseProvider` — the Supabase client.
- `authChangesProvider` — stream of auth state changes (login/logout events).
- `currentUserIdProvider` — the current user's ID (or null if not logged in).
- `connectivityServiceProvider` — the connectivity checker.
- `onlineProvider` — stream of true/false for internet status.
- `storageRemoteProvider` — Supabase Storage client.
- `itemsRepositoryProvider` — the main items data manager.
- `authRepositoryProvider` — the auth data manager.
- `usernameProvider` — the current user's username.
- `allItemsProvider` — all items for the current user (live stream).
- `itemProvider` — watch a single item by ID (live stream).
- `savedFilterProvider` — the current filter/search state for Saved Messages.
- `filteredItemsProvider` — items filtered by the current search/filter.
- `fromChatsProvider` — items with attachments (for Drive "From Chats").
- `syncProvider` — triggers and tracks the cloud sync state.
- `pendingShareProvider` — stores and persists incoming share text.
- `notificationServiceProvider` — the notification system.
- `launchRouteProvider` — the route from a notification cold start.
- `remindersRepositoryProvider` — item reminder manager.
- `itemReminderProvider` — the active reminder for a given item.
- `driveRepositoryProvider` — Drive data manager.
- `driveFilesProvider` — list of Drive files.
- `driveSignedUrlProvider` — signed URL for a Drive file.
- `eventsRepositoryProvider` — calendar events manager.
- `eventsProvider` — all calendar events.
- `eventProvider` — a single calendar event by ID.
- `chatsRepositoryProvider` — 1-to-1 chats manager.
- `directFileUrlProvider` — signed URL for a chat attachment.
- `chatFilesProvider` — attachments from 1-to-1 chats.
- `chatsProvider` — live stream of conversations (updates when new messages arrive).
- `holidayPrefsProvider` — holiday settings (region, festivals toggle) persisted in drafts.
- `holidaysProvider` — holiday data for the chosen region.

---

### `lib/app/router.dart` (278 lines)
**Manages all navigation** using go_router.

Key components:
- `_RouterRefresh` — notifies go_router when auth state or pending share changes (triggers redirects).
- `_safeFrom` — validates redirect target URLs (prevents open redirects).
- `routerProvider` — the main GoRouter with all routes and redirect logic.
- `_HomeShell` — the shell with the bottom bar (phone) or side rail (desktop/web).
- `_SnagMark` — the small Snag logo in the desktop sidebar.

---

### `lib/app/theme.dart` (74 lines)
**Defines the entire visual style** of the app.

- `snagTeal` = `Color(0xFF0F766E)` — the primary brand color.
- `buildTheme(brightness)` — creates a `ThemeData` for light or dark mode using `ColorScheme.fromSeed(seedColor: snagTeal)`.
- Customizes: AppBar (flat, no tint), NavigationBar (68px tall), input fields (rounded, filled), chips (rounded), filled buttons (52px tall, 14px radius), snack bars (floating).
- `ChatColors` extension — adds two computed colors: `bubble` (the chat bubble background) and `chatBackground` (the chat screen's background pattern).

---

### `lib/core/env.dart` (16 lines)
**Reads secret configuration** from build flags.

- `supabaseUrl` — the Supabase project URL.
- `supabaseAnonKey` — the public API key.
- `isConfigured` — returns `true` only if both values are non-empty.
- `appVersion` — hardcoded to `"1.5.0"` (keep in sync with `pubspec.yaml`).

Values are never hardcoded — they come from `--dart-define-from-file=env.json` at build time.

---

### `lib/core/result.dart` (16 lines)
A simple **success/failure wrapper** type.

```
sealed class Result<T>
  Ok<T>(value)      ← success case
  Err<T>(message, retryable)  ← failure case
```

Repository functions return `Result<void>` or `Result<bool>` so the UI knows whether to show success or an error message with retry.

---

### `lib/core/errors.dart` (97 lines)
**Maps technical errors to friendly user messages.**

Custom exception types:
- `OfflineException` — thrown when writing while offline.
- `ItemGoneException` — thrown when an item is missing or belongs to someone else.
- `ValidationException` — thrown when form validation fails.

`Messages` class — all the hardcoded error string constants.

`userMessageFor(error)` — takes any exception and returns a short string the user can read:
- Auth errors → credential errors, rate limits, email confirmation.
- Storage errors → file too large, server unreachable.
- Database errors → username conflict, invalid fields.
- Network errors → server unreachable.
- Everything else → "Something went wrong. Please try again."

---

### `lib/core/utils/validators.dart` (37 lines)
Four validator functions:
- `validateUsername(value)` — checks format `^[a-z0-9_]{3,20}$`.
- `validateEmail(value)` — checks `user@domain.ext` format.
- `validateLoginId(value)` — accepts email OR username.
- `validatePassword(value)` — requires at least 8 characters.

---

### `lib/data/local/tables.dart` (60 lines)
**Defines the local database schema** for drift.

- `TagsConverter` — converts between `List<String>` in Dart and a JSON string like `'["flutter","notes"]'` in the database.
- `Items` table — all columns for saved items (see section 9).
- `Drafts` table — form state storage (key, payload JSON, updatedAt).

---

### `lib/data/local/app_database.dart` (110 lines)
**The actual local database** — a drift `@DriftDatabase` class.

Key methods:
- `watchItems(ownerId)` — live stream of all items for a user, oldest first.
- `watchItem(ownerId, id)` — live stream of one item.
- `getItem(ownerId, id)` — single item fetch.
- `allItems(ownerId)` — all items as a future.
- `upsertItem(item)` — insert or update an item.
- `deleteItem(id)` — delete one item.
- `replaceAllForOwner(ownerId, remote)` — replaces the entire cache in one transaction. Preserves local file paths for items that still exist.
- `getDraft(key)`, `saveDraft(key, payload)`, `deleteDraft(key)` — draft management.
- `wipe()` — deletes all items and drafts (used on logout).

Also configured for web: uses `sqlite3.wasm` + `drift_worker.js` to run SQLite in the browser via WebAssembly.

---

### `lib/data/remote/items_remote.dart`
Talks to **Supabase Postgres** for saved items:
- `fetchAll()` — gets all items for the current user.
- `fetchOne(id)` — gets one item by ID.
- `insert(id, write)` — creates a new item row.
- `updateIfVersion(id, version, changes)` — conditional update (only updates if version matches).
- `delete(id)` — deletes a row.

---

### `lib/data/remote/storage_remote.dart`
Talks to **Supabase Storage** for files:
- `upload(path, file, mime)` — uploads a file from disk.
- `uploadBytes(path, bytes, mime)` — uploads raw bytes (for web).
- `signedUrl(path)` — gets a temporary URL valid for 1 hour. Caches in memory.
- `remove(path)` — deletes a file.
- `clearCache()` — clears the signed URL cache (called on logout).

---

### `lib/data/remote/auth_remote.dart`
Talks to **Supabase Auth**:
- `signUp(email, password, username)` — creates a new account.
- `signIn(login, password)` — login with email or username (using the Edge Function for username support).
- `signOut()` — logs out.
- `username()` — fetches the current user's username from `profiles`.
- `isUsernameAvailable(username)` — calls the `is_username_available` database function.

---

### `lib/data/repositories/items_repository.dart` (597 lines)
**The most important file** — the single "door" to item data.

Main responsibilities:
- **Read**: `watchAll()`, `watchOne(id)`, `load(id)`, `refresh()`.
- **Validate**: `validate(input, existing)` — checks all rules from section 9, returns a `ItemWrite` object or throws `ValidationException`.
- **Create**: `create(input, id)` — validates → uploads → inserts → caches.
- **Update**: `update(original, input, baseVersion)` — validates → uploads → conditional update → conflict handling → caches.
- **Archive/restore**: `setArchived(item, archived)` — conditional update.
- **Set tags**: `setTags(item, tags)` — conditional update.
- **Accept server version**: `acceptServerVersion(server)` — "Keep theirs" after conflict.
- **Delete**: `delete(item)` — remote delete → storage delete → local delete.
- **Drafts**: `loadDraft(key)`, `saveDraft(key, input)`, `deleteDraft(key)`.
- **File staging**: `stagePickedFile(sourcePath)` — copies a picked file to `<docs>/pending/` so it survives a draft restore.
- **Wipe**: `wipeLocal()` — clears cache, deletes all local files.

Also defines:
- `PickedAttachment` — represents a picked file (has path, MIME type, name, optional bytes for web).
- `ItemInput` — the form data (type, title, content, URL, tags, newAttachment, removeAttachment). Serializes to/from JSON for draft storage.
- `UpdateOutcome` sealed class: `Updated(item)`, `Conflict(server)`, `Gone()`.

---

### `lib/features/auth/auth_screens.dart` (438 lines)
Two screens:

**`LoginScreen`**:
- Email/username + password form.
- Shows an error box on failure.
- "Sign in" button with loading spinner.
- "New here? Create an account" link.
- Uses `AuthRepository.signIn()`.

**`SignUpScreen`**:
- Username + email + password form.
- Real-time username availability check (with debounce and visual indicators: spinner → ✓ available → ✗ taken).
- "Create account" button.
- "Already have an account? Sign in" link.
- Uses `AuthRepository.signUp()`.

---

### `lib/features/messenger/saved/saved_screen.dart` (453 lines)
The **Saved Messages chat screen** (see section 6 for detailed feature list).

Key internal classes:
- `_FilterBar` — the row of filter chips.
- `_MessageList` — the scrollable list of bubbles with date separators.
- `_Composer` — the text input bar at the bottom with send, attach, expand buttons.
- `NewItemArgs` — data class passed via go_router's `extra` to pre-fill the create screen.

---

### `lib/features/messenger/saved/message_bubble.dart`
Renders one item as a **chat bubble**. Handles all three types (note, link, image) plus PDF chips. Includes long-press context menu.

---

### `lib/features/messenger/saved/saved_filter.dart`
Defines the `SavedFilter` data class (query, type, tag, archived) and the `applyFilter` function that filters and searches items. Also has helper functions to get all unique tags.

---

### `lib/features/messenger/item_editor/item_editor_screen.dart` (689 lines)
The **create/edit/share confirm screen** (see section 6 for detailed description).

---

### `lib/features/calendar/calendar_screen.dart` (501 lines)
The **Calendar tab** with month view, upcoming list, holiday display, and settings.

---

### `lib/features/drive/drive_screen.dart` (659 lines)
The **Drive tab** with "From Chats" folders and "My Files" tab. Includes full preview screens for files.

---

### `lib/features/common/common_widgets.dart`
Shared widgets used across the app:
- `LoadingView` — a centered loading spinner.
- `ErrorView` — error message with optional Retry button.
- `EmptyState` — icon + message for empty lists.
- `SyncBanner` — shows sync loading/error at the top of screens.
- `DateSeparator` — the "Today" / "Yesterday" / "Oct 3" dividers in the chat.
- `TagInput` — the tag chip input with suggestions.
- `ItemGoneView` — the "This item no longer exists" view.
- `scaffoldMessengerKey` — a global key used to show snack bars from anywhere in the app.
- `showSnack(message)` — a utility function to show a floating snackbar.

---

### `lib/services/notification_service.dart` (124 lines)
**Local push notification system** (see section 13 for details).

Key: `notificationIdFor(key)` — uses FNV-1a hashing to generate stable integer notification IDs from string keys.

---

### `lib/services/connectivity_service.dart` (35 lines)
**Internet status monitor**. Watches `connectivity_plus` for changes and emits a `bool` stream.

---

### `lib/services/share_intent_service.dart` (82 lines)
**Android share sheet handler** (see section 12 for details).

---

## 17. Third-party packages (external libraries)

**File: `pubspec.yaml`** — version `1.5.0+6`, Dart SDK `^3.12.0`

| Package | Version | Purpose |
|---|---|---|
| `connectivity_plus` | ^7.3.1 | Detect internet connectivity changes |
| `drift` | ^2.35.0 | SQLite local database ORM (Object-Relational Mapping) |
| `drift_flutter` | ^0.3.1 | Flutter integration for drift |
| `file_picker` | ^13.1.0 | Let users pick files (PDFs) from their device |
| `flutter_local_notifications` | ^22.3.1 | Schedule and show local push notifications |
| `flutter_riverpod` | ^3.4.3 | State management — the "brain" for data flow |
| `flutter_timezone` | ^5.1.0 | Get the device's current timezone for notifications |
| `go_router` | ^18.0.2 | URL-based navigation between screens |
| `image_picker` | ^1.2.3 | Let users pick images from camera or gallery |
| `path` | ^1.9.1 | File path manipulation utilities |
| `path_provider` | ^2.1.6 | Find the correct folders on the device to store files |
| `receive_sharing_intent` | ^1.9.0 | Receive text/URLs shared from other Android apps |
| `supabase_flutter` | ^2.18.0 | Connect to Supabase (auth, database, storage, realtime) |
| `timezone` | ^0.11.1 | Timezone data for scheduling notifications |
| `url_launcher` | ^6.3.2 | Open URLs in the browser or open files externally |
| `uuid` | ^4.6.0 | Generate unique IDs (UUIDs) for new items |

**Development-only packages (not in the final app):**
| Package | Purpose |
|---|---|
| `build_runner` | Runs code generators |
| `drift_dev` | Generates database query code from table definitions |
| `flutter_lints` | Code style rules and warnings |
| `flutter_test` | Testing framework |

---

## 18. Tests in the project

**Folder: `test/`**

| File | What it tests |
|---|---|
| `utils_test.dart` | URL normalization, title auto-generation, tag normalization, share text parsing |
| `items_repository_test.dart` | Creating, updating, deleting items; conflict detection; offline behavior |
| `month_view_test.dart` | The calendar month grid widget rendering |
| `features_test.dart` | High-level feature tests |
| `holidays_login_test.dart` | Holiday data loading and login flows |
| `widget_test.dart` | Basic widget rendering tests |

**Database security tests (`supabase/tests/rls_check.sql`):**
SQL queries to verify that RLS policies work correctly.

---

## 19. The deployment / shipping setup

### Android APK:
- Built with: `flutter build apk --release --dart-define-from-file=env.json`
- The anon key ends up inside the APK — this is by design (it's public by design; RLS protects the data).
- App ID: `com.snag.snag`
- App label: `Snag`
- Icon: `ic_stat_snag` (used by notifications)

### Web version:
- Deployed to **Vercel** (a free web hosting service).
- `vercel.json` configures the deployment.
- Uses `web/index.html` as the entry point.
- SQLite runs in the browser using WebAssembly (`web/sqlite3.wasm`) and a Web Worker (`web/drift_worker.js`).
- The web app is a PWA (Progressive Web App) installable from the browser, configured by `web/manifest.json`.
- App icons: `web/icons/snag.svg` and `web/icons/snag-maskable.svg`.

### Supabase backend:
- Free plan.
- Manual setup in the Supabase Dashboard (run the SQL scripts).
- Email confirmation is turned OFF so reviewers can sign up instantly.

### UptimeRobot:
- Free monitoring service.
- Pings the `heartbeat` table every 5 minutes to prevent Supabase from pausing the project.
- URL: `SUPABASE_URL/rest/v1/heartbeat?select=id&apikey=SUPABASE_ANON_KEY`

---

## 20. Known limitations and future plans

### Things intentionally NOT built (marked "Later"):
- Group chats, channels, voice notes, calls.
- Typing indicators, online status, read receipts.
- Push notifications (from the server — only local notifications are implemented).
- Replies, forwarding, reactions.
- End-to-end encryption.
- Sending images in direct chats (text only in v1).
- Drive: folders, move files, file sharing, trash, non-image/PDF file types.
- Calendar: month/week grid view, recurring events, invites, Google Calendar sync.
- Public share links.
- Data export and account deletion.
- Link preview cards (auto-loading title/image from a URL).
- Sharing images INTO Snag (only text/URL sharing is supported in v1).
- iOS support.
- Google/OAuth login.

### Known decisions documented in the plan:
- **Stage 1 → 2 migration clears local-only items**: When cloud sync was added, locally-created items (from before accounts were set up) are deleted. This is a deliberate trade-off.
- **Email confirmation off**: Turned off so reviewers can sign up instantly. Noted as a security trade-off.
- **Conflict policy**: Most recently saved version wins. User is warned before overwriting a newer server version.
- **Offline queue not implemented**: While offline, writes are blocked (not queued). A full offline sync queue was out of scope.
- **Reminders are device-local**: Reminder notifications are stored on the device where they were set. They don't sync across devices.

---

## Summary Diagram

```
                           ┌─────────────────────────────────────────┐
                           │              SNAG APP                    │
                           │                                          │
  Share from Chrome/       │  Screens:                                │
  YouTube/WhatsApp ───────▶│  • Login / Sign-up                      │
                           │  • Messenger (Chat List)                 │
                           │  • Saved Messages (your inbox)          │
                           │  • Item Editor (create/edit)            │
                           │  • Item Detail                          │
                           │  • Drive (From Chats + My Files)        │
                           │  • Calendar (Month + Upcoming)          │
                           │  • 1-to-1 Chat                          │
                           │  • Profile                              │
                           │                                          │
                           │  State (Riverpod Providers)              │
                           │  Navigation (go_router)                  │
                           │                                          │
                           │  Repositories (the data managers):       │
                           │  ┌──────────┐    ┌────────────────────┐ │
                           │  │  Local   │    │      Remote        │ │
                           │  │  (drift/ │◀──▶│   (supabase_flutter│ │
                           │  │  SQLite) │    │    + HTTP calls)   │ │
                           │  └──────────┘    └────────────────────┘ │
                           │                                          │
                           │  Services:                               │
                           │  • ShareIntentService                   │
                           │  • ConnectivityService                  │
                           │  • NotificationService                  │
                           └────────────────┬────────────────────────┘
                                            │ HTTPS + JWT token
                                            ▼
                           ┌─────────────────────────────────────────┐
                           │              SUPABASE                    │
                           │                                          │
                           │  Auth (email + password login)          │
                           │  Postgres + RLS (private data)          │
                           │  Storage (private files)                │
                           │  Realtime (live chat)                   │
                           └─────────────────────────────────────────┘
                                            ▲
                           UptimeRobot ─────┘ (pings every 5 min)
```

---

*Report generated: October 1, 2026. Project version: 1.5.0+6.*
