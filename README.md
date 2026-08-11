# Notify GCal Menu

A native macOS menu bar app that shows a system notification when a Google Calendar event
is about to start. This is a native reimplementation of the
[notify-gcal](../notify-gcal) Chrome extension, for when you'd rather have a small
always-running menu bar helper than depend on Chrome staying open.

## What It Does

Every 30 seconds, the app checks your primary Google Calendar for events starting soon
(configurable lead time) and shows a macOS notification with a sound for each one. If the
event has a Google Meet link, the notification includes a "Join Meeting" button. Clicking
the notification (or that button) opens the video call link, or the event's Calendar page
if there isn't one.

## Project Contents

- `Package.swift`: Swift Package Manager manifest (macOS 13+, one executable target, depends on Sparkle)
- `Sources/NotifyGCalMenu/`
  - `NotifyGCalMenuApp.swift` / `MenuBarContentView.swift` / `AppModel.swift`: the menu bar UI and its state
  - `GoogleAuthManager.swift` / `LoopbackHTTPServer.swift` / `PKCE.swift` / `KeychainStore.swift`: OAuth sign-in/out and token storage
  - `CalendarService.swift` / `CalendarModels.swift`: talks to the Calendar API
  - `EventChecker.swift` / `SettingsStore.swift`: the polling loop, lead-time setting, and notified-event dedup
  - `NotificationManager.swift` / `ToneEngine.swift` / `EventLinkOpener.swift`: notifications, the chime, and opening links from them
  - `UpdaterManager.swift`: the only file that imports Sparkle; wraps `SPUStandardUpdaterController` and guards on the placeholder key
  - `Resources/Secrets.plist`: your OAuth client credentials (gitignored — see setup below)
- `Info.plist`: app bundle metadata (menu-bar-only, no Dock icon)
- `Scripts/build.sh`: builds the package and assembles it into a runnable `.app`
- `appcast.xml`: the Sparkle update feed, hosted from the repo root
- `.github/workflows/ci.yml`: builds the app on every push and pull request
- `.github/workflows/release.yml`: builds, signs, notarizes, and publishes on every `v*` tag

## First-Time Developer Setup

Do this once, before sign-in can work. `Secrets.plist` starts out with placeholder
credentials, so "Sign in with Google" will fail with a "Secrets.plist still has placeholder
OAuth credentials" error until you complete this.

### 1. Create an OAuth client

- Go to the [Google Cloud Console](https://console.cloud.google.com/)
- Create a new project (or pick an existing one)
- Enable the "Google Calendar API" for that project (APIs & Services > Library)
- Configure the OAuth consent screen (APIs & Services > OAuth consent screen) if you haven't already
  - "Internal" if you have a Google Workspace account, so anyone in your org can sign in without being added individually
  - Otherwise "External", and add your Google account as a test user, or publish the consent screen
- Go to APIs & Services > Credentials > Create Credentials > OAuth client ID
  - Application type: **Desktop app**
  - Name it whatever you like (e.g. "Notify GCal Menu")
- Copy the generated **Client ID** and **Client Secret**

The client secret isn't actually confidential for this client type (it ships inside the
app binary either way, per Google's own guidance for installed apps) — it's kept out of git
here purely as good hygiene, not because it protects anything on its own.

### 2. Fill in Secrets.plist

- Run `./Scripts/build.sh` once; it creates
  `Sources/NotifyGCalMenu/Resources/Secrets.plist` from the tracked `.example` file if you
  don't have one yet (the build needs the file to exist, placeholders or not)
- Replace `GoogleClientID` and `GoogleClientSecret` in it with the values from step 1
- Rebuild (`./Scripts/build.sh`) so the new file gets copied into the app bundle

## Building and Running

```sh
./Scripts/build.sh          # debug build -> build/NotifyGCalMenu.app
./Scripts/build.sh release  # release build
open build/NotifyGCalMenu.app
```

The bell icon should appear in your menu bar. There's no Dock icon or app switcher entry
(`LSUIElement` is set), by design for a menu bar utility.

To iterate on the code without rebuilding the bundle each time, `swift run` also works, but
sign-in and notification permissions are more reliable from the assembled `.app` (see
Troubleshooting).

## Enabling Auto-Update

The app ships with Sparkle wired up but switched off: `SUPublicEDKey` in `Info.plist` is a
placeholder, and until it holds a real key the updater never starts and the popover hides
its "Check for Updates…" row. Two steps activate it, and only the first needs a human.

### 1. Generate the signing key (once, by the maintainer)

Download the Sparkle release tools from
[sparkle-project/Sparkle releases](https://github.com/sparkle-project/Sparkle/releases)
and run:

```sh
./bin/generate_keys
```

This stores the private key in your login Keychain and prints the public key. Paste that
public key into `Info.plist` as `SUPublicEDKey`, replacing `YOUR_SPARKLE_PUBLIC_KEY`.

The private key never leaves your Keychain and must never be committed. Back it up
(`./bin/generate_keys -x private-key.txt`) somewhere safe — losing it means no existing
install can be updated again.

### 2. Publish releases

`appcast.xml` in the repository root is the update feed, served directly by GitHub at
`https://raw.githubusercontent.com/mshirlaw/notify-gcal-menu/main/appcast.xml` — no GitHub
Pages or other hosting required. It starts with no entries, which Sparkle reads as "you're
up to date".

Signing archives and adding `<item>` entries is automated — see "Cutting a release" below.

> **One rule worth knowing:** Sparkle accepts an update if *either* the EdDSA key *or* the
> code signing identity matches the installed copy. Changing one at a time is safe;
> changing both in the same release breaks auto-update for every existing install
> permanently.

## Cutting a Release

Releases are cut by pushing a tag. Everything else is automated by
`.github/workflows/release.yml`:

```sh
git tag v1.2.3
git push origin v1.2.3
```

That builds the app, stamps the version, signs it with Developer ID, notarizes and staples
it, publishes a GitHub release with generated notes, and commits the new `<item>` to
`appcast.xml` on `main` so existing installs see the update.

**The git tag is the version source of truth.** `Info.plist` keeps a placeholder version in
git and the real one is stamped into the bundle at build time, so there's no version-bump
commit to remember. Tag names are `vX.Y.Z`; the leading `v` is stripped for the bundle
version. Use [semantic versioning](https://semver.org/) — Sparkle compares versions to
decide whether an update is newer, so they must increase monotonically.

To check what a release will produce without publishing, build one locally:

```sh
MARKETING_VERSION=1.2.3 ./Scripts/build.sh release
```

### Required repository secrets

Set these under Settings → Secrets and variables → Actions. The release workflow is the
only thing that reads them; CI on pushes and pull requests needs none, so builds from
forked pull requests keep working.

| Secret | What it is |
| --- | --- |
| `GOOGLE_CLIENT_ID` | OAuth client ID, from First-Time Developer Setup above |
| `GOOGLE_CLIENT_SECRET` | OAuth client secret, from the same place |
| `SPARKLE_PRIVATE_KEY` | The EdDSA private key, exported with `./bin/generate_keys -x private-key.txt` |
| `DEVELOPER_ID_CERT_P12` | Developer ID Application certificate and key, exported from Keychain Access as `.p12`, then base64-encoded (`base64 -i cert.p12 \| pbcopy`) |
| `DEVELOPER_ID_CERT_PASSWORD` | The password set when exporting that `.p12` |
| `NOTARY_API_KEY_P8` | App Store Connect API key `.p8`, base64-encoded the same way |
| `NOTARY_API_KEY_ID` | That key's Key ID |
| `NOTARY_API_ISSUER_ID` | The Issuer ID from App Store Connect → Users and Access → Integrations |

The Developer ID certificate requires an Apple Developer Program membership. Create it as
**Developer ID Application** (not Mac App Store or Apple Development), and create the
notarization key under App Store Connect → Users and Access → Integrations → Team Keys.

The app is signed with the hardened runtime, which notarization requires, and is
deliberately **not** sandboxed: the sandbox would complicate the loopback OAuth listener
and Keychain access for no benefit outside the Mac App Store. Outside the sandbox the
hardened runtime needs no entitlements for anything this app does, so there is no
entitlements file to maintain.

If `main` is protected, the workflow needs permission to push the appcast commit to it.

## Usage

- Click the bell icon to open the menu
- "Sign in with Google" starts the OAuth flow in your default browser; approve the
  requested read-only calendar access and the browser tab will confirm you can close it
- "Notify me" controls how far ahead of an event start you get notified
- "Check now" runs an immediate check instead of waiting for the next cycle, and lists
  today's remaining events
- "Check for Updates…" asks Sparkle to check right away; it only appears once a real
  Sparkle key is configured (see Enabling Auto-Update above), hidden by default
- "Sign out" revokes the app's access to your calendar and clears the stored refresh token

## Notes / Limitations

- Only checks your primary calendar
- Only fires while the app is running and the Mac is awake
- Checks run every 30 seconds, so notifications can land up to that long after the
  configured lead time
- The refresh token is stored in the macOS Keychain under the service name
  `com.notifygcalmenu.google-refresh-token`; deleting that Keychain item has the same
  effect as signing out

## Troubleshooting

- **"Secrets.plist still has placeholder OAuth credentials"**: finish the First-Time
  Developer Setup section above
- **Sign-in opens a browser but nothing happens after approving**: check Console.app for
  `[Notify GCal]` or `NotifyGCalMenu` log lines; the loopback listener binds to an ephemeral
  `127.0.0.1` port, so this can fail if something (e.g. strict firewall/VPN software) blocks
  local loopback connections
- **No notifications appear**: check System Settings → Notifications → Notify GCal Menu,
  and make sure Focus/Do Not Disturb isn't on
- **Notification permission prompt never appeared**: it's requested once on first launch;
  if you denied it, re-enable it manually in System Settings → Notifications
