# Brothers Coffee — Architecture (Android POS MVP)

## 1. Architectural decisions

- **Client:** Flutter/Dart, Android tablet only for the MVP.
- **Persistence:** Drift over local SQLite; all operational data is local.
- **Media:** product photos reside in app-managed local storage; SQLite stores a stable relative media reference and metadata, not arbitrary external paths.
- **Money:** integer millimes (`int`) end-to-end in domain and database.
- **Network:** no API client, server dependency, analytics dependency, or automatic upload.
- **Design:** feature modules call domain use cases; use cases depend on repository interfaces; Drift implementations stay in data/infrastructure. This keeps a future sync adapter possible without changing POS UI rules.

## 2. Suggested module boundaries

```text
lib/
  app/                 bootstrap, routing, theme, localization, role guards
  core/                money, clock, UUID, result/errors, transaction helpers
  domain/
    entities/          role, account, business day, sale, sale line, catalog
    repositories/      abstract local/sync-ready contracts
    use_cases/         confirm sale, close day, cancel sale, restore backup
  data/
    database/          Drift database, tables, DAOs, migrations
    repositories/      Drift implementations and mapping
    media/             managed local image storage
    export/            CSV/PDF/ZIP generators, Android sharing
    security/          PIN hasher and session storage
  features/
    auth/ pos/ catalog/ day_close/ sales_history/ reports/ backup/ settings/
  l10n/                French and Arabic ARB resources
```

Feature presentation code may read through feature-specific query/use-case interfaces, never directly from Drift. Role checks occur both at route/UI level and in manager-only use cases; the UI check alone is not a security boundary.

## 3. Data model

| Entity/table | Key fields | Notes |
| --- | --- | --- |
| `accounts` | `id` UUID, display name, role, `pin_hash`, active, timestamps | Exactly one manager account; employees are local accounts. |
| `categories` | `id` UUID, name, active, sort order, revision metadata | Archive rather than hard-delete when referenced. |
| `products` | `id` UUID, category ID, name, price_millimes, image ref, active, sort order, revision metadata | Price is catalog current price only. |
| `business_days` | `id` UUID, business date, status, opened/closed metadata, expected/counted cash, variance | Unique open-day constraint enforced transactionally. |
| `business_day_events` | UUID, day ID, event type, actor, timestamp, reason/note | Open, close, reopen audit trail. |
| `sales` | UUID, day ID, display number, status, creator, timestamps, total_millimes, cancellation fields | Unique `(business_day_id, display_number)`. |
| `sale_lines` | UUID, sale UUID, product UUID, label snapshot, unit price millimes, quantity, line total | Product label and price are immutable snapshots. |
| `sale_number_sequences` | day ID, next number | Updated in the confirmation transaction. |
| `app_metadata` | schema/version/install metadata | Supports migration and backup compatibility. |

Use integer quantities only unless the business later explicitly introduces weighted items. Persist UTC timestamps plus the local business-date value chosen at the operation; this retains audit ordering while reporting remains understandable offline.

## 4. Transactional use cases

### Confirm cash sale

Within one SQLite transaction: authorize current role; obtain the only open day or create one when confirming the first sale; validate the basket and integer totals; increment/read the day's sequence; insert sale and immutable line snapshots; set status confirmed. If any operation fails, no day/number/sale/line state is committed.

### Cancel sale

Within one transaction: manager authorization; load sale; require `confirmed` status and non-empty reason; update only allowed cancellation fields; append audit event if modeled separately. Never alter lines, total, creator, or display number.

### Close/reopen day

Closing validates `open`, derives expected cash from confirmed non-cancelled sales, optionally records count and variance, and adds event. Reopening requires manager and reason, updates a `closed` day back to `open`, and adds event. Creation of a next day must not occur while an earlier day is open.

## 5. Security and privacy

- Hash PINs with a maintained password-hashing algorithm and per-account salt; keep authentication/session material in Android secure storage as appropriate.
- Keep the active employee session open during working hours. Provide explicit user switching and require manager PIN verification for manager-only routes, restore, and destructive settings.
- Avoid logging PINs, complete backups, or personal account data.
- Use Android Storage Access/Share intents for output. Limit app storage exposure and validate imported archive paths to prevent traversal.
- The on-device database is operational storage, not a substitute for encrypted device management. Document that tablet screen lock and controlled physical access are required.

## 6. Backup and restore format

A ZIP backup contains a versioned `manifest.json`, SQLite database snapshot, managed media directory, and optional checksums. Manifest includes app version, schema version, creation timestamp, install identifier, and file hashes. Create database snapshot through a consistent SQLite/Drift-safe process before zipping.

Restore pipeline: manager authorization → select file → unpack to isolated temporary directory → validate manifest/schema/checksums and media paths → create fallback backup → quiesce writes → atomically replace database/media → reopen database/migrate if supported → force re-authentication. An incompatible or corrupt archive must leave current data untouched.

## 7. Future sync preparation (not implemented in MVP)

The authoritative MVP remains local SQLite. Prepare, but do not expose or depend on, sync as follows:

- UUID primary keys for all business entities; human display numbers are not global identifiers.
- Add `created_at`, `updated_at`, `revision`, and soft-delete/archive metadata where relevant.
- Preserve immutable sale snapshots and append-only audit events; these are safer sync units than mutable historical records.
- Repository interfaces return domain objects and support change queries without exposing Drift rows.
- Keep local operations transactionally complete before any hypothetical outbox write. A future `sync_outbox` can record entity UUID, operation, revision, and payload after local commit.
- Define conflict policy later: confirmed sales/cancellations/events are append-only; catalogue uses revision-based conflict resolution; account/security changes require server policy.
- Never promise cross-device correctness until a server, identity model, encryption, conflict rules, and reconciliation UX exist.

## 8. Verification strategy

- Unit tests: millimes formatting/math, validation, role guards, date-range aggregation, and every business invariant.
- Drift integration tests: migrations, foreign keys, day uniqueness, sale-number uniqueness, transactional rollback, cancellation/report totals.
- Feature tests: employee-hidden financial navigation/data, manager flows, restart persistence, backup validation/restore failure safety.
- Device tests: airplane mode, Android share sheet invocation, photo persistence, portrait/landscape, French and Arabic/RTL rendering.
- Release checklist: test backup/restore on a clean device, confirm no network permission is required, and manually reconcile a known day’s sale totals/cash variance.
