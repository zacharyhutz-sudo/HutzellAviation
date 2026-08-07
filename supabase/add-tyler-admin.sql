-- One-time patch for the existing Hutzell Aviation Supabase project.
-- Run this in Supabase Dashboard -> SQL Editor.
-- It adds Tyler's verified email to the admin allowlist and promotes an existing
-- confirmed Tyler account immediately, if one already exists.

begin;

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

-- If Tyler already has a confirmed account, promote it now.
update public.profiles p
set
  role = 'admin',
  approval_status = 'approved',
  updated_at = now()
from auth.users u
where p.id = u.id
  and lower(coalesce(u.email, '')) = 'tylerhutzell4@gmail.com'
  and u.email_confirmed_at is not null;

commit;
