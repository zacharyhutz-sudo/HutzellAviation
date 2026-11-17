# Admin dashboard cleanup patch — November 2026

## Deployment order

1. Back up the Supabase database, particularly applications, reservations, flight logs, payments, and hour-ledger entries.
2. In **Supabase Dashboard → SQL Editor**, run the entire contents of `supabase/admin-dashboard-cleanup.sql` as one query. It is written to be safely rerunnable.
3. Upload the **changed/new files** from this patch ZIP to the *root of your existing GitHub repository*, keeping the folders and file paths intact. Do not delete other files. Trigger/wait for the site deployment.
4. Sign into `/admin/` as an authorized administrator, refresh the browser, and verify the changes. You do not need to run `setup.sql` or `phase2.sql` again.

## What changes

- Lists start at **five** rows. `View more (N)` expands; `Show less` collapses.
- Applications, reservation requests, post-flight reports, maintenance, and calendar blocks initially fetch just five records plus an exact count; expanding fetches additional records in batches. Payments and prepaid balances load all rows for accurate financial summaries, but initially render only five. Open squawks load all rows to populate the maintenance linking dropdown.
- Applications and reservation requests are now sorted by the **most recently submitted/created** first. Upcoming scheduled maintenance and time blocks retain **soonest first** sorting; post-flight reports and payment activity use newest first.
- A pending count appears on the application and reservation panels.
- **Remove** on applications/reservations requires confirmation and calls admin-only functions. Approved applications or applications with linked operational/financial history are archived; a non-approved application without history is deleted and its account is reset to `incomplete` so the user can reapply. No user login is deleted.
- **Confirmed** reservations must first be cancelled before removal. Completed or linked reservations are archived, and unused pending/rejected/cancelled requests can be deleted.
- **Include archived** displays archived applications/reservations and provides **Restore**. Archived items are omitted from the main admin lists, but renter-facing history and billing remain intact.
- The former payment-ledger 40-row display limit is replaced with an expandable list; the existing Void action is not a hard delete.
- Added responsive actions, clearer focus states, and removal feedback.

## Important operating notes

- **Archiving an approved application does NOT revoke booking access.** Change the application status to **Suspended** before archiving when access needs to be revoked.
- Archiving a reservation **does not cancel it** or release its aircraft time. Cancel a confirmed reservation before removing it; only remove active reservations after confirming the cancellation.
- Permanent deletion is only allowed when the database function determines it will not destroy or detach existing operations/billing history.
- This patch is designed for the database schema represented by `supabase/setup.sql`, `supabase/phase2.sql`, and `supabase/stripe.sql` in the uploaded ZIP.
- Browser-side admin checks improve the experience, but database functions recheck admin permissions server-side.

## Smoke test checklist

- Create/test with >5 applications and reservations; verify five rows initially, correct counts, View more/Show less, sorting, and Refresh preserving the expanded state.
- Remove an unused pending request; confirm it disappears and can no longer be found by its renter.
- Attempt to remove a confirmed reservation; verify the action requires cancellation.
- Archive a completed flight reservation; verify its flight log, payments, and hour ledger remain unchanged.
- Remove an approved renter application; verify it moves to Include archived and the renter login remains usable; if you want to revoke access, set it to Suspended first.
- Restore an archived record; verify it reappears.
- Reapply after archiving an application; verify it reappears with pending status.
- Verify the page at narrow mobile widths and test that confirmation can be cancelled with the Cancel button or Escape key.

## Validation

The updated client script passed TypeScript checking. A full Astro production build and live Supabase end-to-end tests were not available in the local workspace, so verify in staging or on a database backup before relying on production behavior.
