-- Hutzell Aviation - admin dashboard cleanup (November 2026)
-- Run ONCE in the Supabase SQL Editor BEFORE deploying the matching website patch.
-- Safe to rerun. Existing flight logs, billing, and renter accounts are preserved.
BEGIN;

ALTER TABLE public.renter_applications
  ADD COLUMN IF NOT EXISTS archived_at timestamptz,
  ADD COLUMN IF NOT EXISTS archived_by uuid REFERENCES public.profiles(id);
ALTER TABLE public.reservations
  ADD COLUMN IF NOT EXISTS archived_at timestamptz,
  ADD COLUMN IF NOT EXISTS archived_by uuid REFERENCES public.profiles(id);

CREATE INDEX IF NOT EXISTS renter_applications_admin_recent_idx
  ON public.renter_applications(submitted_at DESC) WHERE archived_at IS NULL;
CREATE INDEX IF NOT EXISTS reservations_admin_recent_idx
  ON public.reservations(created_at DESC) WHERE archived_at IS NULL;

-- Replace the existing submission function so resubmitting an archived application
-- makes it visible to administrators and requires a new approval decision.
CREATE OR REPLACE FUNCTION public.submit_renter_application(
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
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user_id uuid := (SELECT auth.uid());
  v_application_id uuid;
  v_archived_at timestamptz;
BEGIN
  IF v_user_id IS NULL THEN RAISE EXCEPTION 'You must be signed in.'; END IF;
  IF nullif(trim(p_legal_first_name), '') IS NULL OR nullif(trim(p_legal_last_name), '') IS NULL THEN
    RAISE EXCEPTION 'Legal first and last name are required.';
  END IF;
  IF nullif(trim(p_phone), '') IS NULL THEN RAISE EXCEPTION 'Phone number is required.'; END IF;
  IF nullif(trim(p_certificate), '') IS NULL OR nullif(trim(p_rental_purpose), '') IS NULL THEN
    RAISE EXCEPTION 'Certificate and rental purpose are required.';
  END IF;
  IF coalesce(p_total_time, 0) < 0 OR coalesce(p_cherokee_time, 0) < 0 THEN
    RAISE EXCEPTION 'Flight time cannot be negative.';
  END IF;

  SELECT archived_at INTO v_archived_at
  FROM public.renter_applications WHERE user_id = v_user_id FOR UPDATE;

  INSERT INTO public.renter_applications (
    user_id, legal_first_name, legal_last_name, phone, address, city, state,
    certificate, rental_purpose, total_time, cherokee_time, flight_review_date,
    medical_expiration, ratings, status, submitted_at, updated_at
  ) VALUES (
    v_user_id, trim(p_legal_first_name), trim(p_legal_last_name), trim(p_phone),
    nullif(trim(p_address), ''), nullif(trim(p_city), ''), nullif(trim(p_state), ''),
    trim(p_certificate), trim(p_rental_purpose), p_total_time, p_cherokee_time,
    p_flight_review_date, p_medical_expiration, nullif(trim(p_ratings), ''),
    'pending', now(), now()
  )
  ON CONFLICT (user_id) DO UPDATE SET
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
    status = CASE
      WHEN public.renter_applications.archived_at IS NOT NULL THEN 'pending'
      WHEN public.renter_applications.status = 'approved' THEN 'approved'
      ELSE 'pending'
    END,
    archived_at = NULL,
    archived_by = NULL,
    submitted_at = now(),
    updated_at = now()
  RETURNING id INTO v_application_id;

  UPDATE public.profiles
  SET full_name = trim(p_legal_first_name) || ' ' || trim(p_legal_last_name),
      phone = trim(p_phone),
      approval_status = CASE
        WHEN v_archived_at IS NOT NULL THEN 'pending'
        WHEN approval_status = 'approved' THEN 'approved'
        ELSE 'pending'
      END,
      updated_at = now()
  WHERE id = v_user_id;

  RETURN v_application_id;
END;
$$;

-- Permanently remove only a non-approved application with no history.
-- For approved applications or applications with history, archive without changing
-- the renter's approval status or account. Returns 'deleted' or 'archived'.
CREATE OR REPLACE FUNCTION public.admin_remove_application(p_user_id uuid)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_application public.renter_applications%ROWTYPE;
  v_has_history boolean;
BEGIN
  IF NOT (SELECT private.is_admin()) THEN RAISE EXCEPTION 'Administrator access required.'; END IF;
  SELECT * INTO v_application FROM public.renter_applications
  WHERE user_id = p_user_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Application not found.'; END IF;
  IF v_application.archived_at IS NOT NULL THEN RAISE EXCEPTION 'Application is already archived.'; END IF;

  SELECT
    (v_application.status = 'approved')
    OR EXISTS (SELECT 1 FROM public.profiles WHERE id = p_user_id AND approval_status = 'approved')
    OR EXISTS (SELECT 1 FROM public.reservations WHERE renter_id = p_user_id)
    OR EXISTS (SELECT 1 FROM public.payments WHERE renter_id = p_user_id)
    OR EXISTS (SELECT 1 FROM public.block_hour_purchases WHERE renter_id = p_user_id)
    OR EXISTS (SELECT 1 FROM public.hour_ledger WHERE renter_id = p_user_id)
    OR EXISTS (SELECT 1 FROM public.flight_logs WHERE renter_id = p_user_id)
    OR EXISTS (SELECT 1 FROM public.aircraft_squawks WHERE reported_by = p_user_id)
  INTO v_has_history;

  IF v_has_history THEN
    UPDATE public.renter_applications
      SET archived_at = now(), archived_by = (SELECT auth.uid()), updated_at = now()
    WHERE id = v_application.id;
    RETURN 'archived';
  END IF;

  DELETE FROM public.renter_applications WHERE id = v_application.id;
  UPDATE public.profiles
    SET approval_status = 'incomplete', updated_at = now()
    WHERE id = p_user_id AND role = 'renter';
  RETURN 'deleted';
END;
$$;

-- Active confirmed reservations must be cancelled first. A reservation that
-- has a flight log, squawk, bill, ledger entry, or completed status is archived;
-- none of those linked records is deleted or detached.
CREATE OR REPLACE FUNCTION public.admin_remove_reservation(p_reservation_id uuid)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_reservation public.reservations%ROWTYPE;
  v_has_history boolean;
BEGIN
  IF NOT (SELECT private.is_admin()) THEN RAISE EXCEPTION 'Administrator access required.'; END IF;
  SELECT * INTO v_reservation FROM public.reservations
  WHERE id = p_reservation_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Reservation not found.'; END IF;
  IF v_reservation.archived_at IS NOT NULL THEN RAISE EXCEPTION 'Reservation is already archived.'; END IF;
  IF v_reservation.status = 'confirmed' THEN
    RAISE EXCEPTION 'Cancel this confirmed reservation before removing it.';
  END IF;

  SELECT v_reservation.status = 'completed'
    OR v_reservation.actual_aircraft_hours IS NOT NULL
    OR EXISTS (SELECT 1 FROM public.flight_logs WHERE reservation_id = p_reservation_id)
    OR EXISTS (SELECT 1 FROM public.payments WHERE reservation_id = p_reservation_id)
    OR EXISTS (SELECT 1 FROM public.hour_ledger WHERE reservation_id = p_reservation_id)
    OR EXISTS (SELECT 1 FROM public.aircraft_squawks WHERE reservation_id = p_reservation_id)
  INTO v_has_history;

  IF v_has_history THEN
    UPDATE public.reservations
      SET archived_at = now(), archived_by = (SELECT auth.uid()), updated_at = now()
    WHERE id = p_reservation_id;
    RETURN 'archived';
  END IF;

  DELETE FROM public.reservations WHERE id = p_reservation_id;
  RETURN 'deleted';
END;
$$;

-- Restore archived entries to the active admin lists without modifying linked
-- records or renter approval/flight status.
CREATE OR REPLACE FUNCTION public.admin_restore_application(p_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT (SELECT private.is_admin()) THEN RAISE EXCEPTION 'Administrator access required.'; END IF;
  UPDATE public.renter_applications
    SET archived_at = NULL, archived_by = NULL, updated_at = now()
  WHERE user_id = p_user_id AND archived_at IS NOT NULL;
  IF NOT FOUND THEN RAISE EXCEPTION 'Archived application not found.'; END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_restore_reservation(p_reservation_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT (SELECT private.is_admin()) THEN RAISE EXCEPTION 'Administrator access required.'; END IF;
  UPDATE public.reservations
    SET archived_at = NULL, archived_by = NULL, updated_at = now()
  WHERE id = p_reservation_id AND archived_at IS NOT NULL;
  IF NOT FOUND THEN RAISE EXCEPTION 'Archived reservation not found.'; END IF;
END;
$$;

-- No direct browser DELETE privileges; callers must pass the admin check.
REVOKE ALL ON FUNCTION public.admin_remove_application(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.admin_remove_reservation(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.admin_restore_application(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.admin_restore_reservation(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.admin_remove_application(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_remove_reservation(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_restore_application(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_restore_reservation(uuid) TO authenticated;

COMMIT;
