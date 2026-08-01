# Brothers Coffee — Product Requirements (Android POS MVP)

## 1. Product scope

Brothers Coffee is a single-shop, single-Android-tablet point-of-sale application. It works entirely offline, has no server or recurring infrastructure cost, and is designed for a coffee shop counter workflow.

The MVP includes:

- Product and category catalogues, including product photos and manual display ordering.
- Immediate cash sales in Tunisian dinar (TND).
- Employee and manager PIN login.
- Basket editing before confirmation and immutable confirmed sales.
- Business-day open, close, and manager-only reopen controls.
- Manager reporting and restore, with employee-or-manager closing exports.
- French-first UI, with Arabic translation and RTL layout readiness.
- Portrait and landscape tablet layouts.

Out of scope: inventory, product modifiers, card payments, receipts, multiple tablets or shops, remote/live reporting, automatic cloud upload, and a server.

## 2. Users and permissions

| Capability | Employee | Manager |
| --- | --- | --- |
| Sign in using own PIN | Yes | Yes |
| Create and edit an unconfirmed basket | Yes | Yes |
| Confirm an immediate cash sale | Yes | Yes |
| View sales totals, financial dashboard, or financial history | No | Yes |
| Create/edit/archive products and categories | No | Yes |
| Manage employee accounts/PINs | No | Yes |
| Cancel a confirmed sale (reason required) | No | Yes |
| Close a business day, optional cash count | Yes | Yes |
| Reopen a closed business day | No | Yes |
| Generate/share closing exports and backups | Yes | Yes |
| Run reports and restore a backup | No | Yes |

Accounts are local only. PINs must never be stored in clear text; persist a salted password/PIN hash and enforce a practical PIN length policy (for example, 4–8 digits). Manager recovery is an operational procedure, not an employee bypass.

## 3. Core workflows

### Start and authenticate

1. Launch app.
2. User selects account and enters PIN.
3. App opens the POS screen for either role; financial information is not rendered or navigable for employees.
4. A business day is opened automatically and transactionally when the first sale of that day is confirmed.

### Build and confirm a sale

1. Select a category and product.
2. Add, remove, and change quantities while the basket is in `draft` state.
3. Show total in TND, calculated from integer millimes.
4. Confirm cash sale. In one database transaction, assign a UUID and next business-day display number, persist sale and lines, mark status `confirmed`, and clear the basket.
5. A confirmed sale is immutable. Corrections are made only by manager cancellation, never by editing historic lines.

### Cancel a sale

1. Manager opens a confirmed sale.
2. Manager enters a non-empty cancellation reason.
3. App records cancellation actor, local timestamp, and reason, and changes status to `cancelled` in one transaction.
4. Reports exclude cancelled sales from net sales while retaining them in audit views.

### Close and reopen a business day

1. Employee or manager chooses Close day.
2. Cash count is optional. An employee may enter counted cash without being shown expected revenue or variance; a manager may see both.
3. The app stores counted cash and variance when a count exists.
4. Day becomes `closed`; no new sale can be confirmed against it.
5. Only a manager may reopen it, with a required reason and audit record. Reopen restores `open` status and permits sales again.

### Reports, export, backup, restore

- Managers can view daily and custom date-range reports: gross confirmed sales, cancellations, net sales, sale count, cash count/variance, product/category quantities and value, and employee attribution where permitted.
- An employee or manager can generate the closing CSV, PDF, and complete ZIP backup. The in-app financial dashboard remains manager-only, but an employee operating the Android share sheet may be able to open the generated report.
- Export files are shared using Android's native share sheet, allowing the user to choose Google Drive or another installed provider. The app does not upload automatically.
- Restore is manager-only. Before applying a backup, require explicit confirmation, validate format/version/checksum, create a pre-restore local backup when possible, then replace database and managed media atomically or fail without partial restoration.

## 4. Business rules and invariants

- Monetary values are integers in millimes; `1 TND = 1000 millimes`. Never use floating point for stored values or totals.
- Every sale has an immutable UUID and a human-friendly sequential display number unique within its business day. UUID is the primary identifier.
- Display numbers are allocated only during successful confirmation. Gaps are allowed if a transaction rolls back or is otherwise intentionally reserved; uniqueness is mandatory.
- A sale belongs to exactly one business day and has one creator account.
- Only `draft` baskets can change. `confirmed` sales and their line snapshots cannot be updated or deleted.
- A cancellation preserves the sale and all original line snapshots. It must include manager, timestamp, and non-empty reason.
- Only confirmed, non-cancelled cash sales contribute to net cash expectations.
- At most one business day is open at a time for this installation. Closing/reopening events are auditable.
- Product/category changes do not rewrite historic sale lines: each sale line stores name, price, and relevant tax/display snapshots at confirmation.
- All writes that change sale/day state are SQLite transactions.
- Device time is the source of local dates/timestamps. UI must communicate that reports follow tablet local time; time-zone changes are logged when detectable.
- An employee must not obtain the in-app manager dashboard or financial history through routes, cached screens, database UI, or deep links. Closing exports are the documented exception because the employee may operate Android's share sheet.

## 5. UX and localization

- Default language is French. All UI strings are localized through Flutter localization resources, not embedded in widgets.
- Arabic translation is supported by resource structure from the start. RTL layout uses directional padding/alignment/icons and is tested in Arabic; do not assume left-to-right ordering.
- Currency is displayed as TND from millimes using locale-aware formatting while calculations remain integer based.
- Portrait prioritizes product grid plus bottom/side basket; landscape uses persistent catalogue and basket panes. Core confirm/cancel/close actions remain usable at common tablet sizes and with touch targets.
- Empty, error, confirmation, and destructive actions require clear French copy; cancellation, reopening, and restore require explicit confirmation.

## 6. Acceptance criteria

1. App remains fully usable with airplane mode enabled after installation; no feature requires a network request.
2. Confirming the first sale with no open day automatically opens exactly one business day in the same transaction.
3. Employee can create, alter, and confirm a cash basket, but cannot see financial totals/history or reach manager routes.
4. A confirmed sale receives a UUID and a day-scoped display number, persists after restart, and cannot be edited.
5. Manager can cancel a confirmed sale only with a recorded reason; cancelled sales remain auditable and are excluded from net totals.
6. Employee or manager can close a day with or without a cash count; only manager can reopen, with a reason.
7. Money totals are exact across line quantities and report aggregation using integer millimes.
8. Manager reports work for the current business day and an inclusive selected date range, excluding cancelled sales from net values.
9. Products/categories can have local photos; past sales retain correct label/price even after catalogue edits.
10. PDF, CSV, and complete ZIP backups can be generated offline and handed to Android share; restore is inaccessible to employees and rejects invalid backups safely.
11. French layout is polished in portrait and landscape; Arabic resources render without LTR layout breakage.

## 7. Phased implementation plan

1. **Foundation:** Flutter project structure, theming, localization/RTL scaffold, Drift migrations, local secure PIN hashing, repositories, seeded manager bootstrap.
2. **Operational POS:** accounts/login, business-day lifecycle, catalog CRUD/photos, product picker, draft basket, transactional cash confirmation.
3. **Controls:** immutable sale history, manager cancellation/reopen audit flows, employee route/data restrictions, cash-count close flow.
4. **Management:** daily/range reports, catalogue/account administration, responsive UX and accessibility pass.
5. **Portability:** CSV/PDF generation, ZIP backup manifest/database/media packaging, manager restore and recovery testing.
6. **Hardening:** migration tests, transaction/concurrency tests, offline/restart tests, French/Arabic visual QA, tablet portrait/landscape acceptance testing.
