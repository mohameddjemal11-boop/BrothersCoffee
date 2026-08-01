# Brothers Coffee — Remaining MVP implementation roadmap

This roadmap is for implementing the remaining MVP topics one pull request at a
time. Start every branch from an up-to-date `main`, finish and review that pull
request, merge it, and only then create the next branch.

The authoritative product and technical constraints remain in
`PRODUCT_REQUIREMENTS.md` and `ARCHITECTURE.md`.

## Working agreement

For each topic:

1. Update local `main` with `git pull --ff-only`.
2. Create the exact branch listed below.
3. Keep the pull request limited to that topic.
4. Run formatting, analysis, the complete test suite, and an Android build.
5. Test the specified manual scenarios on the physical Android phone.
6. Ask Codex for a review before merging. The initial review is read-only;
   Codex reports findings and only changes code when explicitly requested.

Every implementation must preserve these rules:

- All money uses integer millimes end-to-end. No floating-point money.
- Normal operation remains completely offline and requires no server.
- Widgets do not execute SQL or platform file APIs directly.
- Platform/file behavior is behind an interface that can be faked in tests.
- Confirmed sales and their line snapshots remain immutable.
- Manager-only actions are authorized below the UI layer.
- User-facing text is localized in French and Arabic resources.
- Layout uses directional APIs and remains compatible with RTL.
- Persisted identifiers are UUIDs; display numbers are not identifiers.
- Database changes use versioned Drift migrations and migration tests.

## Topic 0 — Catalogue permission decision

**Decision gate; no code branch unless behavior changes**

The current requirements and implementation make catalogue administration
manager-only. An earlier product discussion allowed both employees and managers
to manage it. Choose one rule before continuing and update
`PRODUCT_REQUIREMENTS.md` so there is one authoritative answer.

If employees must regain catalogue access, use branch:
`codex/catalog-permissions`.

Implementation checklist when a change is required:

- Update the permissions table and catalogue workflow documentation.
- Expose catalogue administration only to the chosen roles.
- Enforce the same authorization in the application/repository layer.
- Test navigation visibility and direct invocation for both roles.
- Verify that changing catalogue data never changes historic sale snapshots.

Review focus:

- UI visibility and repository authorization agree.
- Employee access cannot accidentally expose financial data.
- Tests cover both allowed and rejected calls.

## Topic 1 — Managed category and product photos

**Branch:** `codex/product-photos`

Goal: allow an optional local photo for categories and products, keep it after
restart, and display a safe fallback when no usable image exists.

Implementation checklist:

- Add a media-store interface outside presentation code.
- Implement Android/local storage using an app-managed media directory.
- Use UUID-based managed filenames and stable relative references.
- Reuse the existing `image_picker` and `path_provider` dependencies where
  appropriate; do not store arbitrary external picker paths.
- Validate supported file type and a practical maximum size before copying.
- Add pick, replace, and remove actions to category and product forms.
- Make the repository API distinguish “leave image unchanged” from “remove
  image”; nullable optional parameters alone are ambiguous.
- Display photos in catalogue administration and POS product cards with loading
  and error fallbacks.
- Delete replaced/orphaned managed files only after the database operation has
  succeeded. Never delete a file still referenced by another record.
- Keep media references compatible with the later ZIP backup format.

Automated tests:

- Media copy produces a managed relative reference.
- Invalid type, oversized input, missing source, and copy failure are safe.
- Create/update/remove behavior persists the correct `imageRef`.
- Database failure does not lose the previously referenced image.
- Catalogue widgets render image, no-image, and corrupt-image states.
- Restart/repository tests retain photo references.

Manual acceptance:

- Select a photo on the phone, restart the app, and confirm it remains visible.
- Replace and remove a photo while offline.
- Rotate portrait/landscape and confirm product cards do not overflow.
- Confirm historic sale names and prices are unaffected by photo changes.

Review focus:

- Managed paths cannot escape the app media directory.
- File and database updates cannot leave the current record broken.
- UI code does not directly copy or delete files.

## Topic 2 — Closing CSV/PDF export and Android sharing

**Branch:** `codex/export-and-sharing`

Goal: generate closing exports completely offline and hand them to Android's
native share sheet. Both employees and managers may generate/share a closing
export; this is the documented exception to manager-only financial screens.

Implementation checklist:

- Define an export data model independent of widgets and Drift rows.
- Add a narrowly scoped closing-export query authorized for employee or manager.
  Do not grant employees access to the manager range-report repository.
- Generate deterministic CSV with explicit column order, escaping, encoding,
  business date, sale references, cancellations, totals, cash count, and
  variance when present.
- Generate a readable PDF containing the same reconciled business facts.
- Render all monetary values as integer millimes with no decimal conversion.
- Keep byte/file generation separate from the Android sharing adapter.
- Write generated files to an appropriate app cache/export location.
- Invoke Android's native share sheet; do not upload automatically.
- Add localized progress, success, empty-day, and failure states.
- Decide and document whether an export is available before closing or only for
  a closed day. Prefer closed-day exports for reproducible reconciliation.

Automated tests:

- CSV escaping covers accents, Arabic, separators, quotes, and newlines.
- CSV/PDF fixtures preserve exact millime totals.
- Cancelled sales are retained but excluded from net totals.
- Employee can request a closing export but cannot request range-report data.
- Share adapter receives the expected MIME types and filenames.
- Generation failures do not crash or leave misleading success state.

Manual acceptance:

- Generate CSV and PDF in airplane mode.
- Open both files from the Android share sheet.
- Check a known day's gross, cancellations, net, count, and cash variance by
  hand.
- Test sharing as both employee and manager.

Review focus:

- Export permissions do not weaken financial route/data protection.
- Generator output is deterministic and locale-safe.
- No network permission or automatic upload is introduced.

## Topic 3 — Versioned complete ZIP backup

**Branch:** `codex/backup-export`

Goal: create a complete, portable backup offline and share it through Android.
Restore is intentionally deferred to Topic 4.

Implementation checklist:

- Define backup format version 1 and document it.
- Create a consistent SQLite snapshot using a SQLite-supported snapshot/backup
  mechanism. Never copy only the live database file while WAL writes may exist.
- Package the database snapshot and managed media directory into ZIP.
- Add `manifest.json` containing backup format version, app version, database
  schema version, creation timestamp, install identifier, and file entries.
- Add a SHA-256 checksum and byte size for every packaged file.
- Store archive paths as normalized relative paths.
- Reject or skip unmanaged paths and symbolic/path traversal behavior.
- Allow employee or manager to create/share a backup as required by the product
  permissions table.
- Keep backup creation behind an application service and platform adapter.
- Clean temporary snapshots and incomplete archives after success or failure.

Automated tests:

- ZIP contains the expected database, manifest, and media entries.
- Manifest serialization is deterministic and versioned.
- Every checksum and size matches the archived bytes.
- Snapshot remains readable while the live app database continues operating.
- Missing media and I/O failure produce a clean failure with no partial result.
- Archive entries cannot contain absolute or parent-traversal paths.

Manual acceptance:

- Create and share a backup in airplane mode.
- Inspect the ZIP and manifest on the development PC.
- Confirm product photos are included.
- Continue making a sale after backup creation to prove the database reopened or
  remained usable.

Review focus:

- SQLite consistency, WAL handling, and cleanup on every error path.
- Archive format is sufficient for a future safe restore.
- No PIN hashes or backup contents are logged.

## Topic 4 — Manager-only safe backup restore

**Branch:** `codex/backup-restore`

Goal: restore a valid Topic 3 backup without risking the current installation.
An invalid or interrupted restore must leave current data usable.

Implementation checklist:

- Require an active manager and manager PIN re-authentication.
- Require explicit destructive-action confirmation in localized UI.
- Select an archive through Android's document picker without retaining an
  unsafe external path.
- Extract into a new isolated temporary directory.
- Reject absolute paths, `..` traversal, duplicate normalized paths, links, and
  unexpected required-file replacements.
- Validate manifest version, required entries, sizes, SHA-256 checksums, SQLite
  readability, and supported schema version before touching live data.
- Create and validate a fallback backup of current data before replacement.
- Quiesce writes and close the live database cleanly.
- Atomically replace database and managed media where the platform permits;
  otherwise implement an explicitly recoverable staged swap.
- Reopen/migrate the database, reload dependencies, and force authentication.
- On any failure, restore the previous database/media and report a clear error.
- Record restore provenance without logging sensitive archive content.

Automated tests:

- Valid restore replaces database and media and requires a fresh login.
- Invalid checksum, corrupt ZIP/SQLite, unsupported versions, missing manifest,
  and unsafe paths are rejected before replacement.
- Failure injection at extraction, validation, close, swap, reopen, and migration
  leaves the original installation usable.
- Employee and inactive-manager restore attempts are rejected below the UI.
- A pre-restore fallback can recover the original state.

Manual acceptance:

- Back up a known dataset, add new data, restore, and verify the original known
  dataset and photos return.
- Restore the backup on a clean test installation.
- Try corrupt and wrong-version archives and confirm current data survives.
- Force-close during a staged test restore and verify recovery behavior.

Review focus:

- This review is security and data-loss critical; error paths matter as much as
  the successful path.
- No live files are replaced before all validation succeeds.
- Manager authorization is enforced outside presentation code.

## Topic 5 — Arabic/RTL and accessibility QA

**Branch:** `codex/arabic-rtl-qa`

Goal: make Arabic a tested UI rather than only a prepared resource set, while
improving touch, text-scale, and screen-reader behavior in both languages.

Implementation checklist:

- Review every French and Arabic resource for missing or misleading copy.
- Test all primary screens with Arabic device locale and RTL direction.
- Replace remaining physical left/right padding or alignment with directional
  equivalents where meaning should mirror.
- Verify icons that express direction mirror correctly; neutral icons should not.
- Test long names, large millime totals, and text scaling.
- Add semantic labels/tooltips for icon-only and destructive actions.
- Verify focus order, dialogs, forms, validation, and touch-target size.
- Add representative widget tests for French LTR and Arabic RTL at portrait and
  landscape phone/tablet dimensions.

Automated tests:

- No supported locale is missing a localization key.
- Primary manager and employee flows render without overflow in LTR and RTL.
- Compact action menus remain reachable with large text.
- Money remains an integer millime value in every locale.
- Important actions expose useful semantics.

Manual acceptance:

- Run the complete sale/day/account/report/export flow with Arabic device locale.
- Repeat critical screens with enlarged Android font and display size.
- Rotate the phone throughout the workflow and check dialogs and keyboards.

Review focus:

- RTL behavior is semantic, not merely translated text.
- Fixes do not regress compact French layouts.

## Topic 6 — Offline, restart, migration, and transaction hardening

**Branch:** `codex/offline-hardening`

Goal: prove the application behaves safely under operational failures and date,
restart, concurrency, and larger-data conditions.

Implementation checklist:

- Add restart persistence tests for accounts, catalogue, sales, open/closed day,
  cancellations, media, and settings.
- Add concurrent/double-tap tests for sale confirmation, closing, reopening,
  cancellation, and backup creation.
- Add database failure/rollback tests at each multi-write operation.
- Test midnight boundaries, an older open day, local date changes, and timezone
  changes according to documented device-time behavior.
- Exercise larger catalogues and sales histories for acceptable UI behavior.
- Verify employee financial routes and repository calls remain inaccessible.
- Verify Android manifest/package introduces no required Internet permission.
- Test migrations from every released schema fixture to the current schema.
- Run airplane-mode acceptance and force-stop/restart scenarios on the phone.
- Document discovered operational limitations and recovery instructions.

Automated tests:

- All listed state transitions are atomic and idempotent where required.
- Corrupt or failed operations preserve the last valid state.
- Migration fixtures retain exact historic millime totals and snapshots.
- Employee permission tests cover direct service invocation, not just hidden UI.

Manual acceptance:

- Complete a full business day in airplane mode, force-stop, reopen, close,
  export, back up, and restore.
- Reconcile a known day's expected cash and variance manually.
- Test with low free storage and denied/cancelled picker/share interactions.

Review focus:

- Tests assert business outcomes, not implementation details.
- Failure tests prove absence of partial writes and data loss.

## Topic 7 — Release readiness

**Branch:** `codex/release-readiness`

Goal: produce a repeatable, installable shop build with an operational handoff.

Implementation checklist:

- Choose and document application ID, versioning, and upgrade policy.
- Configure the production app name, icon, splash/theme, and release signing
  without committing private signing secrets.
- Document secure storage and backup handling expectations for the tablet.
- Add a reproducible release build command and checksum procedure.
- Confirm upgrades preserve the production database and managed media.
- Write manager operating instructions for login recovery, closing, export,
  backup frequency, restore, device time, and screen-lock expectations.
- Run the complete release checklist from `ARCHITECTURE.md` on the target phone or
  tablet.
- Record the tested Android/API version and known limitations.

Acceptance:

- A signed release build installs and upgrades over the previous test release.
- All tests, analysis, release build, airplane-mode workflow, and backup/restore
  drill pass.
- The final APK/AAB checksum and version are recorded.
- No development banner, test data, PIN, signing secret, or local backup is
  committed.

Review focus:

- Reproducibility and upgrade safety.
- Secrets and sensitive artifacts remain outside Git.
- Operational documentation matches actual UI behavior.

## Review handoff template

When a branch is ready, send Codex the following:

```text
Branch:
Topic/goal:
Important design decisions:
Files or migrations added:
Commands run and results:
Manual phone scenarios completed:
Known limitations or questions:
```

Codex will review in this order:

1. Data loss, authorization, money, and business-invariant risks.
2. Architecture boundaries and offline behavior.
3. Migration, transaction, and error-path correctness.
4. French/Arabic UX and responsive layout.
5. Automated and manual verification coverage.

The review response will lead with findings ordered by severity and include file
and line references. If there are no blocking findings, it will explicitly state
that and list any remaining test or operational risks.
