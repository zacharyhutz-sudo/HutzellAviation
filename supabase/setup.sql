-- Hutzell Aviation calendar + renter accounts
-- Run this entire script once in Supabase Dashboard -> SQL Editor.

begin;

create extension if not exists pgcrypto;
create extension if not exists btree_gist;
create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null,
  full_name text,
  phone text,
  role text not null default 'renter' check (role in ('renter','admin')),
  approval_status text not null default 'incomplete' check (approval_status in ('incomplete','pending','approved','suspended','rejected')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.aircraft (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  model text,
  registration_number text,
  home_airport text,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.renter_applications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references public.profiles(id) on delete cascade,
  legal_first_name text not null,
  legal_last_name text not null,
  phone text not null,
  address text,
  city text,
  state text,
  certificate text not null,
  rental_purpose text not null,
  total_time numeric(10,1),
  cherokee_time numeric(10,1),
  flight_review_date date,
  medical_expiration date,
  ratings text,
  status text not null default 'pending' check (status in ('draft','pending','needs_information','approved','rejected','suspended')),
  admin_notes text,
  submitted_at timestamptz not null default now(),
  reviewed_at timestamptz,
  reviewed_by uuid references public.profiles(id),
  updated_at timestamptz not null default now()
);

create table if not exists public.reservations (
  id uuid primary key default gen_random_uuid(),
  aircraft_id uuid not null references public.aircraft(id),
  renter_id uuid not null references public.profiles(id),
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  estimated_flight_hours numeric(6,1),
  actual_aircraft_hours numeric(6,1),
  status text not null default 'pending' check (status in ('pending','confirmed','completed','cancelled','rejected')),
  renter_notes text,
  admin_notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  booking_window tstzrange generated always as (tstzrange(starts_at, ends_at, '[)')) stored,
  constraint reservation_end_after_start check (ends_at > starts_at)
);

create table if not exists public.aircraft_blocks (
  id uuid primary key default gen_random_uuid(),
  aircraft_id uuid not null references public.aircraft(id),
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  block_type text not null check (block_type in ('maintenance','owner_use','inspection','unavailable','other')),
  notes text,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  block_window tstzrange generated always as (tstzrange(starts_at, ends_at, '[)')) stored,
  constraint block_end_after_start check (ends_at > starts_at)
);

create index if not exists profiles_email_idx on public.profiles(lower(email));
create index if not exists applications_user_idx on public.renter_applications(user_id);
create index if not exists reservations_renter_idx on public.reservations(renter_id);
create index if not exists reservations_aircraft_start_idx on public.reservations(aircraft_id, starts_at);
create index if not exists blocks_aircraft_start_idx on public.aircraft_blocks(aircraft_id, starts_at);

-- Prevent two active reservations from occupying the same aircraft time.
do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'reservations_no_active_overlap' and conrelid = 'public.reservations'::regclass
  ) then
    alter table public.reservations
      add constraint reservations_no_active_overlap
      exclude using gist (
        aircraft_id with =,
        booking_window with &&
      ) where (status in ('pending','confirmed'));
  end if;
end $$;

-- Prevent overlapping owner/maintenance blocks.
do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'aircraft_blocks_no_overlap' and conrelid = 'public.aircraft_blocks'::regclass
  ) then
    alter table public.aircraft_blocks
      add constraint aircraft_blocks_no_overlap
      exclude using gist (
        aircraft_id with =,
        block_window with &&
      );
  end if;
end $$;

insert into public.aircraft (id, name, model, registration_number, home_airport, active)
values ('00000000-0000-0000-0000-000000000001', 'Hutzell Aviation Piper Cherokee', 'Piper Cherokee', null, 'Athens, Georgia', true)
on conflict (id) do update set
  name = excluded.name,
  model = excluded.model,
  active = true,
  updated_at = now();

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  insert into public.profiles (id, email, full_name, phone, role, approval_status)
  values (
    new.id,
    lower(coalesce(new.email, '')),
    nullif(new.raw_user_meta_data ->> 'full_name', ''),
    nullif(new.raw_user_meta_data ->> 'phone', ''),
    case when lower(coalesce(new.email, '')) in ('zacharyhutz@gmail.com', 'tylerhutzell4@gmail.com') and new.email_confirmed_at is not null then 'admin' else 'renter' end,
    case when lower(coalesce(new.email, '')) in ('zacharyhutz@gmail.com', 'tylerhutzell4@gmail.com') and new.email_confirmed_at is not null then 'approved' else 'incomplete' end
  )
  on conflict (id) do update set
    email = excluded.email,
    full_name = coalesce(public.profiles.full_name, excluded.full_name),
    phone = coalesce(public.profiles.phone, excluded.phone),
    role = case when excluded.email in ('zacharyhutz@gmail.com', 'tylerhutzell4@gmail.com') and new.email_confirmed_at is not null then 'admin' else public.profiles.role end,
    approval_status = case when excluded.email in ('zacharyhutz@gmail.com', 'tylerhutzell4@gmail.com') and new.email_confirmed_at is not null then 'approved' else public.profiles.approval_status end,
    updated_at = now();
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert or update of email, raw_user_meta_data, email_confirmed_at on auth.users
for each row execute function public.handle_new_user();

-- Backfill users that existed before this script was installed.
insert into public.profiles (id, email, full_name, phone, role, approval_status)
select
  u.id,
  lower(coalesce(u.email, '')),
  nullif(u.raw_user_meta_data ->> 'full_name', ''),
  nullif(u.raw_user_meta_data ->> 'phone', ''),
  case when lower(coalesce(u.email, '')) in ('zacharyhutz@gmail.com', 'tylerhutzell4@gmail.com') and u.email_confirmed_at is not null then 'admin' else 'renter' end,
  case when lower(coalesce(u.email, '')) in ('zacharyhutz@gmail.com', 'tylerhutzell4@gmail.com') and u.email_confirmed_at is not null then 'approved' else 'incomplete' end
from auth.users u
on conflict (id) do update set
  email = excluded.email,
  role = case when excluded.email in ('zacharyhutz@gmail.com', 'tylerhutzell4@gmail.com') and exists (select 1 from auth.users au where au.id = excluded.id and au.email_confirmed_at is not null) then 'admin' else public.profiles.role end,
  approval_status = case when excluded.email in ('zacharyhutz@gmail.com', 'tylerhutzell4@gmail.com') and exists (select 1 from auth.users au where au.id = excluded.id and au.email_confirmed_at is not null) then 'approved' else public.profiles.approval_status end,
  updated_at = now();

create or replace function private.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1 from public.profiles
    where id = (select auth.uid()) and role = 'admin'
  );
$$;

create or replace function private.is_approved_renter()
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1 from public.profiles
    where id = (select auth.uid())
      and (approval_status = 'approved' or role = 'admin')
  );
$$;

-- RLS
alter table public.profiles enable row level security;
alter table public.aircraft enable row level security;
alter table public.renter_applications enable row level security;
alter table public.reservations enable row level security;
alter table public.aircraft_blocks enable row level security;

-- Remove old policies when re-running this file.
drop policy if exists "Public can view active aircraft" on public.aircraft;
drop policy if exists "Users can view own profile" on public.profiles;
drop policy if exists "Admins can view all profiles" on public.profiles;
drop policy if exists "Users can view own application" on public.renter_applications;
drop policy if exists "Admins can view all applications" on public.renter_applications;
drop policy if exists "Users can view own reservations" on public.reservations;
drop policy if exists "Admins can view all reservations" on public.reservations;
drop policy if exists "Admins can view aircraft blocks" on public.aircraft_blocks;

create policy "Public can view active aircraft"
on public.aircraft for select
to anon, authenticated
using (active = true);

create policy "Users can view own profile"
on public.profiles for select
to authenticated
using (id = (select auth.uid()));

create policy "Admins can view all profiles"
on public.profiles for select
to authenticated
using ((select private.is_admin()));

create policy "Users can view own application"
on public.renter_applications for select
to authenticated
using (user_id = (select auth.uid()));

create policy "Admins can view all applications"
on public.renter_applications for select
to authenticated
using ((select private.is_admin()));

create policy "Users can view own reservations"
on public.reservations for select
to authenticated
using (renter_id = (select auth.uid()));

create policy "Admins can view all reservations"
on public.reservations for select
to authenticated
using ((select private.is_admin()));

create policy "Admins can view aircraft blocks"
on public.aircraft_blocks for select
to authenticated
using ((select private.is_admin()));

-- Public, privacy-safe calendar feed. No renter identity or notes are exposed.
create or replace function public.get_public_calendar_events(
  p_start timestamptz,
  p_end timestamptz
)
returns table (
  event_id uuid,
  event_kind text,
  starts_at timestamptz,
  ends_at timestamptz,
  status text,
  label text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if p_start is null or p_end is null or p_end <= p_start then
    raise exception 'A valid calendar range is required.';
  end if;
  if p_end - p_start > interval '180 days' then
    raise exception 'Calendar range cannot exceed 180 days.';
  end if;

  return query
  select r.id, 'reservation'::text, r.starts_at, r.ends_at, r.status, 'Reserved'::text
  from public.reservations r
  where r.status in ('pending','confirmed')
    and r.starts_at < p_end
    and r.ends_at > p_start
  union all
  select b.id, 'block'::text, b.starts_at, b.ends_at, b.block_type,
    case b.block_type
      when 'maintenance' then 'Maintenance'
      when 'inspection' then 'Inspection'
      when 'owner_use' then 'Unavailable'
      else 'Unavailable'
    end
  from public.aircraft_blocks b
  where b.starts_at < p_end
    and b.ends_at > p_start
  order by 3;
end;
$$;

create or replace function public.update_my_profile(
  p_full_name text,
  p_phone text
)
returns public.profiles
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  result public.profiles;
begin
  if (select auth.uid()) is null then
    raise exception 'You must be signed in.';
  end if;
  update public.profiles
  set full_name = nullif(trim(p_full_name), ''),
      phone = nullif(trim(p_phone), ''),
      updated_at = now()
  where id = (select auth.uid())
  returning * into result;
  return result;
end;
$$;

create or replace function public.submit_renter_application(
  p_legal_first_name text,
  p_legal_last_name text,
  p_phone text,
  p_address text,
  p_city text,
  p_state text,
  p_certificate text,
  p_rental_purpose text,
  p_total_time numeric,
  p_cherokee_time numeric,
  p_flight_review_date date,
  p_medical_expiration date,
  p_ratings text
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  user_id uuid := (select auth.uid());
  application_id uuid;
begin
  if user_id is null then raise exception 'You must be signed in.'; end if;
  if nullif(trim(p_legal_first_name), '') is null or nullif(trim(p_legal_last_name), '') is null then
    raise exception 'Legal first and last name are required.';
  end if;
  if nullif(trim(p_phone), '') is null then raise exception 'Phone number is required.'; end if;
  if nullif(trim(p_certificate), '') is null or nullif(trim(p_rental_purpose), '') is null then
    raise exception 'Certificate and rental purpose are required.';
  end if;
  if coalesce(p_total_time, 0) < 0 or coalesce(p_cherokee_time, 0) < 0 then
    raise exception 'Flight time cannot be negative.';
  end if;

  insert into public.renter_applications (
    user_id, legal_first_name, legal_last_name, phone, address, city, state,
    certificate, rental_purpose, total_time, cherokee_time,
    flight_review_date, medical_expiration, ratings, status, submitted_at, updated_at
  ) values (
    user_id, trim(p_legal_first_name), trim(p_legal_last_name), trim(p_phone),
    nullif(trim(p_address), ''), nullif(trim(p_city), ''), nullif(trim(p_state), ''),
    trim(p_certificate), trim(p_rental_purpose), p_total_time, p_cherokee_time,
    p_flight_review_date, p_medical_expiration, nullif(trim(p_ratings), ''),
    'pending', now(), now()
  )
  on conflict (user_id) do update set
    legal_first_name = excluded.legal_first_name,
    legal_last_name = excluded.legal_last_name,
    phone = excluded.phone,
    address = excluded.address,
    city = excluded.city,
    state = excluded.state,
    certificate = excluded.certificate,
    rental_purpose = excluded.rental_purpose,
    total_time = excluded.total_time,
    cherokee_time = excluded.cherokee_time,
    flight_review_date = excluded.flight_review_date,
    medical_expiration = excluded.medical_expiration,
    ratings = excluded.ratings,
    status = case when public.renter_applications.status = 'approved' then 'approved' else 'pending' end,
    submitted_at = now(),
    updated_at = now()
  returning id into application_id;

  update public.profiles
  set full_name = trim(p_legal_first_name) || ' ' || trim(p_legal_last_name),
      phone = trim(p_phone),
      approval_status = case when approval_status = 'approved' then 'approved' else 'pending' end,
      updated_at = now()
  where id = user_id;

  return application_id;
end;
$$;

create or replace function public.create_reservation(
  p_aircraft_id uuid,
  p_starts_at timestamptz,
  p_ends_at timestamptz,
  p_estimated_flight_hours numeric default null,
  p_notes text default null
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  user_id uuid := (select auth.uid());
  reservation_id uuid;
begin
  if user_id is null then raise exception 'You must be signed in.'; end if;
  if not (select private.is_approved_renter()) then
    raise exception 'Your renter account must be approved before booking.';
  end if;
  if p_starts_at is null or p_ends_at is null or p_ends_at <= p_starts_at then
    raise exception 'A valid departure and return time are required.';
  end if;
  if p_starts_at < now() + interval '15 minutes' then
    raise exception 'Reservations must begin at least 15 minutes in the future.';
  end if;
  if p_ends_at - p_starts_at > interval '7 days' then
    raise exception 'A single reservation cannot exceed 7 days.';
  end if;
  if p_estimated_flight_hours is not null and (p_estimated_flight_hours < 0.1 or p_estimated_flight_hours > 168) then
    raise exception 'Estimated flight time must be between 0.1 and 168 hours.';
  end if;
  if length(coalesce(p_notes, '')) > 1000 then
    raise exception 'Reservation notes cannot exceed 1000 characters.';
  end if;
  if not exists (select 1 from public.aircraft where id = p_aircraft_id and active) then
    raise exception 'Aircraft is not currently available for booking.';
  end if;

  -- Serialize reservation and block creation for this aircraft.
  perform pg_advisory_xact_lock(hashtext(p_aircraft_id::text));

  if exists (
    select 1 from public.aircraft_blocks b
    where b.aircraft_id = p_aircraft_id
      and b.block_window && tstzrange(p_starts_at, p_ends_at, '[)')
  ) then
    raise exception 'This time overlaps an aircraft-unavailable period.';
  end if;

  insert into public.reservations (
    aircraft_id, renter_id, starts_at, ends_at,
    estimated_flight_hours, status, renter_notes
  ) values (
    p_aircraft_id, user_id, p_starts_at, p_ends_at,
    p_estimated_flight_hours, 'pending', nullif(trim(p_notes), '')
  ) returning id into reservation_id;

  return reservation_id;
exception
  when exclusion_violation then
    raise exception 'That time was just reserved by someone else. Please choose another window.';
end;
$$;

create or replace function public.cancel_my_reservation(p_reservation_id uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if (select auth.uid()) is null then raise exception 'You must be signed in.'; end if;
  update public.reservations
  set status = 'cancelled', updated_at = now()
  where id = p_reservation_id
    and renter_id = (select auth.uid())
    and status in ('pending','confirmed')
    and starts_at > now();
  if not found then raise exception 'Reservation cannot be cancelled.'; end if;
end;
$$;

create or replace function public.admin_set_application_status(
  p_user_id uuid,
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
  if p_status not in ('pending','needs_information','approved','rejected','suspended') then
    raise exception 'Invalid application status.';
  end if;

  update public.renter_applications
  set status = p_status,
      admin_notes = nullif(trim(p_admin_notes), ''),
      reviewed_at = now(),
      reviewed_by = (select auth.uid()),
      updated_at = now()
  where user_id = p_user_id;
  if not found then raise exception 'Application not found.'; end if;

  update public.profiles
  set approval_status = case p_status
      when 'approved' then 'approved'
      when 'rejected' then 'rejected'
      when 'suspended' then 'suspended'
      else 'pending'
    end,
    updated_at = now()
  where id = p_user_id;
end;
$$;

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
  if p_status not in ('pending','confirmed','completed','cancelled','rejected') then
    raise exception 'Invalid reservation status.';
  end if;
  if p_actual_aircraft_hours is not null and p_actual_aircraft_hours < 0 then
    raise exception 'Actual aircraft hours cannot be negative.';
  end if;

  update public.reservations
  set status = p_status,
      admin_notes = nullif(trim(p_admin_notes), ''),
      actual_aircraft_hours = coalesce(p_actual_aircraft_hours, actual_aircraft_hours),
      updated_at = now()
  where id = p_reservation_id;
  if not found then raise exception 'Reservation not found.'; end if;
end;
$$;

create or replace function public.admin_create_aircraft_block(
  p_aircraft_id uuid,
  p_starts_at timestamptz,
  p_ends_at timestamptz,
  p_block_type text,
  p_notes text default null
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  block_id uuid;
begin
  if not (select private.is_admin()) then raise exception 'Administrator access required.'; end if;
  if p_block_type not in ('maintenance','owner_use','inspection','unavailable','other') then
    raise exception 'Invalid block type.';
  end if;
  if p_starts_at is null or p_ends_at is null or p_ends_at <= p_starts_at then
    raise exception 'A valid start and end time are required.';
  end if;

  perform pg_advisory_xact_lock(hashtext(p_aircraft_id::text));

  if exists (
    select 1 from public.reservations r
    where r.aircraft_id = p_aircraft_id
      and r.status in ('pending','confirmed')
      and r.booking_window && tstzrange(p_starts_at, p_ends_at, '[)')
  ) then
    raise exception 'This block overlaps an active reservation.';
  end if;

  insert into public.aircraft_blocks (
    aircraft_id, starts_at, ends_at, block_type, notes, created_by
  ) values (
    p_aircraft_id, p_starts_at, p_ends_at, p_block_type,
    nullif(trim(p_notes), ''), (select auth.uid())
  ) returning id into block_id;
  return block_id;
exception
  when exclusion_violation then
    raise exception 'This time overlaps another aircraft block.';
end;
$$;

create or replace function public.admin_delete_aircraft_block(p_block_id uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not (select private.is_admin()) then raise exception 'Administrator access required.'; end if;
  delete from public.aircraft_blocks where id = p_block_id;
  if not found then raise exception 'Aircraft block not found.'; end if;
end;
$$;

-- Updated-at triggers.
drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at before update on public.profiles
for each row execute function public.set_updated_at();
drop trigger if exists aircraft_set_updated_at on public.aircraft;
create trigger aircraft_set_updated_at before update on public.aircraft
for each row execute function public.set_updated_at();
drop trigger if exists applications_set_updated_at on public.renter_applications;
create trigger applications_set_updated_at before update on public.renter_applications
for each row execute function public.set_updated_at();
drop trigger if exists reservations_set_updated_at on public.reservations;
create trigger reservations_set_updated_at before update on public.reservations
for each row execute function public.set_updated_at();
drop trigger if exists blocks_set_updated_at on public.aircraft_blocks;
create trigger blocks_set_updated_at before update on public.aircraft_blocks
for each row execute function public.set_updated_at();

-- Explicit API privileges.
revoke all on public.profiles, public.renter_applications, public.reservations, public.aircraft_blocks from anon, authenticated;
revoke all on public.aircraft from anon, authenticated;
grant select on public.aircraft to anon, authenticated;
grant select on public.profiles, public.renter_applications, public.reservations, public.aircraft_blocks to authenticated;

revoke all on function public.handle_new_user() from public;
revoke all on function public.set_updated_at() from public;

revoke all on function public.get_public_calendar_events(timestamptz,timestamptz) from public;
revoke all on function public.update_my_profile(text,text) from public;
revoke all on function public.submit_renter_application(text,text,text,text,text,text,text,text,numeric,numeric,date,date,text) from public;
revoke all on function public.create_reservation(uuid,timestamptz,timestamptz,numeric,text) from public;
revoke all on function public.cancel_my_reservation(uuid) from public;
revoke all on function public.admin_set_application_status(uuid,text,text) from public;
revoke all on function public.admin_set_reservation_status(uuid,text,text,numeric) from public;
revoke all on function public.admin_create_aircraft_block(uuid,timestamptz,timestamptz,text,text) from public;
revoke all on function public.admin_delete_aircraft_block(uuid) from public;

grant execute on function public.get_public_calendar_events(timestamptz,timestamptz) to anon, authenticated;
grant execute on function public.update_my_profile(text,text) to authenticated;
grant execute on function public.submit_renter_application(text,text,text,text,text,text,text,text,numeric,numeric,date,date,text) to authenticated;
grant execute on function public.create_reservation(uuid,timestamptz,timestamptz,numeric,text) to authenticated;
grant execute on function public.cancel_my_reservation(uuid) to authenticated;
grant execute on function public.admin_set_application_status(uuid,text,text) to authenticated;
grant execute on function public.admin_set_reservation_status(uuid,text,text,numeric) to authenticated;
grant execute on function public.admin_create_aircraft_block(uuid,timestamptz,timestamptz,text,text) to authenticated;
grant execute on function public.admin_delete_aircraft_block(uuid) to authenticated;

commit;
