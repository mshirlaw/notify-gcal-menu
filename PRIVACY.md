# Privacy Policy

**Notify GCal Menu** is a macOS menu bar app that shows a system notification when a Google
Calendar event is about to start. This document explains what data the app accesses, how it's
used, and how it's stored.

## What data the app accesses

The app requests read-only access to your primary Google Calendar via the
`https://www.googleapis.com/auth/calendar.readonly` scope. This lets it see:

- Event titles, start times, and locations
- Video call links (e.g. Google Meet) attached to events

The app cannot create, modify, or delete anything in your calendar — the scope it requests is
strictly read-only.

## How the data is used

Every 30 seconds, the app checks your primary calendar for events starting soon (within a
lead time you configure) and shows a native macOS notification for each one, with a "Join
Meeting" button if the event has a video call link. That's the only use of calendar data —
nothing else is done with it.

## How the data is stored

Everything the app stores stays **on your own Mac**. Nothing is sent to any server other than
Google's own Calendar API and OAuth endpoints, which the app talks to directly.

- **OAuth refresh token**: stored in the macOS Keychain, protected by the operating system.
- **Access tokens**: kept in memory only, refreshed on demand, never written to disk.
- **App settings** (notification lead time, which events have already been notified): stored
  in `UserDefaults`, macOS's standard local app-preferences storage.

There is no analytics, tracking, or telemetry of any kind, and no backend server operated by
the app's developer — the app talks directly to Google's APIs from your machine.

## Revoking access

You can disconnect the app from your Google account at any time:

- In the app itself, via the "Sign out" menu item, which clears the locally stored refresh
  token, or
- From your Google Account's [third-party access settings](https://myaccount.google.com/permissions),
  which revokes the app's access on Google's side.

## Contact

This is an open-source project. For privacy questions or concerns, please open an issue on
the [GitHub repository](https://github.com/mshirlaw/notify-gcal-menu).

## Changes to this policy

Any changes to this policy will be made via a pull request to this file in the repository,
visible in its commit history.
