-- Hutzell Aviation Stripe checkout support
-- Run after supabase/setup.sql and supabase/phase2.sql.
-- Safe to re-run.

-- Stripe Checkout Session IDs begin with cs_. Keep them unique when stored in the
-- existing payment reference column so webhook retries cannot fulfill twice.
create unique index if not exists payments_unique_stripe_checkout_reference
on public.payments(reference)
where reference like 'cs_%';

create or replace function public.stripe_fulfill_block_purchase(
  p_renter_id uuid,
  p_package_hours numeric,
  p_checkout_session_id text,
  p_amount_cents integer
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  rate_cents integer;
  expected_amount integer;
  existing_purchase_id uuid;
  payment_id uuid;
  purchase_id uuid;
begin
  if p_checkout_session_id is null or p_checkout_session_id not like 'cs_%' then
    raise exception 'Invalid Stripe Checkout Session ID.';
  end if;

  if p_package_hours = 15 then rate_cents := 17000;
  elsif p_package_hours = 25 then rate_cents := 16500;
  elsif p_package_hours = 50 then rate_cents := 15000;
  else raise exception 'Package must be 15, 25, or 50 hours.';
  end if;

  expected_amount := round(p_package_hours * rate_cents)::integer;
  if p_amount_cents <> expected_amount then
    raise exception 'Stripe amount does not match package price.';
  end if;

  select bhp.id into existing_purchase_id
  from public.block_hour_purchases bhp
  join public.payments p on p.id = bhp.payment_id
  where p.reference = p_checkout_session_id
  limit 1;

  if existing_purchase_id is not null then
    return existing_purchase_id;
  end if;

  insert into public.payments (
    renter_id, kind, status, amount_cents, method, description, reference, paid_at, created_by
  ) values (
    p_renter_id, 'block_purchase', 'paid', expected_amount, 'card',
    trim(p_package_hours::text) || '-hour prepaid block — Stripe',
    p_checkout_session_id, now(), null
  ) returning id into payment_id;

  insert into public.block_hour_purchases (
    renter_id, payment_id, package_hours, rate_per_hour_cents, remaining_hours,
    purchased_at, expires_at, status, notes, created_by
  ) values (
    p_renter_id, payment_id, p_package_hours, rate_cents, p_package_hours,
    now(), now() + interval '3 months', 'active', 'Purchased through Stripe Checkout', null
  ) returning id into purchase_id;

  insert into public.hour_ledger (
    renter_id, block_purchase_id, entry_type, hours_delta, note, created_by
  ) values (
    p_renter_id, purchase_id, 'purchase', p_package_hours,
    trim(p_package_hours::text) || '-hour prepaid block purchased through Stripe', null
  );

  return purchase_id;
end;
$$;

create or replace function public.stripe_fulfill_account_payment(
  p_renter_id uuid,
  p_payment_id uuid,
  p_checkout_session_id text,
  p_amount_cents integer
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  payment_row public.payments%rowtype;
begin
  if p_checkout_session_id is null or p_checkout_session_id not like 'cs_%' then
    raise exception 'Invalid Stripe Checkout Session ID.';
  end if;

  select * into payment_row
  from public.payments
  where id = p_payment_id
    and renter_id = p_renter_id
  for update;

  if not found then
    raise exception 'Payment not found for renter.';
  end if;

  -- Stripe can retry the same webhook. Treat an already-fulfilled matching session as success.
  if payment_row.status = 'paid' then
    return payment_row.id;
  end if;

  if payment_row.status <> 'pending' then
    raise exception 'Payment is no longer payable.';
  end if;

  if payment_row.amount_cents <> p_amount_cents then
    raise exception 'Stripe amount does not match outstanding charge.';
  end if;

  update public.payments
  set status = 'paid',
      method = 'card',
      reference = p_checkout_session_id,
      paid_at = now(),
      updated_at = now()
  where id = p_payment_id;

  return p_payment_id;
end;
$$;

revoke all on function public.stripe_fulfill_block_purchase(uuid,numeric,text,integer) from public, anon, authenticated;
revoke all on function public.stripe_fulfill_account_payment(uuid,uuid,text,integer) from public, anon, authenticated;
grant execute on function public.stripe_fulfill_block_purchase(uuid,numeric,text,integer) to service_role;
grant execute on function public.stripe_fulfill_account_payment(uuid,uuid,text,integer) to service_role;
