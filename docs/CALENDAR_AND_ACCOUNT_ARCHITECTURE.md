# Calendar and account architecture

## Current implementation

The Astro site remains a static GitHub Pages deployment. Browser-side Supabase Auth and Data API calls provide the dynamic account and calendar features.

### Public calendar

The browser calls `get_public_calendar_events()` for a limited date range. That function returns only:

- Event identifier
- Reservation or aircraft-block type
- Start and end timestamps
- Generic status and label

It never returns renter names, email addresses, notes, or trip details.

### Renter accounts

Supabase Auth handles email/password accounts. A database trigger creates a matching `profiles` row. New renters begin with incomplete or pending approval; the initial administrator email is assigned the admin role.

### Reservation creation

Approved renters call `create_reservation()`. The function:

1. Confirms an authenticated and approved account.
2. Validates the requested time range.
3. Locks booking operations for the aircraft during the transaction.
4. Checks aircraft blocks.
5. Inserts a pending reservation.
6. Relies on a PostgreSQL exclusion constraint to reject overlapping active reservations.

### Administration

The admin page can:

- Approve, reject, suspend, or request more renter information
- Confirm, complete, cancel, or reject reservations
- Add and remove maintenance, inspection, owner-use, and unavailable blocks

All writes use restricted database functions rather than direct browser table inserts or updates.

## Security model

- RLS is enabled on every exposed table.
- Anonymous visitors can read only the active aircraft record and the redacted calendar function.
- Renters can read only their own profile, application, and reservations.
- Administrators can read all operational records.
- Public and authenticated roles do not receive direct insert/update/delete privileges on protected tables.
- The publishable key is safe for the browser only because RLS and function grants enforce access.
- Never add a secret or service-role key to the GitHub repository or static website.

## Next implementation phases

- Private document storage
- Pricing-plan tables
- Stripe Checkout and verified webhooks
- Prepaid-hour transaction ledger
- Post-flight meter reconciliation
- Transactional email notifications
- Audit-log records for every admin mutation
- Multi-day and overnight booking UI
