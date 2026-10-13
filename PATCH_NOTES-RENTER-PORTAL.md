# Hutzell Aviation renter portal patch

Prepared October 12, 2026 from the uploaded HutzellAviation-main.zip, archive commit `7810c650c05b09b978be962dac91403e74a200e0`.

## Install

1. Extract this ZIP.
2. Copy its `src` folder into the root of your HutzellAviation repository, merging folders and replacing matching files. Copy this patch-notes file alongside it. Do not delete the other files in your repository.
3. Commit the changed files. The existing GitHub Actions workflow remains responsible for building and deploying the site.
4. Check the build result and perform the smoke checks below before relying on the updated renter flow.

For GitHub's browser uploader, open the repository root, choose **Add file → Upload files**, and drag the extracted `src` folder and patch-notes file into the uploader. Preserve the folder paths; do not upload the ZIP itself as the implementation.

This patch has 18 changed or new source files, plus these notes. It does not require a new dependency, database migration, or redeployment of Supabase Edge Functions. It uses the existing Supabase tables/RPCs and Stripe checkout functions. Compare any changes made after the archive snapshot before replacing files.

## Changes

- Separate sign-in and registration from the signed-in renter workspace.
- Bound the login logo using its natural proportions and explicit spacing; remove conflicting legacy login-logo rules.
- Enforce ordinary hidden states so grid/flex styling cannot expose hidden forms, dashboard sections, or account links.
- Replace duplicate account/dashboard links with one Renter Portal destination.
- Add shared account state for the header, portal, and schedule.
- Add Schedule, My Flights, and Hours & Payments navigation, including a mobile bottom bar with device safe-area spacing.
- Put the next flight, remaining prepaid hours, and outstanding balance at the top of the portal.
- Sort upcoming flights in departure order; separate flight history and reports awaiting completion.
- Display all pending charges before payment history, fetching payment records across API pages; paginate the rendered payment history.
- Confirm Stripe results only after a matching paid transaction appears in the database. Retry confirmation for a bounded period, then offer manual refresh and clear guidance.
- Preserve a booking draft through sign-in in the current browser tab, with a two-hour expiry and account ownership check. Browser storage failure does not prevent booking.
- Keep booking confirmations/errors visible after a calendar refresh and preserve inputs when submission fails.
- Disable requests and mark availability unknown when calendar retrieval fails. Ignore stale responses from earlier month loads.
- Prevent editing a flight request while submission is in progress.
- Replace the long homepage with a compact scheduling/payment entry point, rates, renter onboarding, and supporting information links.
- Restore a public Rates page instead of redirecting everyone to account sign-in.
- Route the legacy checkout page into Hours & Payments; retain /account/ and #purchase-hours links.
- Add accessible auth-tab behavior, focus outlines, selected-date semantics, profile-loading recovery, and a slow-loading reload fallback.
- Use the current site origin and base path for email-confirmation returns when PUBLIC_SITE_URL is not explicitly configured. An explicit PUBLIC_SITE_URL still takes precedence.

Published rates, application approval requirements, reservation approval, and backend payment rules remain as defined in the source snapshot. The existing page copy says the aircraft is being prepared for rental; this patch preserves that business-readiness qualification.

## Verification completed

- Parsed 46 TypeScript/JavaScript and Astro frontmatter/script blocks without syntax errors using Node's TypeScript transformation and JavaScript module parser.
- Resolved 107 local source imports and checked CSS delimiter balance.
- Passed 13 focused behavior checks using the actual page/module scripts with a mocked DOM and mocked backend:
  1. Anonymous booking draft survives sign-in; another renter's draft is rejected.
  2. Signed-out account display and auth-tab selection.
  3. Approved portal state, nearest upcoming flight, and separated history.
  4. Older unpaid charges remain payable; URL parameters cannot confirm a payment.
  5. Matching persisted payment confirms checkout.
  6. Pending renter cannot start online checkout.
  7. Profile failure hides the workspace and offers recovery.
  8. Unpaid charges beyond the first API page remain visible.
  9. Calendar failure disables booking and marks availability unknown.
  10. Booking error remains visible after refresh with times preserved.
  11. Booking success remains visible after refresh.
  12. Signed-out booking routes to sign-in with a return destination.
  13. Eastern-time conversion produces correct winter and summer offsets.
- ZIP entries are compared against the uploaded archive and contain only added/changed source files and these notes. No generated build output or node_modules is included.

## Verification limits and deployment checks

The environment rejected npm and Chromium downloads with HTTP 403. A full Astro build, Astro template compilation, visual browser testing, real iPhone Safari testing, and live Supabase/Stripe integration testing could not be run here. The checks above are not substitutes for those gates. No production reservation, payment, or account mutation was performed.

Before using the deployed patch:

- Confirm `npm install` and `npm run build` succeed, or check the existing GitHub Actions build.
- Check 320, 375, 390, 768, 1024, and 1440 px layouts and increased text size. Verify no logo/tab collision, horizontal scrolling, or controls covered by the mobile bottom navigation.
- Try sign-in/registration tabs, email confirmation, sign-out, profile-loading errors, and incomplete/pending/approved/suspended/rejected/admin account states. Confirm the intended Supabase redirect URL is allowed for the deployed domain.
- Check root and GitHub Pages subpath hosting with the appropriate BASE_PATH. Try /account/, #flights, #payments, #purchase-hours, /availability/, /pricing/, and /checkout/.
- Select a flight while signed out, sign in, verify restored times, and submit a request. Check pending/confirmed/cancelled states, conflicting requests, lost connectivity, and post-flight navigation against the actual backend.
- In Stripe test mode, try block purchases and existing-charge payments, a cancelled checkout, slow webhook delivery, and webhook retries. Verify the existing Edge Function SITE_URL points to the deployed site and check transaction ownership and final balances.
- Existing scheduling policy enforcement belongs to the backend. In particular, published turnaround/overnight policies should be checked against the deployed database; this UI patch does not add new reservation policy SQL.

## Included source files

- src/components/CallToAction.astro
- src/components/Footer.astro
- src/components/Header.astro
- src/components/PortalNav.astro (new)
- src/data/site.ts
- src/lib/booking-draft.ts (new)
- src/lib/session.ts (new)
- src/lib/supabase.ts
- src/pages/account.astro
- src/pages/aircraft.astro
- src/pages/apply.astro
- src/pages/availability.astro
- src/pages/checkout.astro
- src/pages/index.astro
- src/pages/postflight.astro
- src/pages/pricing.astro
- src/pages/report-squawk.astro
- src/styles/global.css
