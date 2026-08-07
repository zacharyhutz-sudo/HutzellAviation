-- Hutzell Aviation Phase 2 operations migration
-- Adds prepaid block-hour balances, payment records, post-flight reporting,
-- squawk tracking, and maintenance records.
--
-- Existing project: run this file once in Supabase Dashboard -> SQL Editor.
-- Safe to re-run; objects are created/replaced idempotently where practical.

begin;

create extension if not exists pgcrypto;
create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

-- Keep both current owners/admins on the administrator allow-list.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  is_initial_admin boolean;
begin
  is_initial_admin := lower(coalesce(new.email, '')) in ('zacharyhutz@gmail.com', 'tylerhutzell4@gmail.com')
    and new.email_confirmed_at is not null;
  insert into public.profiles (id, email, full_name, phone, role, approval_status)
  values (
    new.id,
    lower(coalesce(new.email, '')),
    nullif(new.raw_user_meta_data ->> 'full_name', ''),
    nullif(new.raw_user_meta_data ->> 'phone', ''),
    case when is_initial_admin then 'admin' else 'renter' end,
    case when is_initial_admin then 'approved' else 'incomplete' end
  )
  on conflict (id) do update set
    email = excluded.email,
    full_name = coalesce(public.profiles.full_name, excluded.full_name),
    phone = coalesce(public.profiles.phone, excluded.phone),
    role = case when is_initial_admin then 'admin' else public.profiles.role end,
    approval_status = case when is_initial_admin then 'approved' else public.profiles.approval_status end,
    updated_at = now();
  return new;
end;
$$;

-- Backfill the authorized admins immediately if their confirmed Auth users already exist.
insert into public.profiles (id, email, full_name, phone, role, approval_status)
select
  u.id,
  lower(coalesce(u.email, '')),
  nullif(u.raw_user_meta_data ->> 'full_name', ''),
  nullif(u.raw_user_meta_data ->> 'phone', ''),
  'admin',
  'approved'
from auth.users u
where lower(coalesce(u.email, '')) in ('zacharyhutz@gmail.com', 'tylerhutzell4@gmail.com')
  and u.email_confirmed_at is not null
on conflict (id) do update set
  email = excluded.email,
  role = 'admin',
  approval_status = 'approved',
  updated_at = now();

create table if not exists public.payments (
  id uuid primary key default gen_random_uuid(),
  renter_id uuid not null references public.profiles(id) on delete cascade,
  reservation_id uuid references public.reservations(id) on delete set null,
  kind text not null check (kind in ('block_purchase','flight_charge','fee','adjustment','refund')),
  status text not null default 'pending' check (status in ('pending','paid','void','refunded')),
  amount_cents integer not null check (amount_cents >= 0),
  method text check (method is null or method in ('cash','check','card','ach','other')),
  description text,
  reference text,
  paid_at timestamptz,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.block_hour_purchases (
  id uuid primary key default gen_random_uuid(),
  renter_id uuid not null references public.profiles(id) on delete cascade,
  payment_id uuid references public.payments(id) on delete set null,
  package_hours numeric(7,1) not null check (package_hours > 0),
  rate_per_hour_cents integer not null check (rate_per_hour_cents > 0),
  remaining_hours numeric(7,1) not null check (remaining_hours >= 0),
  purchased_at timestamptz not null default now(),
  expires_at timestamptz not null,
  status text not null default 'active' check (status in ('active','exhausted','expired','void')),
  notes text,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint block_remaining_not_over_purchase check (remaining_hours <= package_hours)
);

create table if not exists public.hour_ledger (
  id uuid primary key default gen_random_uuid(),
  renter_id uuid not null references public.profiles(id) on delete cascade,
  block_purchase_id uuid references public.block_hour_purchases(id) on delete set null,
  reservation_id uuid references public.reservations(id) on delete set null,
  entry_type text not null check (entry_type in ('purchase','flight','adjustment','refund','expiration')),
  hours_delta numeric(7,1) not null check (hours_delta <> 0),
  note text,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now()
);

create table if not exists public.flight_logs (
  id uuid primary key default gen_random_uuid(),
  reservation_id uuid not null unique references public.reservations(id) on delete cascade,
  renter_id uuid not null references public.profiles(id) on delete cascade,
  aircraft_id uuid not null references public.aircraft(id),
  hobbs_start numeric(10,1),
  hobbs_end numeric(10,1),
  tach_start numeric(10,1),
  tach_end numeric(10,1),
  actual_aircraft_hours numeric(7,1) not null check (actual_aircraft_hours > 0),
  fuel_added_gallons numeric(7,1) check (fuel_added_gallons is null or fuel_added_gallons >= 0),
  returned_to_base boolean not null default true,
  renter_notes text,
  admin_notes text,
  status text not null default 'submitted' check (status in ('submitted','needs_review','approved')),
  block_hours_applied numeric(7,1) not null default 0 check (block_hours_applied >= 0),
  payg_hours numeric(7,1) not null default 0 check (payg_hours >= 0),
  submitted_at timestamptz not null default now(),
  reviewed_at timestamptz,
  reviewed_by uuid references public.profiles(id),
  updated_at timestamptz not null default now(),
  constraint flight_hobbs_order check (hobbs_start is null or hobbs_end is null or hobbs_end >= hobbs_start),
  constraint flight_tach_order check (tach_start is null or tach_end is null or tach_end >= tach_start)
);

create table if not exists public.aircraft_squawks (
  id uuid primary key default gen_random_uuid(),
  aircraft_id uuid not null references public.aircraft(id),
  reservation_id uuid references public.reservations(id) on delete set null,
  reported_by uuid not null references public.profiles(id),
  title text not null,
  description text not null,
  priority text not null default 'normal' check (priority in ('normal','urgent')),
  status text not null default 'open' check (status in ('open','in_progress','deferred','resolved')),
  admin_notes text,
  resolved_at timestamptz,
  resolved_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.maintenance_records (
  id uuid primary key default gen_random_uuid(),
  aircraft_id uuid not null references public.aircraft(id),
  squawk_id uuid references public.aircraft_squawks(id) on delete set null,
  title text not null,
  maintenance_type text not null check (maintenance_type in ('inspection','repair','preventive','service','other')),
  status text not null default 'scheduled' check (status in ('scheduled','in_progress','completed','cancelled')),
  scheduled_for date,
  completed_at timestamptz,
  hobbs_at_completion numeric(10,1),
  tach_at_completion numeric(10,1),
  notes text,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists payments_renter_created_idx on public.payments(renter_id, created_at desc);
create index if not exists payments_reservation_idx on public.payments(reservation_id);
create index if not exists block_purchases_renter_expiry_idx on public.block_hour_purchases(renter_id, expires_at);
create index if not exists hour_ledger_renter_created_idx on public.hour_ledger(renter_id, created_at desc);
create index if not exists flight_logs_renter_submitted_idx on public.flight_logs(renter_id, submitted_at desc);
create index if not exists squawks_aircraft_status_idx on public.aircraft_squawks(aircraft_id, status, created_at desc);
create index if not exists squawks_reporter_idx on public.aircraft_squawks(reported_by, created_at desc);
create index if not exists maintenance_aircraft_status_idx on public.maintenance_records(aircraft_id, status, scheduled_for);

-- One live pay-as-you-go charge per reservation.
create unique index if not exists payments_one_live_flight_charge_per_reservation
on public.payments(reservation_id)
where kind = 'flight_charge' and status in ('pending','paid');

alter table public.payments enable row level security;
alter table public.block_hour_purchases enable row level security;
alter table public.hour_ledger enable row level security;
alter table public.flight_logs enable row level security;
alter table public.aircraft_squawks enable row level security;
alter table public.maintenance_records enable row level security;

drop policy if exists "Users can view own payments" on public.payments;
drop policy if exists "Admins can view all payments" on public.payments;
drop policy if exists "Users can view own block purchases" on public.block_hour_purchases;
drop policy if exists "Admins can view all block purchases" on public.block_hour_purchases;
drop policy if exists "Users can view own hour ledger" on public.hour_ledger;
drop policy if exists "Admins can view all hour ledger" on public.hour_ledger;
drop policy if exists "Users can view own flight logs" on public.flight_logs;
drop policy if exists "Admins can view all flight logs" on public.flight_logs;
drop policy if exists "Users can view own squawks" on public.aircraft_squawks;
drop policy if exists "Admins can view all squawks" on public.aircraft_squawks;
drop policy if exists "Admins can view maintenance records" on public.maintenance_records;

create policy "Users can view own payments"
on public.payments for select to authenticated
using (renter_id = (select auth.uid()));

create policy "Admins can view all payments"
on public.payments for select to authenticated
using ((select private.is_admin()));

create policy "Users can view own block purchases"
on public.block_hour_purchases for select to authenticated
using (renter_id = (select auth.uid()));

create policy "Admins can view all block purchases"
on public.block_hour_purchases for select to authenticated
using ((select private.is_admin()));

create policy "Users can view own hour ledger"
on public.hour_ledger for select to authenticated
using (renter_id = (select auth.uid()));

create policy "Admins can view all hour ledger"
on public.hour_ledger for select to authenticated
using ((select private.is_admin()));

create policy "Users can view own flight logs"
on public.flight_logs for select to authenticated
using (renter_id = (select auth.uid()));

create policy "Admins can view all flight logs"
on public.flight_logs for select to authenticated
using ((select private.is_admin()));

create policy "Users can view own squawks"
on public.aircraft_squawks for select to authenticated
using (reported_by = (select auth.uid()));

create policy "Admins can view all squawks"
on public.aircraft_squawks for select to authenticated
using ((select private.is_admin()));

create policy "Admins can view maintenance records"
on public.maintenance_records for select to authenticated
using ((select private.is_admin()));

create or replace function public.submit_postflight_report(
  p_reservation_id uuid,
  p_actual_aircraft_hours numeric,
  p_hobbs_start numeric default null,
  p_hobbs_end numeric default null,
  p_tach_start numeric default null,
  p_tach_end numeric default null,
  p_fuel_added_gallons numeric default null,
  p_returned_to_base boolean default true,
  p_notes text default null
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  user_id uuid := (select auth.uid());
  reservation_row public.reservations%rowtype;
  result_id uuid;
begin
  if user_id is null then raise exception 'You must be signed in.'; end if;
  select * into reservation_row from public.reservations
  where id = p_reservation_id and renter_id = user_id;
  if not found then raise exception 'Reservation not found.'; end if;
  if reservation_row.status not in ('confirmed','completed') then
    raise exception 'Only confirmed flights can be closed out.';
  end if;
  if now() < reservation_row.starts_at then
    raise exception 'Post-flight details cannot be submitted before the reservation begins.';
  end if;
  if p_actual_aircraft_hours is null or p_actual_aircraft_hours <= 0 or p_actual_aircraft_hours > 168 then
    raise exception 'Recorded aircraft time must be between 0.1 and 168 hours.';
  end if;
  if p_hobbs_start is not null and p_hobbs_end is not null and p_hobbs_end < p_hobbs_start then
    raise exception 'Ending Hobbs time cannot be lower than starting Hobbs time.';
  end if;
  if p_tach_start is not null and p_tach_end is not null and p_tach_end < p_tach_start then
    raise exception 'Ending tach time cannot be lower than starting tach time.';
  end if;
  if p_fuel_added_gallons is not null and p_fuel_added_gallons < 0 then
    raise exception 'Fuel added cannot be negative.';
  end if;
  if length(coalesce(p_notes, '')) > 1500 then
    raise exception 'Post-flight notes cannot exceed 1500 characters.';
  end if;

  insert into public.flight_logs (
    reservation_id, renter_id, aircraft_id, hobbs_start, hobbs_end, tach_start, tach_end,
    actual_aircraft_hours, fuel_added_gallons, returned_to_base, renter_notes,
    status, submitted_at, updated_at
  ) values (
    reservation_row.id, user_id, reservation_row.aircraft_id,
    p_hobbs_start, p_hobbs_end, p_tach_start, p_tach_end,
    p_actual_aircraft_hours, p_fuel_added_gallons, coalesce(p_returned_to_base, true),
    nullif(trim(p_notes), ''), 'submitted', now(), now()
  )
  on conflict (reservation_id) do update set
    hobbs_start = excluded.hobbs_start,
    hobbs_end = excluded.hobbs_end,
    tach_start = excluded.tach_start,
    tach_end = excluded.tach_end,
    actual_aircraft_hours = excluded.actual_aircraft_hours,
    fuel_added_gallons = excluded.fuel_added_gallons,
    returned_to_base = excluded.returned_to_base,
    renter_notes = excluded.renter_notes,
    status = case when public.flight_logs.status = 'approved' then 'approved' else 'submitted' end,
    submitted_at = case when public.flight_logs.status = 'approved' then public.flight_logs.submitted_at else now() end,
    updated_at = now()
  returning id into result_id;

  if exists (select 1 from public.flight_logs where id = result_id and status = 'approved') then
    raise exception 'This flight has already been finalized by an administrator.';
  end if;

  return result_id;
end;
$$;

create or replace function public.submit_squawk(
  p_aircraft_id uuid,
  p_reservation_id uuid,
  p_title text,
  p_description text,
  p_priority text default 'normal'
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  user_id uuid := (select auth.uid());
  result_id uuid;
begin
  if user_id is null then raise exception 'You must be signed in.'; end if;
  if not (select private.is_approved_renter()) then raise exception 'Approved renter access required.'; end if;
  if p_priority not in ('normal','urgent') then raise exception 'Invalid squawk priority.'; end if;
  if nullif(trim(p_title), '') is null then raise exception 'A short issue title is required.'; end if;
  if nullif(trim(p_description), '') is null then raise exception 'Describe the aircraft issue.'; end if;
  if length(p_title) > 120 or length(p_description) > 2000 then raise exception 'Squawk text is too long.'; end if;
  if not exists (select 1 from public.aircraft where id = p_aircraft_id and active) then
    raise exception 'Aircraft not found.';
  end if;
  if p_reservation_id is not null and not exists (
    select 1 from public.reservations where id = p_reservation_id and renter_id = user_id and aircraft_id = p_aircraft_id
  ) then
    raise exception 'Reservation does not belong to this renter.';
  end if;

  insert into public.aircraft_squawks (
    aircraft_id, reservation_id, reported_by, title, description, priority, status
  ) values (
    p_aircraft_id, p_reservation_id, user_id, trim(p_title), trim(p_description), p_priority, 'open'
  ) returning id into result_id;
  return result_id;
end;
$$;

create or replace function public.admin_record_block_purchase(
  p_renter_id uuid,
  p_package_hours numeric,
  p_payment_method text default null,
  p_reference text default null,
  p_notes text default null
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  rate_cents integer;
  payment_amount integer;
  payment_id uuid;
  purchase_id uuid;
begin
  if not (select private.is_admin()) then raise exception 'Administrator access required.'; end if;
  if not exists (select 1 from public.profiles where id = p_renter_id) then raise exception 'Renter not found.'; end if;
  if p_package_hours = 15 then rate_cents := 17000;
  elsif p_package_hours = 25 then rate_cents := 16500;
  elsif p_package_hours = 50 then rate_cents := 15000;
  else raise exception 'Package must be 15, 25, or 50 hours.';
  end if;
  if p_payment_method is not null and p_payment_method not in ('cash','check','card','ach','other') then
    raise exception 'Invalid payment method.';
  end if;

  payment_amount := round(p_package_hours * rate_cents)::integer;
  insert into public.payments (
    renter_id, kind, status, amount_cents, method, description, reference, paid_at, created_by
  ) values (
    p_renter_id, 'block_purchase', 'paid', payment_amount, p_payment_method,
    trim(p_package_hours::text) || '-hour prepaid block', nullif(trim(p_reference), ''), now(), (select auth.uid())
  ) returning id into payment_id;

  insert into public.block_hour_purchases (
    renter_id, payment_id, package_hours, rate_per_hour_cents, remaining_hours,
    purchased_at, expires_at, status, notes, created_by
  ) values (
    p_renter_id, payment_id, p_package_hours, rate_cents, p_package_hours,
    now(), now() + interval '3 months', 'active', nullif(trim(p_notes), ''), (select auth.uid())
  ) returning id into purchase_id;

  insert into public.hour_ledger (
    renter_id, block_purchase_id, entry_type, hours_delta, note, created_by
  ) values (
    p_renter_id, purchase_id, 'purchase', p_package_hours,
    trim(p_package_hours::text) || '-hour prepaid block purchased', (select auth.uid())
  );

  return purchase_id;
end;
$$;

create or replace function public.admin_set_payment_status(
  p_payment_id uuid,
  p_status text,
  p_method text default null,
  p_reference text default null
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not (select private.is_admin()) then raise exception 'Administrator access required.'; end if;
  if p_status not in ('pending','paid','void','refunded') then raise exception 'Invalid payment status.'; end if;
  if p_method is not null and p_method not in ('cash','check','card','ach','other') then raise exception 'Invalid payment method.'; end if;

  update public.payments
  set status = p_status,
      method = coalesce(p_method, method),
      reference = coalesce(nullif(trim(p_reference), ''), reference),
      paid_at = case when p_status = 'paid' then coalesce(paid_at, now()) else paid_at end,
      updated_at = now()
  where id = p_payment_id;
  if not found then raise exception 'Payment not found.'; end if;
end;
$$;

create or replace function public.admin_finalize_flight(
  p_reservation_id uuid,
  p_actual_aircraft_hours numeric,
  p_admin_notes text default null
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  reservation_row public.reservations%rowtype;
  log_id uuid;
  purchase_row public.block_hour_purchases%rowtype;
  hours_remaining numeric(7,1);
  hours_to_use numeric(7,1);
  v_applied_hours numeric(7,1) := 0;
  v_payg_hours numeric(7,1) := 0;
  charge_cents integer := 0;
begin
  if not (select private.is_admin()) then raise exception 'Administrator access required.'; end if;
  if p_actual_aircraft_hours is null or p_actual_aircraft_hours <= 0 or p_actual_aircraft_hours > 168 then
    raise exception 'Actual aircraft hours must be between 0.1 and 168.';
  end if;

  select * into reservation_row from public.reservations where id = p_reservation_id for update;
  if not found then raise exception 'Reservation not found.'; end if;
  if reservation_row.status not in ('confirmed','completed') then
    raise exception 'Only confirmed reservations can be finalized.';
  end if;

  select id into log_id from public.flight_logs where reservation_id = p_reservation_id for update;
  if found and exists (select 1 from public.flight_logs where id = log_id and status = 'approved') then
    raise exception 'This flight has already been finalized.';
  end if;

  if log_id is null then
    insert into public.flight_logs (
      reservation_id, renter_id, aircraft_id, actual_aircraft_hours, returned_to_base,
      admin_notes, status, submitted_at, updated_at
    ) values (
      reservation_row.id, reservation_row.renter_id, reservation_row.aircraft_id,
      p_actual_aircraft_hours, true, nullif(trim(p_admin_notes), ''), 'submitted', now(), now()
    ) returning id into log_id;
  else
    update public.flight_logs
    set actual_aircraft_hours = p_actual_aircraft_hours,
        admin_notes = nullif(trim(p_admin_notes), ''),
        updated_at = now()
    where id = log_id;
  end if;

  -- Serialize balance use per renter so two flight closeouts cannot spend the same hours.
  perform pg_advisory_xact_lock(hashtext(reservation_row.renter_id::text));
  hours_remaining := p_actual_aircraft_hours;

  -- Use blocks that were valid on the date of the flight, earliest-expiring first.
  for purchase_row in
    select * from public.block_hour_purchases
    where renter_id = reservation_row.renter_id
      and status <> 'void'
      and remaining_hours > 0
      and purchased_at <= reservation_row.ends_at
      and expires_at >= reservation_row.ends_at
    order by expires_at asc, purchased_at asc
    for update
  loop
    exit when hours_remaining <= 0;
    hours_to_use := least(hours_remaining, purchase_row.remaining_hours);

    update public.block_hour_purchases
    set remaining_hours = remaining_hours - hours_to_use,
        status = case
          when remaining_hours - hours_to_use <= 0 then 'exhausted'
          when expires_at <= now() then 'expired'
          else 'active'
        end,
        updated_at = now()
    where id = purchase_row.id;

    insert into public.hour_ledger (
      renter_id, block_purchase_id, reservation_id, entry_type, hours_delta, note, created_by
    ) values (
      reservation_row.renter_id, purchase_row.id, reservation_row.id, 'flight', -hours_to_use,
      'Applied to flight on ' || to_char(reservation_row.starts_at at time zone 'America/New_York', 'YYYY-MM-DD'),
      (select auth.uid())
    );

    v_applied_hours := v_applied_hours + hours_to_use;
    hours_remaining := hours_remaining - hours_to_use;
  end loop;

  v_payg_hours := greatest(hours_remaining, 0);
  charge_cents := round(v_payg_hours * 18000)::integer;

  if charge_cents > 0 then
    insert into public.payments (
      renter_id, reservation_id, kind, status, amount_cents, description, created_by
    ) values (
      reservation_row.renter_id, reservation_row.id, 'flight_charge', 'pending', charge_cents,
      trim(to_char(v_payg_hours, 'FM999990.0')) || ' pay-as-you-go flight hours @ $180/hr', (select auth.uid())
    );
  end if;

  update public.flight_logs
  set actual_aircraft_hours = p_actual_aircraft_hours,
      block_hours_applied = v_applied_hours,
      payg_hours = v_payg_hours,
      admin_notes = nullif(trim(p_admin_notes), ''),
      status = 'approved',
      reviewed_at = now(),
      reviewed_by = (select auth.uid()),
      updated_at = now()
  where id = log_id;

  update public.reservations
  set actual_aircraft_hours = p_actual_aircraft_hours,
      status = 'completed',
      admin_notes = coalesce(nullif(trim(p_admin_notes), ''), admin_notes),
      updated_at = now()
  where id = reservation_row.id;

  -- Refresh statuses for any other blocks that have now expired.
  update public.block_hour_purchases
  set status = 'expired', updated_at = now()
  where renter_id = reservation_row.renter_id
    and status = 'active'
    and remaining_hours > 0
    and expires_at <= now();

  return log_id;
exception
  when unique_violation then
    raise exception 'A live flight charge already exists for this reservation.';
end;
$$;

create or replace function public.admin_set_flight_log_status(
  p_reservation_id uuid,
  p_status text,
  p_admin_notes text default null
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not (select private.is_admin()) then raise exception 'Administrator access required.'; end if;
  if p_status not in ('submitted','needs_review') then
    raise exception 'Use the flight-finalization action to approve a flight.';
  end if;
  update public.flight_logs
  set status = p_status,
      admin_notes = nullif(trim(p_admin_notes), ''),
      reviewed_at = case when p_status = 'needs_review' then now() else reviewed_at end,
      reviewed_by = case when p_status = 'needs_review' then (select auth.uid()) else reviewed_by end,
      updated_at = now()
  where reservation_id = p_reservation_id and status <> 'approved';
  if not found then raise exception 'Open flight log not found.'; end if;
end;
$$;

create or replace function public.admin_set_squawk_status(
  p_squawk_id uuid,
  p_status text,
  p_admin_notes text default null
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not (select private.is_admin()) then raise exception 'Administrator access required.'; end if;
  if p_status not in ('open','in_progress','deferred','resolved') then raise exception 'Invalid squawk status.'; end if;
  update public.aircraft_squawks
  set status = p_status,
      admin_notes = nullif(trim(p_admin_notes), ''),
      resolved_at = case when p_status = 'resolved' then now() else null end,
      resolved_by = case when p_status = 'resolved' then (select auth.uid()) else null end,
      updated_at = now()
  where id = p_squawk_id;
  if not found then raise exception 'Squawk not found.'; end if;
end;
$$;

create or replace function public.admin_create_maintenance_record(
  p_aircraft_id uuid,
  p_title text,
  p_maintenance_type text,
  p_scheduled_for date default null,
  p_notes text default null,
  p_squawk_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  result_id uuid;
begin
  if not (select private.is_admin()) then raise exception 'Administrator access required.'; end if;
  if nullif(trim(p_title), '') is null then raise exception 'Maintenance title is required.'; end if;
  if p_maintenance_type not in ('inspection','repair','preventive','service','other') then raise exception 'Invalid maintenance type.'; end if;
  if p_squawk_id is not null and not exists (select 1 from public.aircraft_squawks where id = p_squawk_id and aircraft_id = p_aircraft_id) then
    raise exception 'Linked squawk not found.';
  end if;
  insert into public.maintenance_records (
    aircraft_id, squawk_id, title, maintenance_type, status, scheduled_for, notes, created_by
  ) values (
    p_aircraft_id, p_squawk_id, trim(p_title), p_maintenance_type, 'scheduled', p_scheduled_for,
    nullif(trim(p_notes), ''), (select auth.uid())
  ) returning id into result_id;
  if p_squawk_id is not null then
    update public.aircraft_squawks set status = 'in_progress', updated_at = now()
    where id = p_squawk_id and status = 'open';
  end if;
  return result_id;
end;
$$;

create or replace function public.admin_set_maintenance_status(
  p_maintenance_id uuid,
  p_status text,
  p_hobbs numeric default null,
  p_tach numeric default null,
  p_notes text default null
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  linked_squawk uuid;
begin
  if not (select private.is_admin()) then raise exception 'Administrator access required.'; end if;
  if p_status not in ('scheduled','in_progress','completed','cancelled') then raise exception 'Invalid maintenance status.'; end if;
  update public.maintenance_records
  set status = p_status,
      hobbs_at_completion = case when p_status = 'completed' then p_hobbs else hobbs_at_completion end,
      tach_at_completion = case when p_status = 'completed' then p_tach else tach_at_completion end,
      completed_at = case when p_status = 'completed' then now() else null end,
      notes = coalesce(nullif(trim(p_notes), ''), notes),
      updated_at = now()
  where id = p_maintenance_id
  returning squawk_id into linked_squawk;
  if not found then raise exception 'Maintenance record not found.'; end if;

  if p_status = 'completed' and linked_squawk is not null then
    update public.aircraft_squawks
    set status = 'resolved', resolved_at = now(), resolved_by = (select auth.uid()), updated_at = now()
    where id = linked_squawk;
  elsif p_status = 'cancelled' and linked_squawk is not null then
    update public.aircraft_squawks
    set status = 'open', resolved_at = null, resolved_by = null, updated_at = now()
    where id = linked_squawk and status = 'in_progress';
  end if;
end;
$$;

-- Existing reservation status control now reserves "completed" for the flight closeout workflow.
create or replace function public.admin_set_reservation_status(
  p_reservation_id uuid,
  p_status text,
  p_admin_notes text default null,
  p_actual_aircraft_hours numeric default null
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not (select private.is_admin()) then raise exception 'Administrator access required.'; end if;
  if p_status not in ('pending','confirmed','cancelled','rejected') then
    if p_status = 'completed' then raise exception 'Finalize the post-flight record to complete a flight.'; end if;
    raise exception 'Invalid reservation status.';
  end if;
  update public.reservations
  set status = p_status,
      admin_notes = nullif(trim(p_admin_notes), ''),
      updated_at = now()
  where id = p_reservation_id;
  if not found then raise exception 'Reservation not found.'; end if;
end;
$$;

-- Updated-at triggers for Phase 2 tables.
drop trigger if exists payments_set_updated_at on public.payments;
create trigger payments_set_updated_at before update on public.payments
for each row execute function public.set_updated_at();
drop trigger if exists block_purchases_set_updated_at on public.block_hour_purchases;
create trigger block_purchases_set_updated_at before update on public.block_hour_purchases
for each row execute function public.set_updated_at();
drop trigger if exists flight_logs_set_updated_at on public.flight_logs;
create trigger flight_logs_set_updated_at before update on public.flight_logs
for each row execute function public.set_updated_at();
drop trigger if exists squawks_set_updated_at on public.aircraft_squawks;
create trigger squawks_set_updated_at before update on public.aircraft_squawks
for each row execute function public.set_updated_at();
drop trigger if exists maintenance_set_updated_at on public.maintenance_records;
create trigger maintenance_set_updated_at before update on public.maintenance_records
for each row execute function public.set_updated_at();

-- API privileges: reads are RLS-protected, all writes go through RPCs.
revoke all on function public.handle_new_user() from public;
revoke all on public.payments, public.block_hour_purchases, public.hour_ledger, public.flight_logs, public.aircraft_squawks, public.maintenance_records from anon, authenticated;
grant select on public.payments, public.block_hour_purchases, public.hour_ledger, public.flight_logs, public.aircraft_squawks, public.maintenance_records to authenticated;

revoke all on function public.submit_postflight_report(uuid,numeric,numeric,numeric,numeric,numeric,numeric,boolean,text) from public;
revoke all on function public.submit_squawk(uuid,uuid,text,text,text) from public;
revoke all on function public.admin_record_block_purchase(uuid,numeric,text,text,text) from public;
revoke all on function public.admin_set_payment_status(uuid,text,text,text) from public;
revoke all on function public.admin_finalize_flight(uuid,numeric,text) from public;
revoke all on function public.admin_set_flight_log_status(uuid,text,text) from public;
revoke all on function public.admin_set_squawk_status(uuid,text,text) from public;
revoke all on function public.admin_create_maintenance_record(uuid,text,text,date,text,uuid) from public;
revoke all on function public.admin_set_maintenance_status(uuid,text,numeric,numeric,text) from public;
revoke all on function public.admin_set_reservation_status(uuid,text,text,numeric) from public;

grant execute on function public.submit_postflight_report(uuid,numeric,numeric,numeric,numeric,numeric,numeric,boolean,text) to authenticated;
grant execute on function public.submit_squawk(uuid,uuid,text,text,text) to authenticated;
grant execute on function public.admin_record_block_purchase(uuid,numeric,text,text,text) to authenticated;
grant execute on function public.admin_set_payment_status(uuid,text,text,text) to authenticated;
grant execute on function public.admin_finalize_flight(uuid,numeric,text) to authenticated;
grant execute on function public.admin_set_flight_log_status(uuid,text,text) to authenticated;
grant execute on function public.admin_set_squawk_status(uuid,text,text) to authenticated;
grant execute on function public.admin_create_maintenance_record(uuid,text,text,date,text,uuid) to authenticated;
grant execute on function public.admin_set_maintenance_status(uuid,text,numeric,numeric,text) to authenticated;
grant execute on function public.admin_set_reservation_status(uuid,text,text,numeric) to authenticated;

commit;
