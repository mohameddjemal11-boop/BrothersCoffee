# Brothers Coffee Engineering Guide

## Product constraints

- The application is an offline-first Android point-of-sale system for one coffee shop and one tablet.
- French is the initial UI language. Keep all user-facing text localized and keep layouts compatible with future Arabic/RTL support.
- Store TND amounts as integer millimes. Never use floating-point values for money.
- Confirmed sales are immutable. Corrections use manager-authorized cancellation records with a reason.
- The local database is the source of truth. Server synchronization is a future concern and must not be required for normal operation.

## Architecture

- Keep presentation, application/domain logic, repositories, persistence, and platform integrations separated.
- UI code must not execute SQL or platform file APIs directly.
- Use UUIDs for persisted entity identifiers and human-readable sequential numbers only for display.
- Snapshot product names and prices into sale lines.
- Prefer explicit state transitions for business days and sales over destructive updates.
- Use versioned Drift migrations and database transactions for business operations.

## Flutter conventions

- Keep widgets small and testable; business rules belong outside widgets.
- Preserve transient state such as the basket across orientation changes.
- Support portrait and landscape tablet layouts.
- Add unit tests for money, totals, permissions, day transitions, and report calculations.
- Add migration and integration tests for persistence-critical changes.

## Verification

- Run formatting, static analysis, and relevant tests before handing off changes.
- Do not claim Android readiness unless `flutter doctor` and an Android build have been checked.
