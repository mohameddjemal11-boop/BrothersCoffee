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
