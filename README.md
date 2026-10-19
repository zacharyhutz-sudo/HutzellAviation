# Hutzell Aviation website — renter operations portal

This Astro project presents Hutzell Aviation LLC as a Piper Cherokee aircraft-rental company for approved pilots and time builders. It does not advertise flight instruction through the aircraft.

## Live features

- Supabase email/password renter accounts
- Email-confirmation-compatible registration and login
- Renter application and administrator approval workflow
- Authorized administrators for `zacharyhutz@gmail.com` and `tylerhutzell4@gmail.com`
- Public, privacy-safe aircraft availability calendar
- Approved-renter reservation requests with overlap protection
- Renter reservation history and cancellations
- **Prepaid 15-, 25-, and 50-hour block balances with three-month expirations**
- **Hour ledger showing purchases and flight deductions**
- **Payment ledger for prepaid blocks and pay-as-you-go flight charges**
- **Post-flight renter reports with Hobbs/tach/fuel/return details**
- **Admin flight finalization that applies eligible block hours first and bills remaining time at $180/hour**
- **Renter aircraft-squawk reporting and admin status tracking**
- **Admin maintenance records linked to squawks when desired**
- Admin maintenance, inspection, owner-use, and unavailable calendar blocks

## Phase 2 database migration — required

The Phase 2 UI depends on new Supabase tables and RPC functions. **Run the database migration before deploying the new pages.**

For an existing Hutzell Aviation Supabase project:

1. Open **Supabase → SQL Editor**.
2. Open `supabase/phase2.sql` from this repository.
3. Paste the entire file into a new SQL query.
4. Click **Run**.
5. Confirm the query completes successfully, then deploy the website files.

`phase2.sql` is designed to be safe to re-run if needed. It also updates the administrator allow-list so a confirmed `tylerhutzell4@gmail.com` account receives administrator access.

For a brand-new Supabase project, run `supabase/setup.sql` first, then run `supabase/phase2.sql`.

## How Phase 2 billing works

### Prepaid blocks

An administrator records a paid 15-, 25-, or 50-hour block from the Admin dashboard. The site creates:

- a paid payment record,
- a three-month block-hour balance,
- and a positive hour-ledger entry.

### Flight closeout

After a confirmed reservation begins, the renter can submit a post-flight report. Tyler/admin then finalizes the recorded aircraft hours.

On finalization, Supabase automatically:

1. finds prepaid blocks that were valid on the date of the flight,
2. applies the earliest-expiring eligible hours first,
3. records each deduction in the hour ledger,
4. marks the reservation completed,
5. and creates a pending pay-as-you-go charge at **$180/hour** for any uncovered flight time.

A flight can only be finalized once, which prevents accidental double deductions.

### Payments

The payment ledger is operational, but **a merchant/card processor is not connected yet**. Admins can record prepaid block payments and mark generated flight charges paid using Card, ACH, Check, Cash, or Other as the bookkeeping method.

## Squawks and maintenance

Approved renters can report an aircraft issue from their account or directly from a confirmed/completed reservation. Reports can be marked normal or urgent.

Admins can:

- move squawks through Open → In progress → Deferred → Resolved,
- create a maintenance record from a squawk,
- track scheduled/in-progress maintenance,
- record Hobbs/tach at completion,
- and separately add a maintenance calendar block when the aircraft should be unavailable.

The squawk form explicitly does not determine airworthiness. Potential safety issues should be handled directly with Tyler and the aircraft should not be dispatched until appropriately addressed. The website maintenance tracker is an internal workflow tool only; it does not replace required aircraft maintenance records, logbook entries, inspections, or return-to-service documentation.

## Still not connected

- Document uploads
- Direct Stripe/card checkout
- Automated email/SMS notifications
- Fuel-receipt uploads
- Overnight/multi-day renter self-service in the browser

The database accepts reservations lasting up to seven days, but the current calendar interface intentionally limits renter self-service to a single day. Tyler can manage exceptions manually while policies are finalized.

## Required Supabase authentication setup

**This dashboard change is required in addition to deploying the website patch.**

1. Open **Supabase → Authentication → URL Configuration** for the Hutzell Aviation project.
2. Set **Site URL** to `https://hutzellaviation.com` (replace any localhost or old GitHub Pages URL).
3. Under **Redirect URLs**, add this **exact** URL:

   ```text
   https://hutzellaviation.com/auth/confirm/?flow=signup
   ```

   This is the callback used by the `Create Account` form. If you also want to use
   a custom token-hash email template or admin invitations, add
   `https://hutzellaviation.com/auth/confirm/` as another allowed URL.
4. Go to **Authentication → Email Templates → Confirm sign up**. The verification
   button should use `{{ .ConfirmationURL }}` so Supabase verifies the user and
   respects the `emailRedirectTo` destination. Remove hard-coded localhost or
   old GitHub Pages links in custom email templates. Do **not** replace
   `{{ .ConfirmationURL }}` with a direct link to the success page: doing so
   skips verification.
5. If sending **Supabase administrator invitations**, also review the **Invite user**
   template. Dashboard invitations without an explicit redirect use the **Site URL**
   as their fallback. They will now land on the live site, but they will not
   automatically use the branded confirmation page unless the invitation
   specifies an allowed redirect or the template is customized appropriately.
6. Deploy the site and test with a **new, unverified email address**. Open the
   verification email, confirm that the browser opens
   `https://hutzellaviation.com/auth/confirm/`, and verify that the success
   page leads to the renter account. Also test an expired/invalid link.

The callback accepts Supabase's normal fragment/PKCE response and also supports
`token_hash` links from a deliberately customized verification email template.
It does not mark an account as verified based on a URL flag alone.

## Required GitHub repository variables

Under **Settings → Secrets and variables → Actions → Variables**, add:

```text
PUBLIC_SUPABASE_URL=https://svcrlkpyudmksrnvgrsj.supabase.co
PUBLIC_SUPABASE_PUBLISHABLE_KEY=your publishable key
```

These are repository **variables**, not secrets. The authentication callback now uses the visitor’s current website origin, so an old `PUBLIC_SITE_URL` variable is **not required** and should be removed if it points at GitHub Pages or localhost. Never place a Supabase secret/service-role key in this static site.

## Deploy

The included `.github/workflows/main.yml` builds and deploys the Astro site through GitHub Actions whenever `main` changes.

1. Run the Phase 2 Supabase migration first.
2. Upload the changed files to the repository using the same paths shown in the update ZIP.
3. Confirm **Settings → Pages → Source** is set to **GitHub Actions**.
4. Commit to `main`.

## Run locally

```bash
npm install
npm run dev
```

## Stripe Checkout

Stripe Checkout support is now included for approved renter accounts. See `STRIPE_DEPLOY.md` for the database migration, Edge Function deployment, webhook setup, and testing sequence.

The Stripe secret stays in Supabase Edge Function secrets. The static GitHub Pages bundle contains only Stripe Price IDs, never an API secret. Checkout Sessions are created server-side only after Supabase authenticates the renter and confirms the account is approved.
