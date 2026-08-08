# Brothers Coffee — Product rework backlog

This document records the next product changes and fixes agreed after the
original MVP roadmap. Topics are defined collaboratively, clarified before
planning, and then implemented one pull request at a time by the project owner.
Codex reviews each topic before it is merged.

The existing [`IMPLEMENTATION_ROADMAP.md`](IMPLEMENTATION_ROADMAP.md) remains a
record of the original MVP backlog. When the two documents conflict, a topic in
this document takes precedence once its requirements are marked **Agreed**.
The product requirements and architecture must be updated as part of each
implementation when an agreed topic changes their assumptions.

## Topic workflow

Each topic moves through these states:

1. **Clarifying** — the requested outcome and open questions are recorded.
2. **Agreed** — product behavior and edge cases have been confirmed.
3. **Planned** — branch, implementation steps, tests, manual acceptance, and
   review focus are documented.
4. **In progress** — implementation has started on its dedicated branch.
5. **In review** — automated and manual verification are complete and the
   branch is ready for a read-only review.
6. **Completed** — the reviewed pull request has been merged.

Unless a topic explicitly changes them, the offline-first, integer-millime,
localization, immutable-sale, and repository-boundary constraints continue to
apply.

## Topic 1 — Manually controlled cash session

**Status:** Planned

**Branch:** `codex/manual-cash-sessions`

### Confirmed product behavior

- The existing `manager` role is the administrator for this workflow; no new
  role is introduced.
- The product and UI concept is renamed from business day (`journée`) to cash
  session (`session de caisse`).
- Only a manager may open, close, or reopen a cash session. Employees must not
  see or invoke those actions.
- Opening and closing are always explicit manual actions. A sale, a date
  change, an app restart, or any other automatic process must never open or
  close a session.
- An open session may span midnight or remain open for several calendar dates.
- Multiple sessions may be opened and closed on the same calendar date, but at
  most one session may be open at a time.
- A manager may close a session containing no sales.
- Opening requires an initial cash float (`fond de caisse`). It is entered and
  stored as an exact non-negative integer number of millimes, so zero is valid.
- When opening, the manager assigns exactly one account to the session. The
  manager's own account is assignable and is selected by default.
- Only active accounts are assignable. The assignment identifies the cashier
  responsible for the session; it does not prevent other authenticated active
  accounts from confirming sales. Each sale continues to record the account
  that actually confirmed it.
- Session assignment cannot be changed after opening in the initial scope.
- An account assigned to the currently open session cannot be archived. Name
  and PIN changes remain allowed, and archival becomes possible after closing.
- Opening, closing, and reopening timestamps are operationally important and
  must be persisted as part of the audit history together with their actors.
- A sale cannot be confirmed without an open session. An employee sees a clear
  localized message such as: “La caisse est fermée. Contactez un responsable”.
- A manager can access simple “Ouvrir la caisse” and “Fermer la caisse” actions
  from the POS according to the current session state.
- Closing keeps the counted cash optional. When supplied, the initial formula
  is:

  ```text
  expected cash = opening float + net non-cancelled cash sales
  variance      = counted cash - expected cash
  ```

- A manager may reopen a closed session with a mandatory reason. Reopening
  continues the same session and preserves its original opening float; opening
  a new session is a distinct operation.
- Every open, close, and reopen is retained as an append-only event. Each close
  event preserves its timestamp and its expected, optional counted, and
  optional variance snapshot; reopening never erases an earlier close attempt.
- A sale belonging to a closed session cannot be cancelled.
- Reopening makes the session's confirmed sales cancellable again. Closing the
  session blocks further cancellations until it is reopened.
- Sales must remain reportable both by their actual calendar date and by their
  cash session.
- Cash sessions have a UUID primary identifier and a global human-readable
  sequence such as `S-000123`. A sale reference uses its actual local sale
  date, session sequence, and sequence within that session, for example
  `V-20260808-S000123-001`.
- The current session reference and assigned cashier may be visible to every
  authenticated user on the POS.
- Closing and reopening never happen automatically, even when a session spans
  multiple dates.

### Existing behavior that this topic supersedes

- Either employee or manager can currently close a business day.
- The first sale currently opens a business day automatically.
- A first sale on a later date currently closes the older open day and opens a
  new one atomically.
- Business days are currently unique by calendar date and sale display numbers
  are sequenced within that dated record.
- Expected cash currently derives from net non-cancelled cash sales without an
  opening cash float.

### Cash movements

The session supports manager-only cash additions and withdrawals while it is
open:

- `cash addition` (`ajout de caisse`) increases expected cash.
- `cash withdrawal` (`retrait de caisse`) decreases expected cash.
- Each movement has a UUID, a strictly positive integer amount in millimes, a
  mandatory reason, actor, and timestamp.
- Movements are immutable and cannot be deleted. A mistake is corrected with
  an opposite movement carrying its own reason and audit identity.
- The original opening float is immutable. A float-entry mistake is therefore
  reconciled through an addition or withdrawal instead of rewriting history.

Expected cash becomes:

```text
expected cash = opening float
              + net non-cancelled cash sales
              + cash additions
              - cash withdrawals
```

This is a cash-drawer reconciliation feature, not a complete expense or
accounting subsystem.

### Reporting views

- A session report contains every sale belonging to the session even when it
  spans midnight, plus the assigned cashier, opening float, itemized cash
  movements, lifecycle events, sales totals, and closing reconciliation
  snapshots.
- Calendar reports group sales by their actual local confirmation date and can
  combine sales from multiple sessions on the same date.
- Session attribution and actual sale-creator attribution remain separate.

### Scope boundaries

Included:

- Manual session open, close, and reopen lifecycle.
- One responsible active account per session.
- Opening float and manager-only cash additions/withdrawals.
- Session and calendar reporting semantics.
- Migration of existing business-day and sale history.
- Manager authorization below the UI layer.

Not included:

- Multiple responsible cashiers or assignment changes during a session.
- Shift scheduling, employee attendance, payroll, or till handover workflows.
- Editing or deleting opening floats, movements, or lifecycle events.
- Automatic open, close, midnight rollover, or scheduled reminders.
- Expense categories, suppliers, accounting entries, or inventory impact for a
  cash withdrawal.
- Multiple simultaneously open tills or sessions.

### User workflows

#### Open a session

1. A signed-in manager selects “Ouvrir la caisse”.
2. The form requires a non-negative opening float in integer millimes and one
   active responsible account. The manager is selected by default.
3. Confirmation creates the UUID session, allocates the next global `S-000123`
   display reference, records the opening timestamp/actor, and marks it open in
   one transaction.
4. A second open session is rejected by both application logic and a database
   invariant.
5. Every authenticated user sees the open session reference and responsible
   cashier.

#### Sell with or without a session

1. Any active employee or manager may build a basket.
2. Confirmation without an open session is rejected below the UI layer. The UI
   displays “La caisse est fermée. Contactez un responsable”.
3. With an open session, confirmation records the session UUID, actual creator,
   UTC timestamp, local sale date, session-scoped sequence, and immutable sale
   snapshots atomically.
4. The display reference follows `V-YYYYMMDD-S000123-001`, where the date is
   the sale's actual local date rather than the session opening date.

#### Add or withdraw cash

1. A manager opens the current session controls and chooses cash addition or
   withdrawal.
2. The form requires a strictly positive integer-millime amount and a non-empty
   reason.
3. The movement is appended with UUID, manager, and timestamp in a transaction.
4. It cannot be edited or deleted. A mistake is corrected with an opposite
   movement and a new reason.

#### Close and reopen

1. A manager selects “Fermer la caisse”.
2. The app calculates expected cash from the immutable opening float, current
   net non-cancelled sales, additions, and withdrawals.
3. Counted cash remains optional. If supplied, variance is calculated exactly
   in millimes.
4. Closing appends a close event containing timestamp, manager, expected cash,
   optional counted cash, and optional variance, then marks the session closed.
   An empty session may be closed.
5. Sales, movements, and cancellations against a closed session are rejected.
6. A manager may reopen it only when no other session is open and only after
   entering a non-empty reason. Reopening appends an event and retains every
   earlier close snapshot.
7. A later close creates another close event; it never overwrites the earlier
   event.

### Domain and persistence plan

Use a versioned Drift migration (expected schema v3 to v4; use the next actual
version at implementation time). Replace date-owned business-day semantics with
session-owned semantics while preserving all existing records.

Suggested model:

- `cash_sessions`
  - UUID primary key.
  - Globally unique positive display number used as `S-000123`.
  - `open` or `closed` status.
  - Responsible account ID, opening manager ID, non-negative opening float,
    opening UTC timestamp, captured local opening date/time context, revision,
    and created/updated metadata.
- `cash_session_events`
  - Append-only UUID event records for `opened`, `closed`, and `reopened`.
  - Session, actor, UTC timestamp, and local time context.
  - Reopen reason where applicable.
  - Close events carry immutable expected, optional counted, and optional
    variance snapshots.
- `cash_movements`
  - Append-only UUID, session ID, `addition` or `withdrawal`, positive amount,
    required reason, manager actor, timestamp, and local time context.
- Session-number sequence
  - A transactionally allocated global positive sequence independent of dates.
- `sales`
  - Replace the business-day association with a cash-session association.
  - Persist the actual local sale date needed by the reference and calendar
    reports instead of deriving it from the session.
  - Keep the existing session-scoped positive sale sequence.

Database safeguards:

- Enforce at most one open session, including for writes that bypass normal UI.
- Retain foreign-key restrictions and UUID identifiers.
- Keep confirmed sale and sale-line immutability triggers.
- Reject cancellation when the owning session is closed.
- Make session events and cash movements update/delete protected.
- Validate non-negative opening/count values, strictly positive movement values,
  non-empty required reasons, and internally consistent variance snapshots.

Migration behavior:

- Convert each existing business day into a cash session without losing UUIDs,
  status, actors, timestamps, reconciliation values, events, or sale links.
- Allocate deterministic global session display numbers in chronological order.
- Use each legacy business date to populate the migrated sales' local sale date.
- Use a zero opening float for migrated sessions because the old schema did not
  record one.
- Choose a valid historical responsible account deterministically, preferring
  the original opener, and preserve archived referenced accounts.
- Convert legacy close/reopen history into append-only session events and retain
  the best available close snapshots.
- Remove the old unique-by-calendar-date rule and automatic-rollover behavior.
- Extend migration tests from every supported historic schema version through
  the new schema, including populated version-3 data.

### Repository and application boundaries

- Replace `BusinessDayRepository` terminology with a cash-session contract.
- Provide application operations for current-session status, open, close,
  reopen, list/detail, add cash, and withdraw cash.
- Every manager-only method accepts/validates the acting account below the UI.
- Sale confirmation obtains the current open session but never creates one.
- Sale cancellation validates that the owning session is currently open.
- Account administration rejects archival of the account assigned to the open
  session with a typed, localized failure.
- Keep Drift rows and SQL out of widgets. Expected-cash calculation belongs in
  domain/application logic exercised independently from presentation.
- Use typed failure codes for no open session, already-open session, inactive
  assignee, manager required, closed session, invalid amount/reason, assigned
  account archival, and reopen conflict.

### Reporting plan

- Add a manager-only session list and session-detail report keyed by session
  UUID/reference.
- Session detail includes responsible cashier, actual sale creators, opening
  float, movements, all lifecycle events, full-session sales, cancellations,
  and every close reconciliation snapshot.
- Date and date-range reports filter sales by their persisted actual local sale
  date. Several sessions on one date are combined, and a session spanning dates
  contributes each sale to its real date.
- Do not attribute an entire cross-midnight opening float or close variance to
  every calendar date. Cash reconciliation belongs to the session view; date
  views may expose the related session references for navigation/audit.
- Existing current-catalogue labels in aggregate reports and immutable snapshot
  labels in historical sale detail remain unchanged.

### Presentation and localization plan

- Replace user-facing “journée” lifecycle wording with “session de caisse”.
- Show a compact session-status component on the POS for all roles: open/closed,
  session reference, and assigned cashier when open.
- Show open, close, reopen, addition, and withdrawal actions only to managers
  and only in valid states.
- Employees see no financial reconciliation values or session-management
  actions.
- Opening form: integer-millime float and active-account selector defaulted to
  the manager.
- Closing form: expected cash, optional counted cash, and computed variance for
  the manager.
- Movement forms: type, integer-millime amount, mandatory reason, and explicit
  confirmation.
- Keep French as the primary copy and add corresponding Arabic resources.
- Use directional spacing/alignment and verify phone/tablet portrait/landscape
  layouts without overflow.
- Dialog widgets own and dispose their controllers to avoid repeating the
  previous reason-dialog lifecycle assertion.

### Documentation updates in the implementation branch

- Update `PRODUCT_REQUIREMENTS.md` to replace business-day automation and
  permissions with the agreed cash-session model.
- Update `ARCHITECTURE.md` model, transactions, invariants, migration notes,
  and report boundaries.
- Update `README.md` current capabilities after implementation.
- Mark this topic complete here only after its reviewed pull request is merged.
- Revisit original roadmap topics whose export/backup/report assumptions still
  refer to a calendar business day.

### Automated verification

Domain/repository tests:

- Manager can open with zero or positive float and any active assignee.
- Employee open/close/reopen/movement calls are rejected below the UI.
- Inactive assignee, negative float, and a second open session are rejected.
- No-session sale confirmation fails without allocating a sale number or
  changing the basket's persisted state.
- Any active account can sell in an open session; responsible and actual creator
  attribution remain distinct.
- Multiple sessions on one date and one session spanning dates produce unique,
  correctly formatted references and sequences.
- Expected cash exactly includes float, net sales, additions, and withdrawals.
- Closing with and without counted cash, including an empty session, persists
  the correct snapshots.
- Movement authorization, amount/reason validation, immutability, and opposite
  correction are enforced.
- Reopening requires manager/reason, preserves the float and old close event,
  and fails while another session is open.
- Cancellation fails while closed, succeeds after reopening, and affects the
  next close calculation without rewriting an earlier close snapshot.
- Assigned-account archival fails while open and succeeds after close.
- Failures roll back session status, sequences, events, movements, sales, and
  close calculations atomically.

Database/migration tests:

- Only one open session can exist even through direct database writes.
- Session events and movements cannot be updated or deleted.
- Finalized sale/line immutability remains intact after table/column migration.
- Version 3 populated data migrates without losing history, references, totals,
  actors, or timestamps; versions 1 and 2 still upgrade through the full path.

Reporting tests:

- Session report includes all its sales across midnight and all close attempts.
- Date reports split cross-midnight sales by actual local sale date and combine
  multiple sessions on the same date.
- Cancelled sales and movement totals affect the correct session calculations.
- Employees cannot invoke session financial reports directly.

Widget tests:

- Employee sees session status but no management actions or reconciliation.
- Manager sees the correct action for open/closed state.
- Closed-session confirmation presents the localized message.
- Open/close/reopen/movement validation and success/error states render safely.
- Representative compact portrait, short landscape, and tablet layouts have no
  overflow in French and Arabic/RTL.

### Manual phone acceptance

- In airplane mode, verify that a sale is blocked before opening a session.
- Open with a zero float and with a positive float; assign both an employee and
  the manager in separate sessions.
- Switch users and verify the responsible cashier remains visible while another
  active account can record a sale with correct creator attribution.
- Restart and rotate the app while open; confirm session, basket behavior, and
  status remain coherent.
- Add and withdraw cash, enter an opposite correction, then reconcile expected
  cash manually.
- Close with no count, close with a count, reopen with a reason, cancel a sale,
  and close again; inspect the complete event history.
- Confirm a closed session blocks sales, movements, cancellations, and assigned
  account archival as specified.
- Open two sessions on the same date and keep one open across a date change;
  verify session and calendar reports plus displayed references.
- Verify no operation opens or closes a session automatically.

### Acceptance criteria

- Exactly one manually opened session can be active, independent of date.
- Only managers can manage sessions or movements; authorization is enforced
  below presentation.
- Every sale requires an open session and retains actual local date, session,
  creator, UUID, immutable snapshots, and unique display reference.
- Opening float, movements, lifecycle events, close snapshots, reasons, actors,
  and timestamps survive restart and remain auditable.
- Expected/count/variance calculations are exact integer millimes.
- Session and calendar reports follow their distinct agreed boundaries.
- Existing installations migrate without losing operational history.
- All behavior works offline with localized responsive UI.

### Review focus

- No legacy automatic-open, automatic-rollover, or date-unique assumption
  remains reachable.
- Manager restrictions are repository/application rules, not merely hidden UI.
- Migration preserves historic sales and reconciliation evidence.
- Append-only records and finalized sales cannot be mutated through alternate
  repository or direct-database paths.
- Local date/reference behavior remains deterministic across midnight and app
  restart.
- Session close/reopen and sale confirmation transactions cannot leave partial
  state.
- Employee screens do not expose financial values.

### Ordering and dependencies

Implement this topic before further export, backup/restore, or reporting work
because those features must use cash-session rather than business-day concepts.
The implementation should start from an up-to-date `main` and remain isolated
to `codex/manual-cash-sessions` until review and merge.

## Topic 2 — Inventory management

**Status:** Planned

**Branch:** `codex/inventory-management`

### Confirmed direction

- Add offline local inventory management while keeping the sales catalogue and
  physical stock as distinct concepts.
- An inventory item does not have to be sellable or visible on the employee POS.
  For example, packs of coffee beans may be tracked only in inventory.
- A sellable catalogue product does not have to be stock-tracked. For example,
  espresso may remain available on the POS without a directly maintained
  “espresso quantity”.
- A sellable catalogue product may be linked to inventory so its confirmed sale
  automatically consumes stock. For example, selling one water bottle reduces
  the linked water-bottle inventory quantity.
- Inventory quantities are whole signed units such as packs, bottles, and cans;
  grams, millilitres, and fractional quantities are not included.
- Each catalogue product may link to at most one inventory item, and each
  inventory item may link to at most one catalogue product in this version.
- Every inventory item has an explicit whole base stock unit explaining what
  one quantity means. Examples include one bottle, one pack, one can, or one
  box. The base unit is part of the inventory item's persisted definition.
- A product-to-item link carries a configurable strictly positive whole-unit
  consumption quantity, defaulting to one.
- Inventory is advisory and auditable rather than a sale-blocking reservation
  system. Automatic consumption may make theoretical stock negative; a sale is
  never rejected solely because recorded stock is insufficient.
- Inventory management, quantities, history, thresholds, and manual operations
  are manager-only. Employees continue to sell linked products without managing
  inventory.
- Inventory is continuous across cash sessions and calendar dates. It is not
  reset or copied when a session opens or closes.
- Inventory remains local and offline.

### Initial conceptual model

- **Catalogue product:** what the cashier selects and sells on the POS.
- **Inventory item:** a physical good whose available quantity is tracked.
- **Optional consumption link:** defines how much of an inventory item a
  confirmed sale of a catalogue product consumes.

The separation permits these initial cases:

| Example | In sales catalogue | In inventory | Automatic consumption |
| --- | --- | --- | --- |
| Espresso | Yes | No direct espresso item | No |
| Coffee-bean pack | No | Yes | No; manager records use/withdrawal manually |
| Water bottle | Yes | Yes | One linked bottle per sold bottle |

### Confirmed stock operations

- Creating an inventory item requires an initial whole-unit quantity; zero is
  valid. The initial balance is represented in stock history.
- Managers can record stock receipt/addition, manual withdrawal/use, and a
  physical inventory count/adjustment. Manual operations retain a helpful
  reason or comment, actor, and timestamp.
- Example: when an owner takes two coffee-bean packs home, the manager records a
  withdrawal of two with the reason instead of silently editing the balance.
- Stock history is append-only. A mistaken manual movement is corrected with a
  new opposite movement rather than editing or deleting the original.
- Confirming a sale of a linked product appends an automatic consumption
  movement and decreases theoretical stock in the same transaction.
- Cancelling that sale appends an automatic return movement restoring the exact
  quantity originally consumed. Historic consumption is not mutated.
- Negative theoretical stock is allowed for automatic consumption so forgotten
  receipts or adjustments never block a legitimate physical sale.
- An optional low-stock threshold can be configured when creating an inventory
  item. A manager warning appears at quantity less than or equal to the
  threshold, with a stronger state for negative stock. Thresholds are
  non-negative and warnings remain inside the app; no push notification is
  required.
- Employees see neither theoretical stock quantities nor low/negative-stock
  warnings. These indicators are manager-only and never block a sale.
- Receipt/addition comments are optional. Withdrawal/use and physical-count
  adjustments require a non-empty reason. Initial balance uses a system
  description.
- A manager withdrawal may make theoretical stock negative.
- A physical inventory count must be non-negative. The system appends the
  positive or negative difference from theoretical stock as an adjustment.
- Product and inventory records are created separately. A manager optionally
  links them and configures consumption through catalogue/inventory management.
- An inventory item linked to an active catalogue product cannot be archived
  until it is unlinked.
- Base units use a localized predefined list: piece, bottle, can, pack, box,
  carton, and bag, plus an `other` option with a required custom label.
- Size or packaging details belong in the item name, for example `Eau 1,5 L` or
  `Café en grains 1 kg`; no separate unit-description field is needed.
- Receipts are entered directly in base units. Receiving one pack of six
  individually tracked bottles means adding six bottle units, optionally noting
  the packaging in the receipt comment. Automatic package conversion is
  deferred.
- Purchase prices, suppliers, lots, expiry, accounting, and per-session
  sub-inventories are outside this version.

### Scope boundaries

Included:

- Manager-only inventory item creation, metadata updates, history, movements,
  thresholds, linking, unlinking, and archival.
- Whole-unit initial balance, receipts, withdrawals, and physical counts.
- Optional one-to-one linkage with a configurable whole-unit consumption rate.
- Automatic sale consumption and cancellation return movements.
- Negative theoretical stock with manager-only low/negative indicators.
- Migration, persistence, auditability, localization, and offline operation.

Not included:

- Fractional quantities, weights, volume calculations, recipes, or multiple
  ingredients per product.
- One inventory item shared by multiple products or one product consuming
  multiple items.
- Stock reservation when adding to the basket or blocking confirmation because
  of theoretical availability.
- Packages with automatic base-unit conversion.
- Employee stock screens, exact stock visibility, or employee stock warnings.
- Purchase orders, purchase cost, suppliers, accounting, lots, expiry, barcode
  scanning, inventory locations, or per-session sub-inventories.

### User workflows

#### Create an inventory item

1. A manager opens inventory management and creates an item with a unique UUID,
   name, localized base-unit type, optional custom unit label when `other` is
   selected, non-negative initial quantity, and optional non-negative low-stock
   threshold.
2. The initial quantity becomes the current theoretical balance and an
   append-only initial-balance history entry, including zero.
3. The manager may later edit descriptive metadata and threshold, but never
   directly overwrite the balance or historic movement.

#### Receive, withdraw, and count stock

1. A receipt adds a strictly positive number of base units and allows an
   optional comment.
2. A manual withdrawal removes a strictly positive number of units and requires
   a non-empty reason. It may make the theoretical balance negative.
3. A physical count requires a non-negative observed quantity and a non-empty
   reason. The application calculates the signed difference and records the
   counted value plus resulting balance, even when the difference is zero.
4. Every operation records UUID, manager, timestamp, signed change, and balance
   after the movement in one transaction.
5. A mistake is corrected using a new opposite movement; history cannot be
   edited or deleted.

#### Link a catalogue product

1. The manager creates inventory and catalogue records separately.
2. From product or inventory management, the manager selects an active record
   on the other side and specifies a strictly positive whole consumption value,
   defaulting to one.
3. Database uniqueness guarantees one product to one item and one item to one
   product.
4. Link edits or unlinking affect only future sales. Existing sale-consumption
   movements retain their original item and quantity.
5. An archived item cannot receive a new link. An item linked to an active
   product cannot be archived until unlinked.

#### Sell and cancel a linked product

1. Employees use the POS exactly as for an untracked product; no quantity,
   threshold, or warning is exposed.
2. Confirmation calculates `sale quantity × configured consumption`, appends a
   negative sale-consumption movement, and updates the balance in the same
   transaction as the sale.
3. The sale succeeds even if the resulting balance is zero, below threshold, or
   negative.
4. A permitted cancellation appends the exact inverse of the consumption saved
   for that sale. It does not use the product's current link or current
   consumption configuration.
5. Duplicate cancellation cannot restore stock more than once.

### Domain and persistence plan

Use the next Drift schema version after Topic 1. Existing catalogue products
remain unlinked and all current sales/history remain unchanged.

Suggested model:

- `inventory_items`
  - UUID primary key, name, active/archive state, revision, timestamps.
  - Base-unit enum and nullable custom label required only for `other`.
  - Signed `current_quantity` projection.
  - Nullable non-negative low-stock threshold.
- `product_inventory_links`
  - UUID primary key or stable relationship identifier.
  - Unique product ID and unique inventory-item ID.
  - Strictly positive whole consumption quantity, revision, and timestamps.
- `inventory_movements`
  - Append-only UUID, inventory item, movement type, signed quantity delta,
    resulting balance, actor, UTC timestamp, and local date/time context.
  - Optional reason/comment with constraints determined by movement type.
  - Optional physical counted quantity for stocktake records.
  - Optional sale/sale-line references and related consumption reference for
    automatic consumption/return traceability.

Movement types should distinguish at least:

- `initialBalance`
- `receipt`
- `manualWithdrawal`
- `physicalCountAdjustment`
- `saleConsumption`
- `saleCancellationReturn`

Persistence safeguards:

- Store quantities as SQLite integers; no floating point or decimal conversion.
- Permit signed current balances and sale/manual-withdrawal results.
- Require positive input for receipts, withdrawals, and link consumption.
- Require non-negative physical counts and thresholds.
- Enforce both sides of the one-to-one link with unique indexes.
- Protect inventory movements from update/delete through database triggers.
- Keep current quantity and its appended movement consistent in one transaction;
  no repository operation updates only one side.
- Sale consumption and cancellation return are part of their existing sale
  transactions so neither business record can commit partially.
- Preserve the consumption item and quantity on the movement so later link or
  catalogue changes cannot alter cancellation behavior.

Migration behavior:

- Create inventory tables without synthesizing items for existing products.
- Existing products are untracked until a manager explicitly links them.
- Preserve all pre-inventory sale records without retroactive stock movements.
- Extend every supported schema migration path and generated schema snapshot.

### Repository and application boundaries

- Add manager-authorized inventory query and command interfaces independent of
  Drift rows and widgets.
- Separate descriptive item/link commands from balance-changing commands.
- Require and validate the acting manager for create, edit, receive, withdraw,
  count, link, unlink, and archive operations below presentation.
- Integrate automatic movement creation inside `SaleRepository` confirmation
  and cancellation transactions without granting employees general inventory
  permissions.
- Use typed failures for manager required, inactive account, invalid unit/custom
  label, invalid quantity/threshold, missing reason, item/link not found,
  one-to-one conflict, archived item, and linked-active-product archival.
- Expose a manager query for current items, warning status, linked product, and
  paged/filtered movement history.
- Keep the balance calculation and movement validation in application/domain
  logic with repository-level transactional enforcement.

### Warning and history behavior

- No threshold means no low-stock warning, although negative stock is always
  visually identifiable to the manager.
- With a threshold, `current quantity <= threshold` is low stock.
- Negative stock uses a stronger error state than an ordinary threshold warning.
- Warnings are computed from current local data and displayed in inventory
  management and suitable manager navigation/status surfaces only.
- No push notification, network request, employee warning, or sale blocking is
  introduced.
- Movement history shows chronological type, delta, balance after, actor,
  timestamp, reason/comment, and linked sale reference when applicable.

### Presentation and localization plan

- Add a manager-only inventory screen with search/filter, name, formatted
  quantity/unit, optional linked product, and low/negative status.
- Provide create/edit, receipt, withdrawal, physical count, history, link/unlink,
  and archive actions in valid states.
- Use localized singular/plural labels for predefined units. For `other`, show
  the manager-provided label without pretending it can be automatically
  translated.
- Product administration shows optional inventory linkage and consumption per
  sold unit; the employee POS does not show that configuration.
- Require explicit confirmation for archive, unlink, withdrawal, and physical
  adjustment actions.
- Localize all French and Arabic labels/errors and keep directional layout APIs
  for RTL.
- Verify compact phone and tablet portrait/landscape forms, lists, dialogs, long
  item names, large/negative quantities, and custom unit labels without overflow.

### Documentation updates in the implementation branch

- Add inventory scope, permissions, negative-stock rule, and workflows to
  `PRODUCT_REQUIREMENTS.md`.
- Add inventory entities, ledger invariants, and sale transaction integration to
  `ARCHITECTURE.md`.
- Update `README.md` after implementation and mark this topic completed only
  after review and merge.
- Keep per-session sub-inventory explicitly documented as future work.
- Ensure future export and backup plans include inventory configuration and
  movement history.

### Automated verification

Domain/repository tests:

- Manager creates items with every predefined unit, valid custom unit, zero or
  positive initial balance, and optional threshold.
- Invalid custom unit, negative initial/count/threshold, and unauthorized direct
  calls fail without partial writes.
- Receipt, withdrawal, physical count, zero-difference count, and opposite
  correction produce exact balances and immutable history.
- Receipt comment is optional; withdrawal/count reasons are mandatory.
- Manual withdrawal and sale consumption may cross zero and become negative.
- Low warning triggers at equality/below threshold and negative uses the stronger
  state; no-threshold behavior is correct.
- One-to-one uniqueness is enforced from both product and inventory directions;
  link consumption must be positive.
- Link edits/unlinking affect future sales only.
- Linked active-product archival is rejected; unlinking permits archival.

Sale integration tests:

- Selling an unlinked product makes no inventory movement.
- Selling quantity `q` consumes `q × configured units` atomically.
- Sale confirmation succeeds into negative stock and retains normal immutable
  sale snapshots.
- Sale rollback also rolls back balance and consumption movement.
- Cancellation restores exactly the historic consumption once, even after link
  quantity changes or unlinking.
- Cancellation rollback leaves sale and inventory unchanged.
- Employee sale confirmation can trigger automatic consumption without gaining
  access to inventory management commands or queries.

Database/migration tests:

- Current-balance projection always matches the ordered movement ledger after
  every committed operation.
- Direct movement update/delete is rejected.
- Direct duplicate product/item linkage is rejected.
- Existing supported schema versions migrate with products unlinked and all
  previous sales intact.

Widget tests:

- Employee navigation and POS expose no stock count, warning, history, or
  inventory-management route.
- Manager inventory list renders normal, low, and negative states.
- Create/edit and movement forms validate whole integers, unit/custom labels,
  thresholds, and required reasons.
- Product linking and conflict/archive errors are localized and recoverable.
- French and representative Arabic/RTL phone/tablet layouts do not overflow.

### Manual phone acceptance

- In airplane mode, create bottle, pack, and custom-unit items with zero and
  positive balances; restart and verify persistence.
- Receive one pack of six tracked bottles by adding six bottle units and leaving
  an optional packaging comment.
- Withdraw coffee-bean packs with a reason, enter an incorrect movement, and
  correct it with the opposite movement; inspect the full history.
- Perform a physical count from both positive and negative theoretical balances.
- Link a water product with consumption one, sell several units, and verify the
  automatic movement and balance.
- Sell beyond theoretical stock and verify the sale succeeds, the manager sees
  negative status, and an employee sees no inventory information.
- Cancel an eligible sale and verify the exact quantity returns once.
- Change/unlink a product after a sale, then cancel it and verify restoration
  still follows historic consumption.
- Verify low-stock equality, below-threshold, negative, and no-threshold states.
- Confirm inventory persists unchanged across cash-session close/open cycles.
- Test inventory forms/history in portrait and landscape with French and Arabic
  locale where available.

### Acceptance criteria

- Managers can maintain a continuous offline inventory of whole base units with
  auditable initial, receipt, withdrawal, count, sale, and cancellation history.
- Product linkage is optional and one-to-one, with configurable positive whole
  consumption.
- Confirmed linked-product sales update stock atomically and never fail merely
  because theoretical stock is insufficient.
- Cancellation restores the exact historic consumption without mutating ledger
  history or double-restocking.
- Employees cannot access quantities, warnings, history, or management commands.
- Negative and low-stock states are visible to managers and never require a
  network connection.
- Existing products and sales migrate without fabricated inventory history.

### Review focus

- No floating-point or fractional stock representation is introduced.
- Inventory authorization is enforced below the UI; automatic employee sale
  consumption does not expose general stock access.
- Current balance and immutable ledger cannot diverge under failures or direct
  repository usage.
- Sale/cancellation transactions remain atomic with inventory movements.
- Negative stock is intentionally allowed and never accidentally used as a sale
  guard.
- Link changes cannot corrupt historic cancellation restoration.
- Employee UI reveals no manager-only inventory information.

### Ordering and dependencies

Implement after Topic 1 so sale confirmation/cancellation integrates with the
final cash-session lifecycle and so schema migrations are ordered once. Complete
it before inventory-aware export, backup/restore, or reporting topics. Start
from the reviewed, merged Topic 1 result on `codex/inventory-management`.

## Topic 3 — Application shell and POS interface redesign

**Status:** Clarifying

**Working branch name:** To be confirmed after the requirements are agreed.

### Reference direction

The supplied POS screenshot is a structural reference rather than a request for
an identical visual copy. Its useful foundations are:

- A persistent, compact navigation area at the side of a landscape tablet.
- A large central workspace dedicated to categories and quickly tappable
  product tiles.
- A persistent order/basket panel on the right with quantity controls, total,
  and the primary sale action always reachable.
- Clear separation between global navigation, catalogue selection, and the
  current order.
- A dense counter-oriented layout that minimizes navigation during a sale.

The example's euro currency, card payment, denomination shortcuts, table
service, and other bakery-specific functions are not implicitly part of this
topic. Brothers Coffee continues to use integer millimes and immediate cash
sales unless separately agreed.

### Initial Brothers Coffee interpretation

- The redesign establishes a shared application shell and design system for the
  entire app, then adapts POS, cash sessions, inventory, catalogue, reports,
  accounts, settings, and authentication to it.
- Landscape tablet is the primary POS composition: adaptive navigation rail,
  catalogue/product workspace, and fixed basket panel.
- A roughly 10-inch Android tablet is the primary target, while tablet portrait
  and phone portrait/landscape remain fully usable.
- Product and category ordering continues to follow manager-defined catalogue
  order.
- Existing product photos are used when available with a stable branded
  fallback when absent or unreadable.
- The current cash-session reference, open/closed state, responsible cashier,
  and signed-in account have a clear but compact place in the shell.
- A closed session keeps sale confirmation unavailable and displays the agreed
  employee message or manager open action.
- Manager destinations can include cash-session controls, inventory, catalogue,
  reports/history, account management, and settings; employee navigation shows
  only permitted destinations.
- Phone portrait/landscape and future Arabic/RTL remain supported through an
  adaptive composition rather than shrinking the tablet layout.
- Tablet landscape uses a left navigation rail. It exposes POS, cash session,
  inventory, catalogue, history/reports, accounts, settings, and user switching
  according to the signed-in role.
- Categories use a colored horizontal strip at the bottom of the landscape
  catalogue and above the grid on narrower layouts. Colors come from the app
  palette rather than new manager-configurable category data.
- A product tile shows photo/fallback, name, price in millimes, and its current
  basket quantity. One tap immediately adds one unit.
- The landscape basket is a persistent right panel containing every line,
  plus/minus/remove controls, line totals, order total, and a large cash-sale
  confirmation action.
- Payment remains the existing immediate cash confirmation. Received-cash
  entry, change calculation, denomination shortcuts, card payment, and table
  service are excluded.
- Product search is excluded because the shop catalogue is intentionally small.
- On a phone, the product grid remains primary and a persistent bottom summary
  opens the basket as a full-height sheet/page instead of permanently consuming
  half of the screen.
- A polished warm coffee visual identity may be designed after the shop logo is
  supplied. The logo, extracted brand cues, and an approved tablet POS mockup
  are inputs before final Flutter styling.
- A landscape-tablet wireframe/mockup must be reviewed before Topic 3
  implementation; phone and management layouts derive from that direction.

### Tablet emulation and visual verification

The development PC currently has the Android SDK and command-line AVD tools,
including a Pixel Tablet device definition, but it does not yet have the Android
Emulator package, a system image, or an AVD installed.

Before Topic 3 implementation or visual acceptance:

- Install the Android Emulator and one stable x86_64 Google APIs system image
  using the existing Android SDK manager.
- Create a dedicated AVD such as `BrothersCoffee_Tablet_API35` from the Pixel
  Tablet or equivalent 10-inch profile.
- Verify hardware acceleration on this Windows host and document any required
  Windows Hypervisor Platform setting.
- Run the real Android build through `flutter run` on that AVD in landscape and
  portrait, including rotation, restart, keyboard, dialog, and touch workflows.
- Keep physical-phone testing for compact layouts.
- Add widget/golden-style layout checks at representative logical tablet and
  phone sizes so common regressions do not depend solely on manual emulator
  inspection.
- A real target tablet remains desirable for final release acceptance because
  an emulator cannot validate physical touch ergonomics, brightness, or device-
  specific performance, but it is sufficient for development layout review.

### Requirements still to clarify

- Final logo asset, brand colors/cues, and any constraints on how the logo may be
  cropped or recolored.
- Final visual direction and detailed component choices after the first
  landscape-tablet mockup is reviewed.
- Emulator system image/API selection after checking download availability and
  hardware acceleration during setup.
