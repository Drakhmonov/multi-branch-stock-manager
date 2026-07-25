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

-----------

## Phase 10 — Firestore security rules & closing the double-receive gap
**Dates:** 14 July 2026

**Goal:** Replace the open test-mode rules with real role-based security rules now that all four role screens exist to test against, and re-run the full lifecycle to confirm nothing regresses.

**Completed:**
- Wrote `firestore.rules`: role read/write scoping per collection — `users` self-read-only and not client-editable (no self role escalation); `stockItems` readable by all, writable by kitchen/manager; `branchStock` and `orders` scoped to the owning branch for branch staff, broader visibility for kitchen/delivery/manager; `stockMovements` create-only for the relevant role and never updatable/deletable, matching the immutable-ledger design from Phase 3
- Wired `firebase.json` to the new rules file and deployed via `firebase deploy --only firestore:rules`; confirmed unauthenticated access is now rejected (`PERMISSION_DENIED`)
- Added a `received` `OrderStatus` and had `confirmReceived()` advance the order to it as part of the existing transaction, so a confirmed delivery is distinguishable from one still awaiting confirmation
- Split `ReceiveDeliveryScreen` into three states — "No order" (nothing at all), "Receive Order" (delivered, awaiting confirmation), "Received Order" (confirmed) — matching the section pattern already used in the kitchen and delivery screens
- Re-ran the full four-role walkthrough end to end against the deployed rules to confirm nothing broke

**Decisions made:**
- None beyond what's captured in the fixes below

**Issues & resolutions:**
- The Branch test account had no `branchId` set in Firestore; the app's Dart-side `?? 'unknown'` fallback had been masking this, but security rules compare against the real stored field, so orders/receipts would have been silently rejected. Fixed by setting a real `branchId` on the account before deploying rules
- First deploy of the `branchStock` read rule denied `confirmReceived()` on any brand-new branch+item combo: the rule read `resource.data.branchId`, but a transactional `get()` on a not-yet-existing document has `resource == null`, so the comparison errored and denied. Fixed by explicitly allowing `resource == null` in that rule
- Caught, independent of the rules work: `confirmReceived()` never changed the order's status, so a confirmed delivery stayed flagged `delivered` forever — nothing prevented branch staff from tapping "Confirm Received" twice on the same order and double-counting stock. Fixed by advancing the order to `received` in the same transaction and updating the UI/rules to match

-----------

## Phase 11 — Branch management, self-service sign-up, and a correction workflow
**Dates:** 22 July 2026

**Goal:** Make "multi-branch" a real, in-app feature rather than a manual Firebase Console step, and close two gaps surfaced by actually using the app: no way to review branch history, and no way to fix a mistaken daily-usage entry given the immutable ledger.

**Completed:**
- Added `branches` CRUD to `FirestoreService` (`streamBranches()`, `addBranch()`) and a manager-only `BranchManagementScreen` to create branches from the UI instead of the Firebase Console
- Added `SignUpScreen`: new branch/kitchen/delivery staff can self-register, with a branch dropdown sourced live from the real `branches` collection; deliberately excludes the `manager` role from self-signup, with `firestore.rules` enforcing the same restriction server-side (self-created `users` docs can never set `role: manager`)
- Resolved `branchId` to real branch names everywhere it was previously shown raw: `ManagerDashboardScreen`'s per-branch breakdown, `KitchenDashboardScreen` and `DeliveryScreen` order lists, and `BranchHomeScreen`'s title — via a new shared `streamBranchNames()` helper
- Added `BranchHistoryScreen`, reachable from a new "History" tile on the branch home hub: streams that branch's full `stockMovements` ledger (sold/wasted/received/corrections), sorted newest-first client-side
- Added a stock correction workflow: a "Log Correction" action on the history screen writes a signed `adjustment` movement (positive restores stock, negative removes more) with a required reason, rather than editing the original entry — keeping the ledger immutable while still giving branch staff a way to fix a mistake, with both the original entry and the fix visible in history
- Added an optional `note` field to `StockMovementModel` to carry the correction reason
- Updated `firestore.rules`: branch staff can now create `adjustment` movements (previously only `received`/`sold`/`wasted`); `branches` reads are now public (`allow read: if true`) rather than requiring sign-in

**Decisions made:**
- Manager accounts stay a manual Console step; only branch/kitchen/delivery are self-service, to avoid a public sign-up flow letting anyone grant themselves manager-level visibility into financials
- Corrections are modeled as a new ledger entry, not an edit, consistent with the Phase 3 immutable-ledger decision — mistakes stay visible instead of being silently overwritten

**Issues & resolutions:**
- The sign-up screen's branch dropdown initially came back empty even though branches existed in Firestore: `streamBranches()` requires `isSignedIn()` per the original rule, but a new user isn't authenticated yet at sign-up time, so the read silently failed and the dropdown had nothing to show — the same "stream fails silently, UI doesn't check `hasError`" class of bug flagged back in Phase 9. Fixed by making `branches` reads public, since branch names/locations aren't sensitive and a pre-signup user has no other way to see them
- "Create an account" originally used `Navigator.push` to show the sign-up screen on top of the login screen. On success, the app's top-level auth state updated correctly underneath, but the pushed route stayed on top of the navigator stack, so the screen never visibly changed — the user had no confirmation and, on retrying, hit "email already in use" from their first (actually successful) attempt. Fixed by making sign-up a top-level sibling of the login screen (matching how `main.dart` already switches screens on role), removing the stale route entirely, and adding an explicit "Account created" `SnackBar` via a `ScaffoldMessengerKey` that survives the screen swap
- Twice during this phase, edits made to the running `flutter run` session weren't reflected in the browser — `flutter run` requires an explicit hot reload/restart trigger that isn't available when driven through a non-interactive background shell. Resolved by killing and relaunching the dev process after each batch of changes; worth automating properly (e.g. a VM service hot-reload call) if this keeps coming up

-----------

## Phase 12 — Responsive layout & adaptive navigation
**Dates:** 22 July 2026

**Goal:** Make the app read as a real mobile/web app rather than a single mobile screen stretched onto a browser tab — width-constrained content on wide viewports, and a persistent adaptive nav shell for the multi-screen roles instead of push/back navigation.

**Completed:**
- Added `ResponsiveBody` (`lib/widgets/responsive_body.dart`): centers content and caps its width on wide viewports; used across every screen (narrower for the login/sign-up forms, wider for lists/dashboards)
- Added `AdaptiveNavShell` (`lib/widgets/adaptive_nav_shell.dart`): the standard Material 3 adaptive scaffold — a `NavigationRail` above a 700dp breakpoint, a bottom `NavigationBar` below it — with a two-line app bar title (destination name + branch/user context) and a sign-out action
- Rebuilt `BranchHomeScreen` (4 destinations: Order/Receive/Daily Update/History) and `ManagerDashboardScreen` (Dashboard/Branches) on top of the shell, replacing their old tile-list-plus-push-navigation and icon-button-to-a-pushed-screen patterns respectively; `KitchenDashboardScreen` later gained a second destination the same way in Phase 13
- Added a sign-out action (there was previously no way to log out of the app at all — `AuthService.signOut()` existed but nothing called it), wired through `main.dart` back to the login screen

**Decisions made:**
- Single 700dp breakpoint (not Material's full 3-tier window-size-class system) — enough for a two-mode rail/bottom-nav swap without over-engineering for this app's scope

**Issues & resolutions:**
- None beyond the general `flutter run` hot-reload friction already noted in Phase 11 (recurring throughout the session — resolved the same way, by killing and relaunching)

-----------

## Phase 13 — Packaged stock items, kitchen catalog management, and follow-on fixes
**Dates:** 22-23 July 2026

**Goal:** Support real kitchen items that come in packs/containers (dumplings in bags, oil in 20L cans, chilli oil in packs of 6) rather than a single flat unit, and give kitchen staff an actual UI to add/restock/edit/remove catalog items — `addStockItem()` and `restock()` had existed since Phase 4 but nothing had ever called them.

**Completed:**
- `StockItemModel`: renamed `unit` → `pieceUnit`, added `packLabel`/`piecesPerPack`/`costPerPack`; `costPerUnit` (cost per piece) stays the value every ledger/report calculation already used, now derived from `costPerPack / piecesPerPack` — kept orders, deliveries, and the underlying ledger entirely in pieces, so only the catalog/restock layer needed to become pack-aware
- Added `StockCatalogScreen` (kitchen): search, full item detail (pack composition, stock in pieces *and* packs, cost, low-stock tint using the `reorderThreshold` field that had sat unused since Phase 3), and Add/Restock/Edit/Delete actions backed by new/updated `FirestoreService` methods (`addStockItem`, `restock`, `updateStockItemDetails`, `deleteStockItem`)
- Extended the adaptive shell from Phase 12 to `KitchenDashboardScreen` (Orders + Stock Catalog destinations)
- Added a search bar to `BranchOrderScreen`
- Extended pack-awareness to where branch staff actually interact with packaged items: `BranchOrderScreen` ("Available centrally" and the order quantity field show/accept packs, e.g. bags) and `DailyStockUpdateScreen` ("Currently held" and Sold/Wasted fields do the same) — both convert to pieces before touching Firestore, so the ledger and every report stay exactly as precise as before (still logging in individual pieces, per the original design choice for this screen)

**Decisions made:**
- Orders/deliveries/daily-usage stay in pieces internally always; packs are purely a UI convenience layered on top (input and display convert to/from pieces), not a second unit tracked through the system — kept the blast radius to the catalog/restock layer plus a thin conversion at each branch-facing input

**Issues & resolutions:**
- The new search bars on `BranchOrderScreen`/`StockCatalogScreen` initially made typing impossible — no characters would appear, backspace didn't work, and focus dropped after every keystroke. Root cause: every screen's `StreamBuilder` called `_firestoreService.streamXxx()` directly inside `build()`, creating a brand-new `Stream` object on every rebuild; the search field's `onChanged` called `setState` on every keystroke, so each keystroke recreated the stream, which reset `StreamBuilder` to its loading state and tore down the whole subtree — including the text field being typed into. Fixed by caching every such stream once (`late final` field) instead of recreating it in `build()`, across every screen with this pattern, not just the two with search bars
- Preparing or confirming an order with more than one line item failed with a Firestore transaction error; single-item orders worked fine. Root cause: `prepareOrder()` and `confirmReceived()` looped over the order's items doing a read then writes per item — Firestore transactions require every read in a transaction to happen before any write, and the second item's read came after the first item's writes. Fixed by restructuring both methods into two passes: read every item doc first, then perform all the writes

-----------

## Phase 14 — Closing the silent stream-failure gap
**Dates:** 23 July 2026

**Goal:** Fix the technical debt item flagged back in Phase 9 and reiterated in Phase 13: every `StreamBuilder` in the app renders its ordinary empty-state message on a stream error (`snapshot.hasError` is never checked), so a real failure — a missing composite index, a permissions rejection, a dropped connection — looks identical to "there's genuinely nothing here." Phase 9's £0.00 dashboard bug was a direct instance of this class of bug; nothing since had actually closed the gap for the other ten screens that share the pattern.

**Completed:**
- Added `StreamErrorView` (`lib/widgets/stream_error_view.dart`): a small shared widget showing an error icon, a plain-language message, and the underlying error text, for use wherever a stream's failure needs to be visible instead of swallowed
- Audited all 11 screens using `StreamBuilder` and added a `snapshot.hasError` check, ahead of the existing loading/empty checks, to every stream whose failure would actually block or mislead the user: `BranchOrderScreen`, `StockCatalogScreen`, `ManagerDashboardScreen` (movements), `KitchenDashboardScreen` (orders), `DeliveryScreen` (orders), `BranchManagementScreen`, `ReceiveDeliveryScreen`, `SignUpScreen` (branch dropdown — a required field for branch-staff sign-up), and both streams in `DailyStockUpdateScreen` (items and the branch's own stock levels)
- `BranchHistoryScreen`: added the same `hasError` handling to its primary movements stream; for the secondary items stream (used only to populate the "Log Correction" dialog), disabled the correction FAB with an explanatory `SnackBar` on failure instead of letting it open a dialog with no items to select
- Ran `flutter analyze` (clean) and did a headless smoke test — launched `flutter run -d chrome`, confirmed the dev server compiled and served the app with no exceptions in the Flutter run log, then shut it down

**Decisions made:**
- Not every `StreamBuilder` got this treatment. Several screens (`BranchHomeScreen`, and the `branchNamesStream` used inside `KitchenDashboardScreen`/`DeliveryScreen`/`ManagerDashboardScreen`) only use their stream to resolve a branch ID to a display name; on failure they already degrade gracefully to showing the raw ID instead of hiding a real functional problem, so these were deliberately left alone rather than adding a full-screen error state for a cosmetic label
- Chose one shared `StreamErrorView` widget over ad hoc per-screen error text, so the failure state reads consistently across the app and is a single place to improve later (e.g. adding a retry action)

**Issues & resolutions:**
- The Claude Code browser extension wasn't connected in this environment, so the usual click-through UI verification wasn't possible. Substituted `flutter analyze` plus a `flutter run -d chrome` smoke test (server compiles, serves HTTP 200, no exceptions in the run log) as a lower-confidence stand-in; a full manual walkthrough of the error paths (e.g. temporarily pointing a stream at a nonexistent collection) is still worth doing by hand before relying on this in the dissertation write-up

-----------

## Phase 15 — Order status timeline & unified order visibility
**Dates:** 23 July 2026

**Goal:** An order's journey (requested → preparing → delivered → received) was scattered and one-directional — `OrderModel` only ever stored `status` and `createdAt`, so there was no record of when each later step happened or who did it, and no single screen showed a order's whole progression. Worse, branch staff had no screen at all showing an order between "I placed it" and "it's been delivered": `BranchOrderScreen` only places new orders, and the old `ReceiveDeliveryScreen` only showed delivered/received ones. Add real-time status with per-step timestamps, visible with the order itself rather than a separate history screen, across all four roles including the manager dashboard.

**Completed:**
- `OrderModel`: added `preparingAt`/`preparedByName`, `deliveredAt`/`deliveredByName`, `receivedAt`/`receivedByName` (all nullable, so existing orders without them still deserialize). Timestamps stored as ISO8601 strings, matching how `createdAt` already worked in this model
- `FirestoreService`: `prepareOrder()`, `markDelivered()` (previously took no actor at all), and `confirmReceived()` now record each transition's timestamp and the acting user's display name alongside the status change; added `streamOrder(orderId)` for a live single-document subscription
- Deliberately denormalized the actor's **name** rather than uid onto the order doc — `users/{uid}` docs are locked to self-read-only in `firestore.rules`, so no other role could resolve a uid to a name anyway, and the uid-level audit trail already exists via `stockMovements.performedBy` linked through `relatedOrderId`. Avoided a rules change to `users` or a new cross-user lookup entirely
- Added `OrderStatusTimeline` (`lib/widgets/order_status_timeline.dart`): a vertical stepper showing all four steps, with timestamp + "by {name}" for steps reached and a greyed-out marker for steps not yet reached
- Added `showOrderDetailSheet()` (`lib/screens/order_detail_sheet.dart`): a live-updating bottom sheet (via `streamOrder`) showing the item list plus the timeline; every order card across the app now opens this on tap
- Broadened `ReceiveDeliveryScreen` from "delivered + received only" to stream and show **all** of a branch's orders, grouped into Requested/Preparing/Receive Order/Received Order sections — this is the piece that actually closes the branch-visibility gap. Renamed its `BranchHomeScreen` destination label from "Receive" to "Orders" to match
- Added an "Orders" destination to `ManagerDashboardScreen` (`_ManagerOrdersBody`): every order across all branches, status-tinted, tappable to the same detail sheet
- Made every existing order card in `KitchenDashboardScreen` and `DeliveryScreen` tappable to the detail sheet too, without changing their existing status-filtered queue sections (still useful as an action queue for those roles)
- Lifted the timestamp formatter that `BranchHistoryScreen` had locally (`_formatTimestamp`) into a shared `lib/utils/format.dart`, now used by both it and the new timeline widget, rather than writing a third copy
- Updated `firestore.rules`: each order-status transition's `hasOnly([...])` field allow-list now includes that step's new timestamp/name fields (previously `['status']` only) — otherwise the new writes would have been silently rejected, the same class of gap as Phase 10's `resource == null` miss. Redeployed via `firebase deploy --only firestore:rules`
- Ran `flutter analyze` (clean) and a `flutter run -d chrome` smoke test (compiles, serves HTTP 200, no exceptions in the run log)

**Decisions made:**
- Real-time was free — every screen already streams from Firestore, so no extra work was needed beyond persisting the per-step data; this phase is purely about data model + display
- Kitchen and delivery keep their existing status-grouped sections rather than switching to a flat "all orders" list like the branch/manager views — those groupings are genuinely how those roles work through a queue, and the full timeline is one tap away regardless
- Notifications (push or in-app) for status changes are explicitly out of scope for this phase, per the user's own framing of it as a later step. True push notifications while the app is closed would need Cloud Functions + FCM, which conflicts with the Phase 0/2 decision to avoid Cloud Functions for billing-risk reasons on the Spark plan — noted as a trade-off to revisit explicitly when that work is picked up, not assumed
- `OrderStatus.cancelled` remains defined but unused (never set anywhere in the app); left untouched

**Issues & resolutions:**
- None — the Phase 10 rules gotcha (new fields need explicit allow-listing in `hasOnly`) was anticipated up front from reading the existing rules before writing the model changes, rather than being discovered by a failed write after the fact
- As in Phase 14, the browser extension wasn't connected in this environment, so verification was `flutter analyze` + a compile/serve smoke test rather than a full click-through of the four-role order lifecycle; that manual walkthrough (place → prepare → deliver → confirm, checking the timeline fills in correctly at each stage from every role's screen) is still worth doing by hand

-----------

## Phase 16 — Orderer identity, per-step notes, and kitchen quantity adjustments
**Dates:** 23 July 2026

**Goal:** Extend Phase 15's order timeline with three related pieces flagged as natural follow-ons: who placed an order and any note they attached, an optional note kitchen/delivery/branch can leave at their own step, and — the one that actually changes behaviour — letting kitchen send a different quantity than was requested, or add an item that wasn't originally ordered, when they prepare it.

**Completed:**
- `OrderItem`: added nullable `fulfilledQuantity` — null until kitchen prepares the order, then set to whatever was actually sent (may differ from the original `quantity`). A kitchen-added item not on the original order is just a line with `quantity: 0` and a `fulfilledQuantity` set — no second list needed
- `OrderModel`: added `placedByName` (denormalized at `placeOrder()` time, same pattern as Phase 15's `preparedByName`/etc., falling back to `'Unknown'` for pre-Phase-16 orders), `note` (the branch's note when placing), and `preparingNote`/`deliveredNote`/`receivedNote` (one per transition, mirroring the existing timestamp fields)
- `FirestoreService.prepareOrder()` now takes the kitchen-edited item list rather than reading straight off the order, deducts central stock and logs `orderDeducted` movements by `fulfilledQuantity`, and persists the edited list back onto the order so later steps see what was actually sent. `confirmReceived()` switched the branch-stock increase and `received` movement quantity from `quantity` to `fulfilledQuantity ?? quantity`, so a branch's stock after confirming reflects what actually arrived, not what was originally asked for. `placeOrder()`/`markDelivered()`/`confirmReceived()` all gained an optional `note` param
- `KitchenDashboardScreen`: replaced the one-tap "Prepare" button with a dialog (same `showDialog`/`StatefulBuilder` pattern as `StockCatalogScreen`'s Add/Restock/Edit dialogs) listing each requested item with an editable "sending" quantity defaulting to what was requested, an "Add item" control sourced from the stock catalog for anything not originally requested, and an optional note
- Added a shared `showConfirmWithNoteDialog()` (`lib/widgets/confirm_with_note_dialog.dart`) — a small confirm-plus-optional-note dialog — used by `DeliveryScreen`'s "Mark Delivered" and `ReceiveDeliveryScreen`'s "Confirm Received", both previously one-tap actions
- `BranchOrderScreen` gained an optional note field on the order form; the placing branch staff's name is now captured automatically
- `OrderStatusTimeline`: each step now shows its note (in quotes, under the timestamp) when one was left; `order.note` renders on the Requested step
- Lifted the order-items summary line — duplicated across `KitchenDashboardScreen`, `DeliveryScreen`, `ReceiveDeliveryScreen`, `ManagerDashboardScreen`'s Orders tab, and `order_detail_sheet.dart` (five copies) — into a shared `orderItemsSummary()` in `lib/utils/format.dart`, which also now shows "requested X, sent Y" wherever a fulfilled quantity differs from what was asked
- `order_detail_sheet.dart` header now shows who placed the order
- Updated `firestore.rules`: kitchen's `requested → preparing` transition's `hasOnly([...])` now also allows `items` and `preparingNote`; delivery's allows `deliveredNote`; branch's allows `receivedNote`. Redeployed via `firebase deploy --only firestore:rules`
- Ran `flutter analyze` (clean) and a `flutter run -d chrome` smoke test (compiles, serves HTTP 200, no exceptions in the run log)

**Decisions made:**
- Kept a single `items` list with a `fulfilledQuantity` field per line, rather than two parallel "requested" and "fulfilled" lists — one row per item either way, and a kitchen-added item is just a natural edge case (`quantity: 0`) rather than a separate concept
- Rules don't deep-validate that kitchen only changed `fulfilledQuantity` per line and left `stockItemId`/`name`/`quantity` alone — that would need Cloud Functions. Treated as consistent with the existing trust model rather than a new gap: kitchen already has direct write access to `stockItems` quantities
- Notes are attached to the step they were entered at, not surfaced as a separate collection — matches the "status has to appear with the order" framing this whole timeline feature started from

**Issues & resolutions:**
- None. As in Phases 14–15, the browser extension wasn't connected in this environment, so verification stayed at `flutter analyze` + a compile/serve smoke test; a full manual walkthrough (place with a note → prepare with an adjusted quantity and an added item → deliver with a note → confirm with a note, checking the timeline and that branch stock reflects fulfilled rather than requested quantities) is still worth doing by hand

-----------

## Phase 17 — Automated test suite, and a real formatting bug it caught
**Dates:** 24 July 2026

**Goal:** The project had zero real test coverage — `test/widget_test.dart` was still Flutter's default counter-app smoke test, unrelated to this app entirely, and (confirmed by actually running it) already failing outright. Add a real automated test suite ahead of submission.

**Completed:**
- Deleted the stale default `test/widget_test.dart`
- Added pure Dart unit tests for every model's `toMap`/`fromMap` round-trip and its fallback/defaulting behaviour for old or malformed data: `test/models/{branch,user,stock_item,stock_movement,order}_model_test.dart` — including `OrderModel`'s Phase 15/16 fields (e.g. pre-Phase-16 orders without `placedByName` falling back to `'Unknown'`, unknown `status`/`type` strings falling back to their safe defaults, `StockItemModel`'s legacy `unit`/`costPerUnit` fallbacks from Phase 13)
- Added `test/utils/format_test.dart` covering `formatTimestamp` and `orderItemsSummary`
- Added widget tests for the two presentational widgets that don't touch Firestore: `test/widgets/order_status_timeline_test.dart` (reached vs unreached steps, notes rendering) and `test/widgets/stream_error_view_test.dart`
- Writing the `orderItemsSummary` tests surfaced a real, previously unnoticed bug: every quantity display in the app (`Buns x10`, `Available centrally: 40 pcs`, etc.) was actually rendering as `Buns x10.0` — `OrderItem.quantity`/`StockItemModel.currentQty`/`StockMovementModel.quantity` are all `double` (to allow fractional units like kg), and every screen interpolated them directly with no formatting. This wasn't a Phase 16 regression — the exact same pattern was there since `BranchOrderScreen` in Phase 5, just never noticed because nobody was asserting the exact display string until now
- Fixed it properly rather than just in the tested function: added `formatQty()` to `lib/utils/format.dart` (shows a plain integer for whole numbers, keeps the decimal for genuinely fractional quantities) and applied it everywhere a raw quantity was being interpolated — `orderItemsSummary`, `BranchHistoryScreen`'s signed adjustment display, `BranchOrderScreen`'s "Available centrally" label, `StockCatalogScreen`'s stock label, and `DailyStockUpdateScreen`'s "Currently held" label
- 33 tests passing, `flutter analyze` clean

**Decisions made:**
- Scoped tests to pure model logic and Firebase-free widgets only; deliberately did not add `fake_cloud_firestore` or a Firebase emulator to test `FirestoreService` or the screens that stream from it directly — that's real added complexity (and this project has already hit enough Windows-specific tooling friction, per Phases 1 and 11) for value that's lower priority than getting solid coverage on the parts that don't need it. Documented as a scoping decision, not an oversight, in case it's asked about
- Prioritized model round-trip tests over UI snapshot-style tests: the model layer is where Phase 15/16's nullable-field fallback logic actually lives and is the highest-value thing to pin down before submission

**Issues & resolutions:**
- Confirmed the pre-existing test actually failed (`flutter test` before this phase: 0 passing, 1 failing) rather than just assuming it was stale — worth having actually run it rather than taking "probably broken" on faith
- The `formatQty` bug is a good illustration of why the tests were worth writing: it wasn't caught by 16 phases of manual testing or `flutter analyze`, only by writing a test that pinned down the exact expected string

-----------

## Phase 18 — Visual polish pass
**Dates:** 24 July 2026

**Goal:** The UI had been functionally complete since Phase 12's responsive/adaptive-nav work but visually plain — default Material widgets with status colors picked ad hoc per screen (`Colors.amber[50]`, `Colors.green[50]`, `Colors.red[50]`, `Colors.blue[50]`) that had no relationship to the app's actual seeded color scheme. Also removed the debug banner, which had been sitting in the corner of every screenshot/demo since Phase 1.

**Completed:**
- `debugShowCheckedModeBanner: false` in `main.dart`
- Added `lib/theme/app_theme.dart`: a proper `ThemeData` (moved out of the inline `ThemeData(...)` that had been sitting directly in `main.dart` since Phase 1) with `cardTheme`, `inputDecorationTheme`, `elevatedButtonTheme`/`filledButtonTheme`, `dialogTheme`, `navigationRailTheme`/`navigationBarTheme`, and `appBarTheme` all set consistently — rounded corners, flat/tonal surfaces instead of hard drop shadows, filled form fields
- Added a `StatusColors` `ThemeExtension` for the one semantic role Material 3 doesn't ship by default (a "success" green) — registered on the theme so it stays seeded/harmonious rather than a raw literal color
- Replaced every ad hoc status color with a theme-derived one: `tertiaryContainer` for "preparing", `secondaryContainer` for "delivered" (manager's cross-branch view only, which needs to distinguish all four statuses at once), the new `StatusColors.successContainer` for each role's own terminal "done" state, `errorContainer` for low-stock warnings — across `KitchenDashboardScreen`, `DeliveryScreen`, `ReceiveDeliveryScreen`, `ManagerDashboardScreen`, `StockCatalogScreen`
- Normalized a handful of hardcoded `TextStyle(fontWeight: FontWeight.bold, fontSize: 16)`-style headings (manager dashboard's "By branch"/waste-rate card, the kitchen prepare dialog's section headings) to the theme's `textTheme` scale instead
- Ran `flutter analyze` (clean), `flutter test` (33 passing, unaffected), and a `flutter run -d chrome` compile/serve smoke test

**Decisions made:**
- Scoped to "polished Material 3" rather than a custom/bespoke design system, per explicit direction — kept the existing component set (Card, ListTile, NavigationRail/Bar, AlertDialog) and made it feel intentional through theming, rather than replacing components or restructuring layouts
- Used Material 3's own tonal container roles (`tertiaryContainer`, `secondaryContainer`, `errorContainer`) wherever they already fit the semantic need, and only added one custom color (`successContainer`, via a proper `ThemeExtension`) for the one role — a semantic "success" green — that Material 3 doesn't provide out of the box

**Issues & resolutions:**
- None. As in recent phases, verification stayed at `flutter analyze` + `flutter test` + a compile/serve smoke test — the browser extension still isn't connected in this environment, so the actual visual result hasn't been eyeballed by either of us yet; worth a quick look before treating this as final, since exact tonal hues from `ColorScheme.fromSeed` can only really be judged by looking at them

-----------

## Phase 19 — Branch comparison chart on the manager dashboard
**Dates:** 24 July 2026

**Goal:** The manager dashboard's "By branch" section was a flat list of `Sold: £X   Wasted: £Y` text per branch — exactly the kind of comparison that's slow to scan and easy to miss an outlier in. Add a chart to make cross-branch comparison genuinely useful for spotting a problem branch at a glance, per the user's own framing (chosen over dark-mode/animations/etc. as the actual value-add for decision-making).

**Completed:**
- Added the `fl_chart` package (the standard Flutter charting library) — first new dependency beyond Firebase since Phase 0
- Added `BranchComparisonChart` (`lib/widgets/branch_comparison_chart.dart`): a grouped bar chart, one group per branch, Sold vs Wasted value as two bars per group, with a tap tooltip and a legend
- Colors chosen deliberately, not picked by eye: sold/wasted are two independent magnitudes, not a status, so rather than an intuitive-but-arbitrary red/green pairing they get the first two slots of a fixed categorical color order, validated colorblind-safe by running the six-check validator script (`worst adjacent ΔE 24.7 protan / 33.6 normal-vision`, both well clear of the safety floor) rather than eyeballed
- Y-axis rounds to a clean max (1/2/5 × a power of ten — `_niceMaxY`) so gridlines land on round £ values instead of an arbitrary max like "£1,347"
- Wired into `ManagerDashboardScreen`'s `_ManagerDashboardBody`, between the waste-rate card and the existing "By branch" list — the chart handles at-a-glance comparison, the list stays underneath as the exact-figures table view, per branch totals now computed once (`branchTotals`) and shared between both instead of being duplicated
- `flutter analyze` clean, `flutter test` (33 passing, unaffected), `flutter run -d chrome` compile/serve smoke test

**Decisions made:**
- Grouped (clustered) bars, not stacked — sold+wasted stacked would visually imply a combined "total" that isn't a meaningful business figure; grouped keeps the two magnitudes directly comparable per branch without a misleading implied sum
- Picked `fl_chart` over a hand-rolled bar widget when asked — one new dependency, but it's pure client-side with no billing/cost implications (unlike the Cloud Functions avoided since Phase 0), and gives tap tooltips and clean axis rendering for a lot less code than building it by hand
- Kept the existing per-branch list rather than replacing it with the chart — the chart is for spotting an outlier fast; the list is still what you'd read for an exact number, consistent with treating a chart as an addition to, not a replacement for, the underlying data

**Issues & resolutions:**
- None. Verification stayed at the same level as recent phases (analyze/test/compile-serve, no live browser click-through) — worth actually looking at the rendered chart before relying on it, same caveat as Phase 18's theme work

-----------

## Phase 20 — Fixed order quantities showing in pieces instead of packs everywhere
**Dates:** 24 July 2026

**Goal:** User-reported bug: the kitchen "Prepare Order" dialog was showing a packaged item like dumplings in raw pieces (e.g. "40") rather than the packs a branch actually ordered in (e.g. "2 bags"), with no unit label at all. Checking "other places" as asked surfaced the same gap across every order-display surface built in Phases 15–16: `orderItemsSummary()` and the kitchen prepare dialog's quantity inputs never got the pack-awareness Phase 13 gave `BranchOrderScreen` and `DailyStockUpdateScreen` — those two screens convert between packs and pieces at the input layer; everything order-related added after them (order detail sheet, kitchen/delivery/receive-delivery lists, the manager Orders tab) never did.

**Completed:**
- Added `formatItemQty()` (`lib/utils/format.dart`): given a piece count and a catalog item, shows packs with the piece count alongside for a packaged item ("2 bags (40 pcs)"), the piece unit for an unpackaged one ("10 pcs"), or a bare number if the catalog entry isn't available — same convention `_availableLabel`/`_heldLabel`/`_stockLabel` already used
- `orderItemsSummary()` now takes a `Map<String, StockItemModel>` catalog lookup (order items themselves only ever store a raw piece quantity, never pack composition, so the catalog has to be joined in at display time) and uses `formatItemQty` throughout, including the requested-vs-sent and added-item cases
- `KitchenDashboardScreen`'s prepare dialog: quantity fields now display and accept **packs** for a packaged item (converting to/from pieces on submit, the same conversion `BranchOrderScreen`'s order form already does) instead of a bare piece count with no unit at all; added a "Requested: X" line per item so kitchen can see the original ask while adjusting, which the dialog previously didn't show anywhere
- Threaded a stock-items catalog stream into every screen that renders `orderItemsSummary` but didn't already have one: `order_detail_sheet.dart` (converted from `StatelessWidget` to `StatefulWidget` so the stream could be cached instead of recreated on every rebuild, per the Phase 13 stream-caching rule), `delivery_screen.dart`, `receive_delivery_screen.dart`, `manager_dashboard_screen.dart`'s Orders tab
- Extended `test/utils/format_test.dart` with real coverage of the conversion (packaged vs unpackaged, singular "1 bag" vs plural "2 bags", fractional packs, requested-vs-sent in packs, unknown-item fallback) — 39 tests passing, up from 33
- Deliberately left `BranchHistoryScreen`'s ledger view alone — it already labels its raw piece counts clearly (`"Dumplings (pcs)"`) and is a precise historical record by design (Phase 13), not something read to act on in packs
- `flutter analyze` clean, `flutter run -d chrome` compile/serve smoke test

**Decisions made:**
- Order items store only a raw piece quantity, never pack composition (a deliberate Phase 13 boundary — "packs are purely a UI convenience layered on top, not a second unit tracked through the system") — so display-time pack conversion has to join against the live stock catalog rather than reading it off the order itself, and degrades to a bare piece count if the catalog item's since been deleted

**Issues & resolutions:**
- None new. Same verification caveat as Phases 18–19 — no live browser click-through was possible in this environment, so it's worth actually opening the kitchen prepare dialog on a real packaged item and confirming the pack math looks right before relying on it

-----------

## Phase 21 — Split "preparing" into Start Preparing / Ready to Deliver
**Dates:** 25 July 2026

**Goal:** Kitchen had one action, "Prepare," that did everything at once — opened the quantity-adjustment dialog, deducted central stock, and jumped the order straight from `requested` to `preparing`, which was actually the last state kitchen ever set (delivery picked up straight from there). There was no way to signal "we've started on this" separately from "this is boxed and ready to go," and no status anyone else could see in between. User-requested: split into two real kitchen actions with a new status in between, reflected consistently across every screen that shows order status.

**Completed:**
- `OrderStatus`: inserted `prepared` between `preparing` and `delivered`
- `OrderModel`: renamed `preparedByName` → `preparingByName` (it captured the old single "advance to preparing" step, which under the new semantics is the **Start Preparing** step — the name now says what it means); added `preparedAt`/`preparedByName`/`preparedNote` for the new **Ready to Deliver** step, where fulfilled-quantity finalization now happens
- `FirestoreService`: added `startPreparing(orderId, performedByName, {note})` — a simple status-only update (`requested → preparing`), no stock movement, mirroring `markDelivered`'s shape. Renamed `prepareOrder()` → `markPrepared()`; same transaction body (deduct central stock by `fulfilledQuantity`, log `orderDeducted` movements, persist the edited `items` list) but now guards/sets `preparing → prepared` instead of `requested → preparing`
- `KitchenDashboardScreen`: three sections instead of two — **Requested** (new lightweight "Start Preparing" button via the shared `showConfirmWithNoteDialog`, no quantity editing), **Preparing** (the existing quantity-adjustment dialog, retitled "Ready to Deliver," now fires here instead of at Requested), **Prepared / awaiting delivery** (read-only, same shape the old "awaiting delivery" section had) — this is the literal "add prepared items" ask
- `DeliveryScreen`'s "Ready for delivery" section now filters on `prepared` instead of `preparing`
- `receive_delivery_screen.dart` (branch's Orders tab) gained a "Prepared" section between Preparing and Receive Order, tinted `primaryContainer` to stay visually distinct from Preparing's `tertiaryContainer`
- `ManagerDashboardScreen`'s Orders tab: added `prepared` to both the status label and status color mapping (`primaryContainer`, matching the branch screen's choice)
- `OrderStatusTimeline`: inserted a "Prepared" step between "Preparing" and "Delivered," wired to the new fields; "Preparing" step now reads the renamed `preparingByName`
- Updated `firestore.rules`: kitchen now has two guarded transitions (`requested → preparing` with only status/preparingAt/preparingByName/preparingNote; `preparing → prepared` with the `items` rewrite allowance that used to live on the single kitchen transition); delivery's precondition moved from `preparing` to `prepared`. Redeployed
- Fixed `test/models/order_model_test.dart` and `test/widgets/order_status_timeline_test.dart`, both of which had stopped testing what they claimed to — `flutter analyze` passed and the suite stayed green through the rename because the old field name (`preparedByName`) still compiled, just against a different step's meaning now; the tests needed updating by hand to actually cover both steps distinctly, not just kept passing by accident
- `flutter analyze` clean, 40 tests passing (up from 39), `flutter run -d chrome` compile/serve smoke test

**Decisions made:**
- Quantity finalization and stock deduction stay at the *second* kitchen action, not the first — "Start Preparing" is a quick acknowledgement with no numbers attached, since what's actually being sent typically isn't known until the order is being boxed up, not when work begins
- New items can still only be added at the "Ready to Deliver" step, same as before — that's still the point fulfillment is actually decided, just renamed/retriggered rather than moved

**Issues & resolutions:**
- Caught during verification, not by tests: after the enum/field rename, `flutter analyze` and the full suite stayed green even though `order_model_test.dart` was silently exercising the wrong step's semantics (old field name, new meaning) — worth remembering that a passing suite after a rename doesn't by itself prove the rename was propagated correctly everywhere it mattered; had to manually check the test fixtures actually covered both new fields, not just compiled against them
- No live browser click-through was possible in this environment (same recurring caveat) — worth manually walking start-preparing → ready-to-deliver → deliver → confirm before relying on this

-----------

## Phase 22 — Kitchen order history
**Dates:** 25 July 2026

**Goal:** User-reported: once an order left "prepared" (i.e. was delivered), it simply stopped appearing anywhere in the kitchen's Orders tab — that screen only ever renders the three active-work statuses, so a delivered order wasn't lost from Firestore, just invisible to kitchen staff with no way to look it back up.

**Completed:**
- Added a third "History" destination to `KitchenDashboardScreen`, alongside Orders and Stock Catalog
- New `_KitchenHistoryBody`: streams all orders, filters to `delivered`/`received`, shows branch name + item summary + status chip per row, tappable to the same `showOrderDetailSheet` every other order card in the app already opens
- Extracted `orderStatusLabel()`/`orderStatusColor()` into a new shared `lib/utils/order_status.dart`, replacing the private `_statusLabel`/`_statusColor` methods that had been living only on `ManagerDashboardScreen`'s `_ManagerOrdersBodyState` — the kitchen history view needed the exact same status-label/tint mapping, so this is now shared rather than about to become a second copy
- Added `test/utils/order_status_test.dart` covering `orderStatusLabel` for all six statuses
- `flutter analyze` clean, 41 tests passing (up from 40), `flutter run -d chrome` compile/serve smoke test

**Decisions made:**
- A flat chronological list (like `ManagerDashboardScreen`'s Orders tab), not grouped by status — this is a "look something up" view, not an action queue, so a single list ordered newest-first is more appropriate than the section-per-status pattern the active-work Orders tab uses
- Scoped history to `delivered`/`received` only, not every status — the other three (requested/preparing/prepared) are already visible in the Orders tab's active-work sections; duplicating them into History would just be noise

**Issues & resolutions:**
- None. Same verification level as recent phases — `flutter analyze`/`flutter test`/compile-serve smoke test only, no live click-through in this environment

-----------

## Phase 23 — First real Android run, and a real Android-only bug it found
**Dates:** 25 July 2026

**Goal:** The Android target had been configured since Phase 1–2 but never actually run — every verification in every phase since has been Chrome/web only. Set up an emulator and confirm the app genuinely works on Android, not just "should work."

**Completed:**
- Installed an Android 36 (`google_apis`, x86_64) system image and created a `Pixel_8_API_36` AVD via the SDK tools already present on this machine (`flutter doctor` showed the Android toolchain fully installed and licensed, just never exercised)
- First `flutter run -d emulator-...` build took ~10 minutes (Gradle had to pull down NDK, build-tools 36, platform 34, and CMake that hadn't been needed for web builds); confirmed via screenshot that the app launches cleanly — login screen, Phase 18 theme, no crash, no Firebase init failure
- Found a real, Android-only bug during that first check: tapping the Email field on `LoginScreen`/`SignUpScreen` didn't reliably raise the keyboard, while Password did. Root cause: both fields used `keyboardType`/`obscureText` with no `autofillHints` set and weren't wrapped in an `AutofillGroup`, so Android's autofill negotiation on the email-shaped field could intercept the tap instead of handing off to the IME — confirmed in the device log by two consecutive `SHOW_SOFT_INPUT` requests both cancelled mid-animation (`onCancelled at PHASE_CLIENT_APPLY_ANIMATION`)
- Fixed properly rather than working around it: wrapped both screens' fields in `AutofillGroup`, added correct `autofillHints` (`email`, `password` on login; `name`, `email`, `newPassword` on sign-up — distinct hint for sign-up since it's a new credential, not an existing one), and `textInputAction` so the software keyboard's "next"/"done" affordance chains between fields properly. This is the standard fix, not a hack — it also means a real password manager can now actually offer to save/fill credentials, which matters for a real business's staff logging in daily
- Rebuilt and verified via `adb shell input tap`/`input text` directly against the running emulator: text now lands in the Email field correctly
- `flutter analyze` clean, 41 tests still passing (no existing test touched either screen), rebuild verified live on-device

**Decisions made:**
- Verified with the actual device/log output rather than assuming a plausible cause — the IME tracker log lines confirming two cancelled show-keyboard animations were what turned "probably an autofill thing" into a confirmed root cause before writing the fix

**Issues & resolutions:**
- The emulator crashed/disconnected once mid-session (`Lost connection to device` in the run log, `adb devices` came back empty, the emulator process itself had died) — restarted `adb` and relaunched the AVD; came back clean on the second attempt. Not investigated further since it didn't recur, but worth knowing this AVD has shown at least one instance of instability
- This is the first phase actually verified on a real running Android build rather than just `flutter analyze`/`flutter test`/web compile-serve — worth treating Android as a first-class target for verification going forward now that the emulator exists, rather than falling back to web-only checks by default

-----------

## Phase 24 — Archive branches instead of deleting them
**Dates:** 25 July 2026

**Goal:** Manager had no way to remove a branch at all — `BranchManagementScreen` only ever had "Add Branch." Investigating what *would* happen if a branch were deleted surfaced a real risk: `firestore.rules` granted managers full `write` on `branches` (which covers delete), but Firestore has no cascade — deleting a branch document would silently orphan every `order`/`branchStock`/`stockMovement` referencing that `branchId`, with no warning. Rather than building real deletion, close the actual gap: branches get archived, never deleted, matching the immutable-history philosophy the rest of the app already follows (Phase 3's ledger, Phase 11's corrections-as-new-entries).

**Completed:**
- `BranchModel`: added `active` (bool, defaults `true`, including for existing branches with no such field yet)
- `FirestoreService`: added `archiveBranch()`/`reactivateBranch()` — both just flip `active`, nothing else touches the document
- `BranchManagementScreen`: split into **Active** and **Archived** sections; each active branch gets an "Archive" action behind a confirm dialog explaining what it does and doesn't do; each archived branch gets a one-tap "Reactivate"
- `SignUpScreen`'s branch dropdown now filters to `active` branches only — audited every other `streamBranches()`/`streamBranchNames()` call site first (kitchen/delivery/manager order lists, branch home) and confirmed none of them should filter, since they all need to keep resolving names for archived branches too so historical orders stay readable rather than falling back to a raw id
- Locked down the actual risk in `firestore.rules`: split `branches`' `allow write` into `allow create, update` (manager only, unchanged) and an explicit `allow delete: if false` — a branch document can no longer be deleted through the app's client SDK path at all, closing the gap that prompted this phase. (Caveat, and told to the user directly: this doesn't prevent someone with direct Firebase Console/project-owner access from deleting it anyway — security rules bind client SDK access, not Console access — so it's real defense-in-depth, not an absolute guarantee)
- Added `active` coverage to `test/models/branch_model_test.dart` (defaults true, round-trips false, defaults true for pre-existing branches without the field)
- Redeployed rules, rebuilt and relaunched on the Android emulator (still crashed and had to be relaunched once more, same instability noted in Phase 23), confirmed clean launch via screenshot; `flutter analyze` clean, 44 tests passing (up from 41)

**Decisions made:**
- Archive-with-a-visible-archived-list over the two alternatives considered (true delete gated on "zero related history," or no delete UI at all) — this was the user's explicit choice, and it's also the option most consistent with how the rest of the app already treats history
- Deliberately did not add any bulk/cascading side effects to archiving (e.g. auto-reassigning staff, blocking new orders) — archiving only ever touches the branch document's own `active` flag; anything staff-facing (a branch-scoped order screen still functioning normally) keeps working exactly as before, since nothing about the branch's own id or data changed

**Issues & resolutions:**
- Same recurring emulator instability as Phase 23 (crashed between sessions, required an `adb`/AVD restart) — not a code issue, just this AVD
- Couldn't click through the actual archive/reactivate flow in this environment — no manager credentials available here. Verified only that the app still launches cleanly on Android after the change; worth the user logging in as manager and archiving a real branch to confirm the UI end to end