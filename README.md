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

- `Package.swift`: Swift Package Manager manifest (macOS 13+, one executable target)
- `Sources/NotifyGCalMenu/`
  - `NotifyGCalMenuApp.swift` / `MenuBarContentView.swift` / `AppModel.swift`: the menu bar UI and its state
  - `GoogleAuthManager.swift` / `LoopbackHTTPServer.swift` / `PKCE.swift` / `KeychainStore.swift`: OAuth sign-in/out and token storage
  - `CalendarService.swift` / `CalendarModels.swift`: talks to the Calendar API
  - `EventChecker.swift` / `SettingsStore.swift`: the polling loop, lead-time setting, and notified-event dedup
  - `NotificationManager.swift` / `ToneEngine.swift` / `EventLinkOpener.swift`: notifications, the chime, and opening links from them
  - `Resources/Secrets.plist`: your OAuth client credentials (gitignored — see setup below)
- `Info.plist`: app bundle metadata (menu-bar-only, no Dock icon)
- `Scripts/build.sh`: builds the package and assembles it into a runnable `.app`

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

- Copy `Sources/NotifyGCalMenu/Resources/Secrets.plist.example` to
  `Sources/NotifyGCalMenu/Resources/Secrets.plist` (already done by default; just edit it)
- Replace `GoogleClientID` and `GoogleClientSecret` with the values from step 1
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

## Cutting a Release

**The git tag is the version source of truth.** `Info.plist` keeps a placeholder version
(`1.0`) in git; the real version is stamped into the built bundle's copy of `Info.plist` at
build time, so there's no version-bump commit to remember before tagging. Use
[semantic versioning](https://semver.org/) for tags (`vX.Y.Z`) — both `CFBundleVersion` and
`CFBundleShortVersionString` are stamped together, since an eventual auto-update mechanism
would compare `CFBundleVersion` to detect newer releases.

To build a release with a specific version stamped in:

```sh
MARKETING_VERSION=1.2.3 ./Scripts/build.sh release
```

To actually cut a release today (manual, since there's no CI/signing pipeline yet — see
#12/#13/#17 for that automation):

```sh
git tag v1.2.3
git push origin v1.2.3
MARKETING_VERSION=1.2.3 ./Scripts/build.sh release
ditto -c -k --keepParent build/NotifyGCalMenu.app NotifyGCalMenu-1.2.3.zip
gh release create v1.2.3 NotifyGCalMenu-1.2.3.zip --title 1.2.3 --generate-notes
```

This produces an **ad-hoc signed** build, not a Developer ID-signed and notarized one —
anyone downloading it will need to right-click → Open (or approve it in System
Settings → Privacy & Security) to bypass Gatekeeper's unidentified-developer warning.
Proper signing and notarization are tracked in #12.

## Usage

- Click the bell icon to open the menu
- "Sign in with Google" starts the OAuth flow in your default browser; approve the
  requested read-only calendar access and the browser tab will confirm you can close it
- "Notify me" controls how far ahead of an event start you get notified
- "Sync Now" runs an immediate check instead of waiting for the next cycle, and lists
  today's remaining events
- "Sign out" revokes the app's access to your calendar and clears the stored refresh token

## Notes / Limitations

- Only checks your primary calendar
- Only fires while the app is running and the Mac is awake
- Checks run every 30 seconds, so notifications can land up to that long after the
  configured lead time
- The refresh token is stored in the macOS Keychain under the service name
  `com.notifygcalmenu.google-refresh-token`; deleting that Keychain item has the same
  effect as signing out

See [PRIVACY.md](PRIVACY.md) for what calendar data the app accesses and how it's stored.

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
