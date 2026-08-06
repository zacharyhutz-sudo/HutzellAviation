# Hutzell Aviation website — live renter calendar

This Astro project presents Hutzell Aviation LLC as a Piper Cherokee aircraft-rental company for approved pilots and time builders. It does not advertise flight instruction through the aircraft.


## Calendar panel visibility patch (v3.0.1)

- Keeps the selected-date booking panel beside the calendar on laptop and tablet-width desktop layouts.
- Stacks the panel only at 820px and below.
- Automatically scrolls the booking panel into view after a date is selected on narrow screens.
- Adds explicit hidden-state CSS so the empty and selected-date panels cannot overlap.

## Live features

- Supabase email/password renter accounts
- Email-confirmation-compatible registration and login
- Renter application stored in Supabase
- Administrator role for `zacharyhutz@gmail.com`
- Administrator approval workflow
- Public, privacy-safe aircraft calendar
- Same-day departure and return-time selection
- Approved-renter reservation requests
- Database-level protection against overlapping active reservations
- Renter dashboard with reservation history and cancellation
- Admin reservation review and status controls
- Admin maintenance, inspection, owner-use, and unavailable calendar blocks
- Responsive replacement logo with a transparent background

## Not connected yet

- Document uploads
- Stripe checkout
- Prepaid-hour balances and ledger
- Final rates and billing reconciliation
- Automated email notifications
- Overnight/multi-day selection in the browser

The database accepts reservations lasting up to seven days, but the first calendar interface intentionally limits renter self-service to a single day. Tyler can manage exceptions manually while policies are finalized.

## Required Supabase setup

1. Open the Supabase project.
2. Go to **SQL Editor**.
3. Paste and run `supabase/setup.sql`.
4. Go to **Authentication → URL Configuration**.
5. Set the site URL to:

```text
https://zacharyhutz-sudo.github.io/HutzellAviation/
```

6. Add this redirect URL:

```text
https://zacharyhutz-sudo.github.io/HutzellAviation/**
```

7. Create or sign in with `zacharyhutz@gmail.com`. The SQL backfill and auth trigger assign that verified email the initial administrator role.

## Required GitHub repository variables

Under **Settings → Secrets and variables → Actions → Variables**, add:

```text
PUBLIC_SUPABASE_URL=https://svcrlkpyudmksrnvgrsj.supabase.co
PUBLIC_SUPABASE_PUBLISHABLE_KEY=your publishable key
PUBLIC_SITE_URL=https://zacharyhutz-sudo.github.io/HutzellAviation/
```

These are repository **variables**, not environment variables and not secrets. Never place a Supabase secret/service-role key in this static site.

## Deploy

The included `.github/workflows/deploy.yml` builds and deploys the Astro site through GitHub Actions whenever `main` changes.

1. Upload the contents of this ZIP to the repository root.
2. Confirm `.github/workflows/deploy.yml` exists.
3. Set **Settings → Pages → Source** to **GitHub Actions**.
4. Commit to `main`.

## Run locally

Copy `.env.example` to `.env`, supply the publishable key, then run:

```bash
npm install
npm run dev
```

## Content still needed

Edit `src/data/site.ts` when final information is available:

- Business phone and email
- Home airport
- Exact aircraft model, year, tail number, avionics, and specifications
- Final rental requirements and policies
- Pay-as-you-go and block-hour rates
- Tyler's full biography and actual photography
