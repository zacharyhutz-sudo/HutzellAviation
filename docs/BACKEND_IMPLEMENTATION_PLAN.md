# Backend implementation plan

The included website is a static front-end release. The availability calendar and renter application are interactive prototypes, but they do not save data.

## Recommended production architecture

- Astro: public pages and renter/admin interfaces
- Supabase Auth: renter and administrator sign-in
- Supabase Postgres: aircraft, applications, approvals, blocks, reservations, packages, and ledgers
- Supabase Storage: private renter-document uploads
- Supabase Edge Functions: privileged booking and payment operations
- Stripe Checkout: pay-as-you-go reservations and hour-block purchases

## Production milestones

### 1. Authentication and profiles

Create user accounts, profiles, renter roles, and an administrator role for Tyler. A new user starts with an unapproved status and cannot reserve the aircraft.

### 2. Renter applications

Store application fields and private documents. Tyler can mark an application as submitted, needs-information, checkout-required, approved, rejected, expired, or suspended.

### 3. Aircraft and blocks

Create the Piper Cherokee record. Tyler can block maintenance, owner use, inspections, weather closures, or other unavailable periods.

### 4. Reservations

Store scheduled departure and return separately from estimated and actual billable aircraft hours. Create a short reservation hold while the renter completes checkout.

### 5. Overlap protection

Use a PostgreSQL timestamp range and exclusion constraint so active holds, reservations, and aircraft blocks cannot overlap for the same aircraft. The database must make the final conflict decision.

### 6. Pricing and package ledger

Store pricing plans in the database. Every package purchase, flight deduction, credit, correction, or expiration creates a ledger entry. Do not rely on one manually editable balance field.

### 7. Stripe

Create Checkout Sessions in a secure Edge Function. Confirm purchases and reservations from verified Stripe webhooks, not from the browser success page.

### 8. Flight completion

Tyler records beginning and ending meter readings, actual aircraft hours, adjustments, squawks, and final charges. The system then applies the flight to the renter ledger or invoice.

## Suggested core tables

- profiles
- renter_applications
- renter_approvals
- renter_documents
- aircraft
- aircraft_images
- aircraft_notices
- pricing_plans
- customer_packages
- hour_transactions
- availability_rules
- reservations
- reservation_holds
- aircraft_blocks
- payments
- flight_records
- maintenance_squawks
- policy_acceptances
- admin_audit_log

## Security requirements

- Enable Row Level Security on every exposed table.
- Keep Supabase service-role keys and Stripe secret keys out of browser code.
- Keep renter documents in a private bucket.
- Public visitors may see availability status but never renter identities or trip notes.
- Approved renters may only access their own bookings, packages, receipts, and documents.
- Admin actions should create audit-log entries.
