# PantryBuddy (Flutter App)

## Overview

This is the client application for PantryBuddy, a household food-inventory
app that helps families track what food they have, where it's stored, and
when it's likely to expire. Built in Flutter/Dart, deployed as a web app,
using the same codebase that would also run on mobile without changes to
the underlying architecture.

This app is one half of a two-part system: it holds no data itself and
performs no business logic directly — every read and write goes through
the [PantryBuddy Backend API](../pantrybuddy-backend), which handles
authentication, authorisation, and the database.

## Architecture

**Repository pattern.** The app is built against a set of abstract data
interfaces (`UserRepository`, `HouseholdRepository`, `InventoryRepository`,
`ReminderRepository`, `ActivityLogRepository`, `ShelfLifeRepository`),
defined in `lib/data/repository.dart`. Two implementations exist:

- `InMemoryDataStore` — an in-memory mock with no persistence, used during
  early development to build and demonstrate the UI before the real
  backend existed.
- `ApiDataStore` — the real implementation, making HTTP calls to the
  backend API.

Because the rest of the app only ever depends on the interfaces, swapping
the mock for the real backend required no changes to any screen or state
logic — only the data-layer implementation changed.

**State management.** A single `AppState` (`ChangeNotifier`) in
`lib/state/app_state.dart` is the app's single source of truth — current
user, household, inventory, reminders, and activity feed all live here.
Screens listen to it via `ListenableBuilder` and rebuild when it changes.
Since the backend has no websocket/push layer, live updates (e.g. seeing
a household member's newly added item) are achieved by polling on a
timer rather than a persistent connection.

**Authentication.** On sign-in/sign-up, `ApiDataStore` receives and holds
a JWT session token in memory, attaching it to every subsequent request
automatically. The token is not persisted to local storage — closing and
reopening the app requires signing in again, a deliberate simplicity
trade-off for this iteration.

## Key Features (by Epic)

- **Epic 1 — Profile & Household Management:** account creation, profile
  editing, creating or joining a household via a numeric invite code,
  with an admin-approval step before a join request grants access.
- **Epic 2 — Inventory Overview:** add/edit/browse food items by storage
  location (Fridge/Freezer/Pantry), with expiry dates auto-suggested from
  a real shelf-life reference dataset (matched by specific product first,
  falling back to category-level guidance), storage-location warnings
  (e.g. flagging when a food shouldn't be kept in the pantry), and a
  search bar available from both the Home and Inventory screens.
- **Epic 3 — Reminders & Shared Household Access:** configurable expiry
  reminders (with a shelf-life-aware suggested lead time), a shared
  household activity feed, and member management including pending
  join-request approval for admins.

## Project Structure

```
lib/
  data/        Repository interfaces + the mock and real implementations
  models/      Domain models (AppUser, Household, FoodItem, Reminder, ...)
  screens/     UI, grouped by feature area (onboarding, home, inventory,
               profile, household)
  services/    Client-side helpers (ID generation, reminder validation)
  state/       AppState — the app's single source of truth
  theme/       Shared visual theming
  utils/       Small shared utilities (date formatting, unit list)
  widgets/     Reusable UI components (item cards, validated text fields)
```

## Getting Started

1. Install the [Flutter SDK](https://docs.flutter.dev/get-started/install).
2. `flutter pub get`
3. Point the app at a backend: edit `lib/data/api_config.dart`'s
   `baseUrl` — defaults to `http://localhost:4000` for local development
   against the backend running on the same machine; set it to the
   deployed backend URL for a production build.
4. `flutter run -d chrome` for local development, or
   `flutter build web --release` to produce a deployable build in
   `build/web`.

### Deployment

Deployed as a static site to Vercel: `flutter build web --release`,
then `vercel --prod` from inside `build/web`. This is a separate Vercel
project from the backend, deployed independently.

## Testing

Testing for this app was primarily conducted as manual/exploratory UI
testing alongside integration testing of the backend it depends on (see
the backend's README and the project's Testing Folder documentation for
the itemised test cases). The automated test suite currently contains a
single smoke test (`test/widget_test.dart`) confirming the app builds
without crashing; broader automated widget/unit test coverage is noted
as a candidate for future iterations.

## Current Limitations

- **No persistent session.** The auth token is held in memory only —
  users must sign in again after closing the app. Acceptable for this
  iteration; a production version would persist it securely.
- **Polling, not push.** Live updates rely on periodic polling rather
  than a real-time connection, meaning changes from another household
  member may take a few seconds to appear rather than being instant.
- **Web-only deployment target.** The architecture is mobile-compatible
  by design (no web-specific dependencies in the core logic), but only
  the web build has been built and deployed this iteration.
