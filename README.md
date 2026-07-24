# Multi-Branch Stock Manager

A Flutter + Firebase app for a food business with a central kitchen and several
branches: branches order stock from the kitchen, the kitchen prepares and
deducts central stock, delivery moves it out, and branches confirm receipt and
log daily sold/wasted quantities. A manager gets cross-branch reporting on top
of it all.

Built as the implementation for a university dissertation. `DEVELOPMENT_LOG.md`
has the full phase-by-phase history — goals, decisions, and bugs hit and fixed
— and is the primary source for the dissertation's Implementation chapter.
This README is just enough to get the app running and oriented in the code.

## Roles

The app has four roles, each routed to a different home screen after login
(`lib/main.dart`):

- **Branch staff** — place orders, track them through to delivery, confirm
  receipt, log daily sold/wasted quantities, view branch history, log
  corrections against the ledger.
- **Kitchen staff** — action requested orders (adjusting quantities or adding
  items if what's requested can't be fulfilled exactly), manage the central
  stock catalog (add/restock/edit/delete items).
- **Delivery** — mark prepared orders as delivered.
- **Manager** — cross-branch sold/wasted/waste-rate reporting, a live view of
  every order across all branches, and branch management (creating new
  branches).

## Tech stack

- **Flutter** (Android + Web targets) — Dart SDK `^3.12.0`
- **Firebase**: Cloud Firestore (data + real-time streams), Firebase
  Authentication (email/password)
- No paid Firebase features — stays on the Spark (free) plan; no Cloud
  Functions

## Getting started

### Prerequisites

- [Flutter SDK](https://flutter.dev) installed and `flutter doctor` passing
  for at least the Web (Chrome) target
- A Firebase project with **Firestore** and **Authentication (email/password)**
  enabled
- The [Firebase CLI](https://firebase.google.com/docs/cli) and
  [FlutterFire CLI](https://firebase.flutter.dev/docs/cli) if you're pointing
  this at your own Firebase project

### Setup

```bash
flutter pub get
```

This repo currently includes `lib/firebase_options.dart` and
`android/app/google-services.json`, wired to the project's own Firebase
project — fine while the repo stays private, but review before making it
public. To point the app at a different Firebase project instead, run
`flutterfire configure` and it will regenerate both.

### Run

```bash
flutter run -d chrome
```

The app has been developed and tested against the Web (Chrome) target
throughout. The Android target is configured but hasn't been exercised
recently — verify on a device/emulator before relying on it.

### Test

```bash
flutter test
```

## Project structure

```
lib/
  models/     Data models — Branch, User, StockItem, StockMovement (the
              immutable ledger), Order/OrderItem
  services/   FirestoreService (all reads/writes) and AuthService
  screens/    One screen per role/workflow step
  widgets/    Shared UI: adaptive nav shell, responsive body, order status
              timeline, stream error view, confirm-with-note dialog
  utils/      Small shared formatting helpers
test/
  models/     Serialization + fallback-behaviour tests for every model
  utils/      Formatting helper tests
  widgets/    Tests for the Firebase-free presentational widgets
```

## Architecture notes

- **Stock is tracked centrally and per branch.** Central stock lives on
  `stockItems`; each branch's own holdings live in `branchStock`.
- **`stockMovements` is an immutable ledger** — every stock change (restock,
  order deduction, delivery received, daily sold/wasted, manual correction)
  is a new ledger entry, never an edit. Corrections are logged as new signed
  adjustment entries rather than editing history. All reporting is computed
  as filtered queries over this ledger.
- **Orders carry their own status timeline.** Each transition
  (requested → preparing → delivered → received) records a timestamp and the
  acting user's name directly on the order document, so any role can see an
  order's full history in one place (`OrderStatusTimeline` /
  `showOrderDetailSheet`) rather than piecing it together from the ledger.
- **Firestore security rules** (`firestore.rules`) enforce role-based access
  server-side — e.g. only the kitchen can advance `requested → preparing`,
  only the owning branch can confirm its own deliveries, `stockMovements`
  entries can be created but never edited or deleted.
