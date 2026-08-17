# Stripe Checkout deployment

This patch connects Hutzell Aviation's approved renter portal to Stripe Checkout through Supabase Edge Functions.

## What is already configured in code

- 15-hour Stripe Price ID: `price_1U3L2d17udspvQmKM3x5lvjU`
- 25-hour Stripe Price ID: `price_1U3L5217udspvQmKO6d2MsqT`
- 50-hour Stripe Price ID: `price_1U3L5u17udspvQmKj8isyIuF`
- Stripe API secret name: `STRIPE_SECRET_KEY`
- Checkout is created only after Supabase authenticates the user and the function confirms `approval_status = 'approved'` or `role = 'admin'`.
- Stripe card details never pass through the GitHub Pages site.

## 1. Run the Stripe database migration

In Supabase Dashboard → SQL Editor:

1. Open `supabase/stripe.sql` from this repository.
2. Paste the whole file into a new query.
3. Run it once.

This adds idempotent Stripe fulfillment functions for block purchases and outstanding account charges.

## 2. Confirm the Stripe secret

In Supabase Dashboard → Edge Functions → Secrets, confirm this secret exists:

```text
STRIPE_SECRET_KEY
```

The value must be the current restricted live key. Do not put the value in GitHub.

## 3. Deploy the Edge Functions

The repository contains:

```text
supabase/functions/create-checkout-session/index.ts
supabase/functions/stripe-webhook/index.ts
supabase/config.toml
```

With the Supabase CLI linked to this project, deploy both functions:

```bash
supabase functions deploy create-checkout-session
supabase functions deploy stripe-webhook
```

`create-checkout-session` requires a signed-in Supabase user JWT. `stripe-webhook` intentionally does not require a Supabase JWT because Stripe authenticates webhook requests with its signature.

## 4. Create the Stripe webhook endpoint

After `stripe-webhook` is deployed, its endpoint is:

```text
https://svcrlkpyudmksrnvgrsj.supabase.co/functions/v1/stripe-webhook
```

In Stripe Dashboard, create a webhook endpoint for that URL and subscribe to:

```text
checkout.session.completed
```

Copy the webhook signing secret Stripe gives you. It starts with `whsec_`.

## 5. Store the webhook secret in Supabase

In Supabase Dashboard → Edge Functions → Secrets, add:

```text
STRIPE_WEBHOOK_SIGNING_SECRET
```

Paste the `whsec_...` value as the secret value.

Redeploy `stripe-webhook` after adding the secret if Supabase does not automatically expose the new secret to the existing deployment.

## 6. Deploy the website

Deploy the updated Astro/GitHub Pages site.

Approved renters will see:

- Purchase 15 Hours — $2,550
- Purchase 25 Hours — $4,125
- Purchase 50 Hours — $7,500
- Pay buttons on pending account charges

Pending/unapproved users do not receive the Stripe purchase controls. More importantly, direct calls to the checkout function are independently rejected unless the authenticated profile is approved.

## 7. Test before normal use

Because the supplied Stripe Price IDs and API key are live, use a real approved account and perform a controlled low-risk verification before advertising checkout broadly. Confirm:

1. Pending/unapproved accounts cannot create checkout sessions.
2. Approved accounts can open Stripe Checkout.
3. The checkout amount matches the selected package.
4. A successful block purchase creates a paid payment record, a three-month block balance, and a positive hour-ledger entry.
5. A successful outstanding-charge payment changes that payment from `pending` to `paid`.
6. Re-sending the same Stripe webhook does not duplicate a block purchase.
