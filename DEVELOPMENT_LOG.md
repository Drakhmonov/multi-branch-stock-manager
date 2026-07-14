# Development log — Multi-Branch Stock Manager

This log tracks the project phase by phase, in a lightweight agile/sprint style. Each phase records the goal, what was completed, key decisions made, issues hit (and how they were resolved), and what comes next.

Purpose: (1) keeps the project honest about actual progress vs plan, (2) gives real, dated evidence of iterative development for the dissertation's Methodology and Implementation chapters, (3) makes it easy to write the Implementation chapter later without trying to reconstruct the timeline from memory.

---

## Phase 0 — Foundation & planning
**Dates:** w/c 7 July 2026

**Goal:** Decide the technology stack and confirm it's buildable given real constraints (Mac storage issues, Windows availability).

**Completed:**
- Reviewed proposal content against dissertation template structure
- Decided tech stack: Flutter (Android + Web targets), Firebase (Firestore + Auth)
- Confirmed decision with supervisor — deviation from original iOS/Xcode plan is acceptable
- Repo created and anonymised (`multi-branch-stock-manager`, not the real business name)

**Decisions made:**
- Drop native iOS as a primary target (Mac access unreliable); keep it as an optional stretch goal
- Use Firebase Spark (free tier) — sufficient for dissertation-scale usage, zero cost

**Issues & resolutions:**
- None at this stage (planning only)

---

## Phase 1 — Development environment setup
**Dates:** w/c 7 July 2026

**Goal:** Get a fully working local Flutter development environment on Windows, confirmed by running a real app.

**Completed:**
- Installed Git, Claude Code, Flutter SDK, Android Studio
- Resolved multiple PATH/environment variable issues (Windows-specific)
- Enabled Developer Mode (required for Flutter plugin symlinks on Windows)
- Confirmed `flutter doctor` clean for Android + Web targets
- Ran default Flutter app successfully in Chrome

**Decisions made:**
- Skip Visual Studio / native Windows desktop target entirely — not needed for Android + Web plan

**Issues & resolutions:**
- Flutter SDK zip download failed once via PowerShell (connection dropped) → re-downloaded via browser instead, more reliable for large files
- Nested folder extraction issue (`flutter\flutter\bin` instead of `flutter\bin`) → manually corrected folder structure
- Multiple PATH-not-recognised errors → root cause was always stale terminal sessions; fixed by opening genuinely new terminal windows after each environment variable change
- OneDrive file-locking conflicts with Flutter's build folder (`ios/Flutter/ephemeral`, `build/flutter_assets`) → removed unused `ios`/`macos` folders; deleted and let Flutter regenerate `build/` when conflicts occurred

---

## Phase 2 — Firebase integration
**Dates:** w/c 7 July 2026

**Goal:** Connect the Flutter app to a real Firebase backend (Firestore + Authentication).

**Completed:**
- Created Firebase project (Spark/free plan) named to match the repo
- Enabled Cloud Firestore (test mode, `europe-west2`)
- Enabled Firebase Authentication (Email/Password provider)
- Installed FlutterFire CLI and Firebase CLI
- Ran `flutterfire configure` for Android + Web platforms
- Added `firebase_core`, `cloud_firestore`, `firebase_auth` packages
- Updated `main.dart` to initialise Firebase on app start
- Verified working connection in Chrome ("Firebase connected. Ready to build.")

**Decisions made:**
- Stay on Firebase Spark plan; avoid enabling Cloud Functions to prevent any billing risk
- Windows platform got registered in Firebase by accident (extra checkbox) — left as harmless, not used

**Issues & resolutions:**
- `flutterfire` command not recognised → same stale-PATH issue as Phase 1, fixed via fresh terminal
- Repo now contains `google-services.json` / `firebase_options.dart` — acceptable since repo is private; flagged as a reminder not to make the repo public without reviewing this

---

## Phase 3 — Data modelling (stock ledger design)
**Dates:** w/c 7 July 2026

**Goal:** Design and implement the core data models, refined through a real discussion of the business workflow (not just the original proposal's assumptions).

**Completed:**
- Revisited stock-tracking assumption: moved from "central stock only" to **central stock + per-branch stock**, since branches genuinely hold and use stock day to day
- Designed an **immutable ledger** (`stockMovements`) as the source of truth for all stock changes, instead of just mutating a single quantity field
- Decided "sold" data will be **manual daily entry by branch staff** (not synced from an existing POS/order system)
- Added a distinct `wasted` movement type, separate from `sold` — directly supports the project's cost/waste-reduction aim
- Implemented models: `BranchModel`, `UserModel`, `StockItemModel` (with reorder threshold), `StockMovementModel`, `OrderModel`
- `flutter analyze` passed clean with no errors

**Decisions made:**
- Reports (daily/weekly/monthly branch comparisons) will be built as filtered queries over the ledger, not as a separately maintained summary table
- Every ledger entry records `performedBy`, supporting both accountability and the project's data ethics/anonymisation commitments

**Issues & resolutions:**
- `Out-File` path error when trying to script-generate model files (folder didn't exist yet) → created files manually in VS Code instead, simpler for this scale of project
- Some model files initially saved as empty (0 bytes) due to paste/save mistakes → caught via `dir` listing showing file sizes, re-pasted content

---

## Phase 4 — Firestore service layer & authentication
**Dates:** 8 July 2026

**Goal:** Build the functions that read/write the models to Firestore, and implement working login gated by user role.

**Completed:**
- Built `FirestoreService` covering: stock items, restocking, placing orders, preparing orders (with stock deduction via transaction), marking delivered, confirming receipt (updates branch stock), daily sold/wasted logging, and ledger-based report queries
- Built `AuthService` (sign in, sign up, sign out, fetch profile)
- Built `LoginScreen` with email/password fields
- Wired `main.dart` to route between login and home screen based on auth state
- Created test user in Firebase Auth + matching Firestore `users` document
- Moved entire project from OneDrive-synced folder (`OneDrive\Desktop\Development\...`) to `C:\Users\dilmu\Dev\` to reduce recurring file-lock errors during builds
- Confirmed full login flow works end to end in Chrome

**Decisions made:**
- Firestore remains in test mode for now; proper security rules deferred until role-based screens exist to test against

**Issues & resolutions:**
- Recurring "Flutter failed to delete a directory" errors during `flutter run`/`flutter clean`, traced to a mix of OneDrive sync and likely antivirus real-time scanning — moving outside OneDrive reduced but didn't fully eliminate this; treated as a non-fatal cosmetic issue since builds still complete successfully
- `AuthService`/model "undefined" errors traced back to files that were missing or accidentally saved empty — resolved by checking actual file sizes with `dir` rather than assuming a paste worked

---

## Phase 5 — Branch order screen
**Dates:** 8 July 2026

**Goal:** Build the first functional screen — branch staff view available stock and submit an order.

**Completed:**
- Built `BranchOrderScreen` with a live Firestore stream of stock items and per-item quantity input
- Wired `main.dart` to show this screen after login
- Added a test `stockItems` document in Firestore for testing
- Confirmed order submission writes correctly to the `orders` collection
- Full flow tested end to end: login → view stock → place order → saved to Firestore

**Decisions made:**
- None beyond what was already established in earlier phases

**Issues & resolutions:**
- `main.dart` initially still referenced the old placeholder `Scaffold` instead of the new screen after a partial edit — fixed by replacing the `home:` block fully

---
## Phase 6 — Kitchen dashboard
**Dates:** 8 July 2026

**Goal:** Kitchen staff see all requested orders and can mark them as preparing, triggering central stock deduction.

**Completed:**
- Built `KitchenDashboardScreen` showing orders split by status (Requested / Preparing)
- Added role-based routing in `main.dart` (kitchenStaff → dashboard, others → branch order screen)
- Confirmed `prepareOrder()` transaction works correctly: order status updates, central stock quantity decreases, and a `stockMovements` ledger entry is created atomically
- Verified in Firestore Console: stock quantity and ledger entries both correct after preparing an order

**Issues & resolutions:**
- Role-based routing initially appeared not to work after editing `main.dart` — cause was stale app state from hot reload, not a code or data issue; resolved with a full stop/restart (`q` then `flutter run` again) rather than hot reload

-----------

## Phase 7 — Delivery screen
**Dates:** 8 July 2026

**Goal:** Delivery staff see orders ready for delivery and mark them as delivered.

**Completed:**
- Built `DeliveryScreen` showing orders split by status (Preparing / Delivered)
- Extended role-based routing in `main.dart` to three roles (kitchenStaff, delivery, branchStaff default)
- Confirmed full status flow end to end: requested → preparing → delivered, tested manually across three different logged-in roles

**Issues & resolutions:**
- None

-----------

## Phase 8 — Branch home hub, receive delivery & daily stock update
**Dates:** 14 July 2026

**Goal:** Give branch staff a proper home screen and complete their side of the stock loop — confirming deliveries and logging daily sold/wasted quantities against the ledger.

**Completed:**
- Built `BranchHomeScreen`: a hub with three tiles (Place an Order, Receive Delivery, Daily Stock Update) replacing the old direct-to-order-screen routing
- Built `ReceiveDeliveryScreen`: streams orders with status `delivered` for the branch, lets staff confirm receipt (`confirmReceived()`), which updates branch stock
- Built `DailyStockUpdateScreen`: streams stock items currently held at the branch, lets staff enter sold/wasted quantities per item, submits via `logDailyUsage()` per item to the ledger
- Updated `main.dart` routing so `branchStaff` lands on `BranchHomeScreen` instead of going straight to `BranchOrderScreen`
- Confirmed the branch-side loop end to end: home → receive delivery → confirm receipt updates stock; home → daily update → submit logs sold/wasted to ledger

**Decisions made:**
- Daily update submits all changed items in one batch action rather than per-row saves, to match how staff would realistically do it once at the end of a shift

**Issues & resolutions:**
- None

-----------

## Phase 9 — Manager dashboard & a real production bug found through testing
**Dates:** 14 July 2026

**Goal:** Give managers the branch-comparison reporting the data model was designed for (Phase 3), and manually walk the full order lifecycle end to end across all four roles to prove the app actually works, not just that each screen compiles.

**Completed:**
- Built `ManagerDashboardScreen`: a period selector (today / 7 days / 30 days / all time) over `streamMovements()`, showing total sold value, total wasted value, a waste-rate percentage, and a per-branch breakdown — all computed as filtered queries over the `stockMovements` ledger, per the Phase 3 decision
- Added `manager` branch to the role-based routing in `main.dart`
- Created four real test accounts (kitchen, delivery, manager, branch) and manually walked the entire lifecycle: place order → prepare (kitchen) → deliver → confirm receipt (branch) → log daily sold/wasted (branch) → verify totals on the manager dashboard

**Decisions made:**
- Report totals are valued at `costAtTime` recorded on each ledger entry (not current stock item cost), consistent with the ledger's immutability principle

**Issues & resolutions:**
- Manual testing found `ReceiveDeliveryScreen` silently showing "No deliveries waiting to be confirmed" even after a real delivery — traced to `FirestoreService.streamOrders(branchId: ...)`, which combines a `.where('branchId', ...)` filter with `.orderBy('createdAt')` on Firestore, a combination that requires a composite index. The index didn't exist, so the query failed with `FAILED_PRECONDITION`, and because the screen never checks `snapshot.hasError`, the failure rendered as an ordinary empty state instead of a visible error. This blocked the entire downstream chain: no confirmed receipt → branch stock never populated → nothing to log in Daily Stock Update → manager dashboard showed £0.00 despite orders having been prepared and delivered correctly
- Fixed by adding `firestore.indexes.json` (composite index on `orders`: `branchId` ASC, `createdAt` DESC) and deploying via `firebase deploy --only firestore:indexes`; re-ran the walkthrough afterwards and confirmed the manager dashboard shows correct non-zero sold/wasted values
- Noted as a gap worth addressing later: Firestore stream builders in this app generally don't surface `snapshot.hasError`, so future index/permission errors would fail the same silent way; also, Firestore is still in test mode with rules due to expire roughly 30 days after being enabled — proper security rules are the next priority