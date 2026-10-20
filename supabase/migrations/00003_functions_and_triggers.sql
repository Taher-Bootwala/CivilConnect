-- CivilHand Database Functions, Triggers & Invariant Checks
-- Module: State Machine, Bayesian Rating, Double-Entry Assertion, Proximity Search & Cash Soft-Lock

-- 1. Double-Entry Balance Assertion Function
CREATE OR REPLACE FUNCTION public.verify_ledger_transaction_balance(p_tx_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
  v_total_debit BIGINT;
  v_total_credit BIGINT;
BEGIN
  SELECT COALESCE(SUM(debit_paise), 0), COALESCE(SUM(credit_paise), 0)
  INTO v_total_debit, v_total_credit
  FROM public.ledger_entries
  WHERE transaction_id = p_tx_id;

  IF v_total_debit <> v_total_credit THEN
    RAISE EXCEPTION 'Ledger imbalance in transaction %: Debits (%) != Credits (%)',
      p_tx_id, v_total_debit, v_total_credit;
  END IF;

  RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- 2. Bayesian Rating Calculation Trigger
CREATE OR REPLACE FUNCTION public.update_labor_bayesian_rating()
RETURNS TRIGGER AS $$
DECLARE
  v_m CONSTANT NUMERIC := 5.0; -- Minimum review count threshold
  v_c CONSTANT NUMERIC := 4.5; -- Prior mean rating
  v_v NUMERIC;
  v_r NUMERIC;
  v_new_bayesian NUMERIC(3, 2);
BEGIN
  -- Aggregate ratings for this labor
  SELECT COUNT(*), AVG(rating_score)
  INTO v_v, v_r
  FROM public.ratings
  WHERE labor_id = NEW.labor_id;

  -- Bayesian Formula: (v / (v + m)) * R + (m / (v + m)) * C
  v_new_bayesian := ROUND(((v_v / (v_v + v_m)) * v_r + (v_m / (v_v + v_m)) * v_c)::numeric, 2);

  UPDATE public.labor_profiles
  SET
    rating_count = v_v::int,
    rating_avg = ROUND(v_r::numeric, 2),
    bayesian_rating = v_new_bayesian,
    updated_at = NOW()
  WHERE id = NEW.labor_id;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER trg_after_rating_insert
AFTER INSERT OR UPDATE ON public.ratings
FOR EACH ROW EXECUTE FUNCTION public.update_labor_bayesian_rating();

-- 3. Booking State Machine & Occupation Enforcement Trigger
CREATE OR REPLACE FUNCTION public.handle_booking_state_transition()
RETURNS TRIGGER AS $$
DECLARE
  v_has_other_active_job BOOLEAN;
BEGIN
  -- Validate permitted state transitions
  IF OLD.status IS NOT NULL AND OLD.status <> NEW.status THEN
    
    -- Disallow invalid backwards transitions
    IF OLD.status IN ('CLOSED', 'CANCELLED', 'EXPIRED') THEN
      RAISE EXCEPTION 'Cannot modify booking in terminal status %', OLD.status;
    END IF;

    -- Record status audit history automatically
    INSERT INTO public.booking_status_history (
      booking_id, from_status, to_status, changed_by, reason, created_at
    ) VALUES (
      NEW.id, OLD.status, NEW.status, auth.uid(), 'State transition triggered', NOW()
    );

    -- Single active work session lock:
    -- If worker moves into active job states, lock availability
    IF NEW.labor_id IS NOT NULL THEN
      IF NEW.status IN ('ACCEPTED', 'ON_THE_WAY', 'ARRIVED', 'IN_PROGRESS') THEN
        
        -- Guard against double-booking
        SELECT EXISTS(
          SELECT 1 FROM public.bookings
          WHERE labor_id = NEW.labor_id
            AND id <> NEW.id
            AND status IN ('ACCEPTED', 'ON_THE_WAY', 'ARRIVED', 'IN_PROGRESS')
        ) INTO v_has_other_active_job;

        IF v_has_other_active_job THEN
          RAISE EXCEPTION 'Worker % already has an active in-progress job', NEW.labor_id;
        END IF;

        UPDATE public.labor_profiles
        SET is_occupied = TRUE, updated_at = NOW()
        WHERE id = NEW.labor_id;

      ELSIF NEW.status IN ('WORK_DONE', 'CLOSED', 'CANCELLED') THEN
        
        -- Unlock availability if no other active jobs exist
        SELECT EXISTS(
          SELECT 1 FROM public.bookings
          WHERE labor_id = NEW.labor_id
            AND id <> NEW.id
            AND status IN ('ACCEPTED', 'ON_THE_WAY', 'ARRIVED', 'IN_PROGRESS')
        ) INTO v_has_other_active_job;

        IF NOT v_has_other_active_job THEN
          UPDATE public.labor_profiles
          SET is_occupied = FALSE,
              completed_jobs_count = CASE WHEN NEW.status = 'CLOSED' THEN completed_jobs_count + 1 ELSE completed_jobs_count END,
              updated_at = NOW()
          WHERE id = NEW.labor_id;
        END IF;

      END IF;
    END IF;

  END IF;

  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER trg_booking_state_transition
BEFORE UPDATE ON public.bookings
FOR EACH ROW EXECUTE FUNCTION public.handle_booking_state_transition();

-- 4. PostGIS Spatial Search Function
-- Finds online, eligible, un-occupied, verified professionals within radius sorted by Bayesian rating
CREATE OR REPLACE FUNCTION public.find_nearby_eligible_pros(
  p_latitude DOUBLE PRECISION,
  p_longitude DOUBLE PRECISION,
  p_service_id UUID,
  p_max_distance_meters INT DEFAULT 20000,
  p_limit INT DEFAULT 20
)
RETURNS TABLE (
  labor_id UUID,
  full_name TEXT,
  phone TEXT,
  avatar_url TEXT,
  rating_avg NUMERIC(3, 2),
  rating_count INT,
  bayesian_rating NUMERIC(3, 2),
  completed_jobs_count INT,
  distance_meters DOUBLE PRECISION,
  visiting_charge_paise BIGINT
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    lp.id AS labor_id,
    p.full_name,
    p.phone,
    p.avatar_url,
    lp.rating_avg,
    lp.rating_count,
    lp.bayesian_rating,
    lp.completed_jobs_count,
    ST_Distance(
      lp.current_location,
      ST_SetSRID(ST_MakePoint(p_longitude, p_latitude), 4326)::geography
    ) AS distance_meters,
    s.visiting_charge_paise
  FROM public.labor_profiles lp
  JOIN public.profiles p ON p.id = lp.id
  JOIN public.labor_services ls ON ls.labor_id = lp.id
  JOIN public.services s ON s.id = ls.service_id
  WHERE ls.service_id = p_service_id
    AND lp.is_online = TRUE
    AND lp.is_occupied = FALSE
    AND lp.is_cash_locked = FALSE
    AND lp.kyc_status = 'verified'
    AND p.is_active = TRUE
    AND ST_DWithin(
      lp.current_location,
      ST_SetSRID(ST_MakePoint(p_longitude, p_latitude), 4326)::geography,
      LEAST(p_max_distance_meters, lp.travel_radius_km * 1000)
    )
  ORDER BY
    lp.bayesian_rating DESC,
    distance_meters ASC
  LIMIT p_limit;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- 5. Cash Exposure Limit & Soft-Lock Maintenance
CREATE OR REPLACE FUNCTION public.update_labor_cash_exposure(
  p_labor_id UUID,
  p_additional_dues_paise BIGINT,
  p_gross_cash_paise BIGINT
)
RETURNS VOID AS $$
DECLARE
  v_new_dues BIGINT;
  v_limit BIGINT;
BEGIN
  SELECT platform_dues_paise + p_additional_dues_paise, cash_limit_paise
  INTO v_new_dues, v_limit
  FROM public.labor_profiles
  WHERE id = p_labor_id;

  UPDATE public.labor_profiles
  SET
    platform_dues_paise = v_new_dues,
    gross_cash_collected_paise = gross_cash_collected_paise + p_gross_cash_paise,
    is_cash_locked = (v_new_dues >= v_limit),
    updated_at = NOW()
  WHERE id = p_labor_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
