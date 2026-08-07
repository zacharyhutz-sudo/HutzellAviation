# Phase 2 Operations Patch — August 7, 2026

This patch adds the renter-operations features discussed after the initial calendar/account launch.

## Added

- Prepaid 15-, 25-, and 50-hour block balances
- Three-month block expiration tracking
- Renter hour ledger
- Payment ledger and outstanding balances
- Manual admin payment reconciliation
- Renter post-flight report page
- Automatic block-hour deduction when admin finalizes a flight
- Automatic $180/hour pay-as-you-go charge for uncovered finalized time
- Renter aircraft squawk reporting
- Admin squawk workflow
- Maintenance record tracking with optional squawk links
- Admin operational summary cards
- Tyler (`tylerhutzell4@gmail.com`) on the administrator allow-list

## New files

- `src/pages/postflight.astro`
- `src/pages/report-squawk.astro`
- `supabase/phase2.sql`

## Required deployment step

Before deploying the updated site, run `supabase/phase2.sql` once in the Supabase SQL Editor.

Direct online card processing is **not** included in this patch because no merchant/payment-provider credentials are connected. The internal payment ledger is live and ready for a future Stripe or other checkout integration.
