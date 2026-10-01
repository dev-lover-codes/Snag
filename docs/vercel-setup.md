# Vercel auto-deploy setup for the Snag website

Fill in these settings so Vercel builds and deploys the website by itself
every time you push to `main` on GitHub. You no longer need to run
`vercel deploy` by hand.

Vercel has no Flutter installed, so the **Install Command** downloads Flutter
3.47.5 (the version this project uses) into the build machine first.

> **These settings already live in [`vercel.json`](../vercel.json)**
> (`installCommand`, `buildCommand`, `outputDirectory`). Vercel uses the file
> over the dashboard, so you can leave the dashboard Override switches off.
> The table below is for reference only. To change a command, edit `vercel.json` and push.

---

## 1. Project Settings → Build and Deployment → Framework Settings

| Field | Override | Value |
|---|---|---|
| **Framework Preset** | n/a | `Other` |
| **Build Command** | **On** | see below |
| **Output Directory** | **On** | `build/web` |
| **Install Command** | **On** | see below |
| **Development Command** | Off | leave empty |

**Install Command** (copy as one line):

```bash
git clone --depth 1 -b 3.47.5 https://github.com/flutter/flutter.git .flutter-sdk && .flutter-sdk/bin/flutter --disable-analytics && .flutter-sdk/bin/flutter pub get
```

**Build Command** (copy as one line):

```bash
.flutter-sdk/bin/flutter build web --release --no-wasm-dry-run --dart-define=SUPABASE_URL=$SUPABASE_URL --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY
```

Click **Save** at the bottom of the Framework Settings box.

## 2. Same page → Root Directory

| Field | Value |
|---|---|
| **Root Directory** | `./` (leave as it is: `pubspec.yaml` is at the top of the repo) |
| Include files outside the root directory in the Build Step | Enabled (default, fine either way) |
| Skip deployments when there are no changes | Disabled (keep it off) |

Click **Save**.

## 3. Environment variables (already done by the Supabase integration)

Connecting Vercel to Supabase saved the variables the build needs, with the
exact names the Build Command uses:

| Key | Used by the build? |
|---|---|
| `SUPABASE_URL` | Yes |
| `SUPABASE_ANON_KEY` | Yes |
| `SUPABASE_SERVICE_ROLE_KEY`, `SUPABASE_SECRET_KEY`, `SUPABASE_JWT_SECRET`, `POSTGRES_*` | **No.** They're never passed into the app, so they never reach the website. |

The integration added them for **Production** only. Preview builds (other
branches) would show "App not configured". Add the two `SUPABASE_` keys to
Preview too if you want working previews.

## 4. Project Settings → Git

1. **Connect Git Repository** → GitHub → `dev-lover-codes/Snag`.
2. **Production Branch:** `main`.

From now on, every push to `main` deploys to production. Pushes to other
branches create preview deployments.

## 5. `vercel.json` (done)

`vercel.json` sits at the top of the repo, where git deployments read it.
It sets the caching and security headers.

## 6. Deploy and check

1. Push to `main`, or click **Deployments → Redeploy** in Vercel.
2. The first build takes about 4–6 minutes (downloading Flutter). Later
   builds are similar, because the build machine starts fresh each time.
3. The banner "Configuration Settings in the current Production deployment differ from your current Project Settings" is normal after changing settings. It disappears once this new deployment finishes.
4. Open **https://snag-teal.vercel.app**. You should see the Snag loading
   screen, then the login page.

### If the build fails

| Message in the build log | Fix |
|---|---|
| `.flutter-sdk/bin/flutter: No such file or directory` | The Install Command didn't run. Check that `vercel.json` at the repo root still has `installCommand`. |
| `App not configured` on the live site | `SUPABASE_URL` / `SUPABASE_ANON_KEY` missing for that environment (step 3). Add them, then redeploy. |
| `No Output Directory named "build/web" found` | Output Directory override is off or misspelt. |
| Command too long | Copy each command as a single line with no line breaks. |

## 7. Email links (Supabase Site URL)

The Vercel–Supabase integration sets Supabase's **Site URL** to
`https://snag-its-raaj.vercel.app/` and **resets it on every production
deployment**. Sign-up confirmation emails link there, so that address must be
public:

- **Settings → Deployment Protection → Vercel Authentication: off** for this
  project. If it's on, email links ask for a Vercel login.
- `https://snag-teal.vercel.app/**` is also in Supabase's Redirect URLs, so
  either address works.
