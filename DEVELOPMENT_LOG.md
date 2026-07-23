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