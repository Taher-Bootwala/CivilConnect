-- ============================================================================
-- CivilHand: Complete Master Database Setup Script for Supabase
-- Run this entire script in Supabase Cloud SQL Editor (1-Click Setup)
-- ============================================================================

-- Step 1: Extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "postgis";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Step 2: Custom Enums
DO $$ BEGIN
  CREATE TYPE user_role AS ENUM ('customer', 'professional', 'admin');
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
  CREATE TYPE kyc_status AS ENUM ('pending', 'submitted', 'verified', 'rejected');
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
  CREATE TYPE booking_status AS ENUM (
    'REQUESTED', 'ACCEPTED', 'ON_THE_WAY', 'ARRIVED', 'IN_PROGRESS',
    'WORK_DONE', 'AMOUNT_PENDING_APPROVAL', 'APPROVED', 'DISPUTED',
    'PAYMENT_PENDING', 'PAID', 'CLOSED', 'CANCELLED', 'EXPIRED'
  );
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
  CREATE TYPE quote_status AS ENUM ('pending', 'approved', 'disputed', 'revised', 'superseded');
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
  CREATE TYPE payment_method_type AS ENUM ('online_razorpay', 'cash');
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
  CREATE TYPE payment_status_type AS ENUM ('pending', 'captured', 'failed', 'refunded');
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
  CREATE TYPE dispute_status_type AS ENUM ('open', 'quote_revised', 'escalated_to_admin', 'resolved_by_admin');
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
  CREATE TYPE account_type AS ENUM ('ASSET', 'LIABILITY', 'EQUITY', 'REVENUE', 'EXPENSE');
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
  CREATE TYPE journal_type AS ENUM (
    'BOOKING_ONLINE_PAYMENT', 'BOOKING_CASH_COLLECTED', 'CASH_SETTLEMENT_DEPOSIT',
    'PROFESSIONAL_PAYOUT', 'REFUND', 'CANCELLATION_PENALTY', 'ADMIN_ADJUSTMENT'
  );
EXCEPTION WHEN duplicate_object THEN null; END $$;

-- Step 3: Core Tables
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  role user_role NOT NULL DEFAULT 'customer',
  full_name TEXT NOT NULL,
  phone TEXT UNIQUE NOT NULL,
  email TEXT UNIQUE,
  avatar_url TEXT,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.customer_profiles (
  id UUID PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
  default_address TEXT,
  default_latitude DOUBLE PRECISION,
  default_longitude DOUBLE PRECISION,
  emergency_contact TEXT,
  strikes_count INT NOT NULL DEFAULT 0,
  outstanding_penalty_paise BIGINT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.labor_profiles (
  id UUID PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
  bio TEXT,
  experience_years INT NOT NULL DEFAULT 0,
  current_location GEOGRAPHY(POINT, 4326),
  travel_radius_km INT NOT NULL DEFAULT 15,
  is_online BOOLEAN NOT NULL DEFAULT FALSE,
  is_occupied BOOLEAN NOT NULL DEFAULT FALSE,
  kyc_status kyc_status NOT NULL DEFAULT 'pending',
  rating_avg NUMERIC(3, 2) NOT NULL DEFAULT 5.00,
  rating_count INT NOT NULL DEFAULT 0,
  bayesian_rating NUMERIC(3, 2) NOT NULL DEFAULT 4.00,
  completed_jobs_count INT NOT NULL DEFAULT 0,
  gross_cash_collected_paise BIGINT NOT NULL DEFAULT 0,
  platform_dues_paise BIGINT NOT NULL DEFAULT 0,
  cash_limit_paise BIGINT NOT NULL DEFAULT 500000, -- ₹5,000 in paise
  is_cash_locked BOOLEAN NOT NULL DEFAULT FALSE,
  bank_account_number TEXT,
  bank_ifsc TEXT,
  bank_account_holder TEXT,
  upi_id TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.labor_kyc (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  labor_id UUID NOT NULL REFERENCES public.labor_profiles(id) ON DELETE CASCADE,
  id_type TEXT NOT NULL,
  id_number_masked TEXT NOT NULL,
  id_document_front_url TEXT NOT NULL,
  id_document_back_url TEXT,
  status kyc_status NOT NULL DEFAULT 'submitted',
  rejection_reason TEXT,
  reviewed_by UUID REFERENCES public.profiles(id),
  reviewed_at TIMESTAMPTZ,
  submitted_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.service_categories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  slug TEXT UNIQUE NOT NULL,
  icon_name TEXT NOT NULL,
  display_order INT NOT NULL DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.services (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  category_id UUID NOT NULL REFERENCES public.service_categories(id) ON DELETE RESTRICT,
  name TEXT NOT NULL,
  description TEXT NOT NULL,
  min_estimate_paise BIGINT NOT NULL DEFAULT 15000,
  max_estimate_paise BIGINT NOT NULL DEFAULT 200000,
  visiting_charge_paise BIGINT NOT NULL DEFAULT 9900,
  typical_duration_minutes INT NOT NULL DEFAULT 60,
  commission_percentage NUMERIC(5, 2) NOT NULL DEFAULT 15.00,
  fixed_platform_fee_paise BIGINT NOT NULL DEFAULT 4900,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.labor_services (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  labor_id UUID NOT NULL REFERENCES public.labor_profiles(id) ON DELETE CASCADE,
  service_id UUID NOT NULL REFERENCES public.services(id) ON DELETE CASCADE,
  is_verified BOOLEAN NOT NULL DEFAULT TRUE,
  UNIQUE(labor_id, service_id)
);

CREATE TABLE IF NOT EXISTS public.bookings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_code TEXT UNIQUE NOT NULL,
  customer_id UUID NOT NULL REFERENCES public.customer_profiles(id) ON DELETE RESTRICT,
  labor_id UUID REFERENCES public.labor_profiles(id) ON DELETE SET NULL,
  service_id UUID NOT NULL REFERENCES public.services(id) ON DELETE RESTRICT,
  status booking_status NOT NULL DEFAULT 'REQUESTED',
  dispatch_mode TEXT NOT NULL DEFAULT 'auto',
  dispatch_timeout_seconds INT NOT NULL DEFAULT 120,
  is_asap BOOLEAN NOT NULL DEFAULT TRUE,
  scheduled_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  service_location GEOGRAPHY(POINT, 4326) NOT NULL,
  address_snapshot TEXT NOT NULL,
  address_landmark TEXT,
  problem_description TEXT NOT NULL,
  problem_photos TEXT[] DEFAULT '{}',
  problem_voice_url TEXT,
  start_otp_hash TEXT NOT NULL,
  dispatched_at TIMESTAMPTZ,
  accepted_at TIMESTAMPTZ,
  on_the_way_at TIMESTAMPTZ,
  arrived_at TIMESTAMPTZ,
  work_started_at TIMESTAMPTZ,
  work_completed_at TIMESTAMPTZ,
  cancelled_at TIMESTAMPTZ,
  cancelled_by UUID REFERENCES public.profiles(id),
  cancellation_reason TEXT,
  penalty_paise BIGINT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.booking_status_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id UUID NOT NULL REFERENCES public.bookings(id) ON DELETE CASCADE,
  from_status booking_status,
  to_status booking_status NOT NULL,
  changed_by UUID REFERENCES public.profiles(id),
  reason TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.booking_quotes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id UUID NOT NULL REFERENCES public.bookings(id) ON DELETE CASCADE,
  labor_id UUID NOT NULL REFERENCES public.labor_profiles(id) ON DELETE RESTRICT,
  version INT NOT NULL DEFAULT 1,
  labor_charge_paise BIGINT NOT NULL,
  material_charge_paise BIGINT NOT NULL DEFAULT 0,
  visiting_charge_paise BIGINT NOT NULL DEFAULT 0,
  fixed_platform_fee_paise BIGINT NOT NULL,
  commission_paise BIGINT NOT NULL,
  tax_paise BIGINT NOT NULL DEFAULT 0,
  total_customer_paise BIGINT NOT NULL,
  net_labor_paise BIGINT NOT NULL,
  explanation_note TEXT,
  before_photos TEXT[] DEFAULT '{}',
  after_photos TEXT[] DEFAULT '{}',
  material_receipt_photos TEXT[] DEFAULT '{}',
  status quote_status NOT NULL DEFAULT 'pending',
  customer_response_note TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  responded_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS public.disputes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id UUID NOT NULL REFERENCES public.bookings(id) ON DELETE CASCADE,
  quote_id UUID NOT NULL REFERENCES public.booking_quotes(id) ON DELETE RESTRICT,
  raised_by UUID NOT NULL REFERENCES public.profiles(id),
  reason TEXT NOT NULL,
  proposed_counter_amount_paise BIGINT,
  status dispute_status_type NOT NULL DEFAULT 'open',
  revision_count INT NOT NULL DEFAULT 0,
  admin_resolution_note TEXT,
  resolved_by UUID REFERENCES public.profiles(id),
  resolved_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.ratings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id UUID UNIQUE NOT NULL REFERENCES public.bookings(id) ON DELETE CASCADE,
  customer_id UUID NOT NULL REFERENCES public.customer_profiles(id) ON DELETE CASCADE,
  labor_id UUID NOT NULL REFERENCES public.labor_profiles(id) ON DELETE CASCADE,
  rating_score INT NOT NULL CHECK (rating_score >= 1 AND rating_score <= 5),
  tags TEXT[] DEFAULT '{}',
  review_text TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.chat_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id UUID NOT NULL REFERENCES public.bookings(id) ON DELETE CASCADE,
  sender_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  message_text TEXT NOT NULL,
  media_url TEXT,
  is_read BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Step 4: Double-Entry Financial Ledger
CREATE TABLE IF NOT EXISTS public.ledger_accounts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code TEXT UNIQUE NOT NULL,
  name TEXT NOT NULL,
  account_type account_type NOT NULL,
  description TEXT,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO public.ledger_accounts (code, name, account_type, description) VALUES
  ('1000', 'Razorpay Clearing (Cash & Bank Asset)', 'ASSET', 'Online customer payments received via payment gateway'),
  ('1100', 'Laborer Cash In Hand (Platform Receivable)', 'ASSET', 'Platform commission & fee dues owed by worker from cash jobs'),
  ('2000', 'Professional Earnings Payable', 'LIABILITY', 'Net earnings owed to professionals for completed online bookings'),
  ('2100', 'Customer Unearned Deposits & Advances', 'LIABILITY', 'Pending customer booking funds prior to job completion'),
  ('2200', 'GST & Tax Liabilities Payable', 'LIABILITY', 'Collected tax amounts owed to government authorities'),
  ('4000', 'Platform Commission Revenue', 'REVENUE', 'Percentage commission earned on completed service quotes'),
  ('4100', 'Platform Fixed Fee Revenue', 'REVENUE', 'Fixed customer platform/convenience fee revenue'),
  ('4200', 'Cancellation Penalty Revenue', 'REVENUE', 'Penalties charged on late customer or worker cancellations'),
  ('5000', 'Payment Gateway Transaction Expenses', 'EXPENSE', 'Razorpay processing and transfer fees')
ON CONFLICT (code) DO NOTHING;

CREATE TABLE IF NOT EXISTS public.payments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id UUID NOT NULL REFERENCES public.bookings(id) ON DELETE RESTRICT,
  quote_id UUID REFERENCES public.booking_quotes(id) ON DELETE RESTRICT,
  amount_paise BIGINT NOT NULL,
  currency TEXT NOT NULL DEFAULT 'INR',
  payment_method payment_method_type NOT NULL,
  payment_status payment_status_type NOT NULL DEFAULT 'pending',
  razorpay_order_id TEXT UNIQUE,
  razorpay_payment_id TEXT UNIQUE,
  razorpay_signature TEXT,
  cash_collected_confirmed_by_worker BOOLEAN NOT NULL DEFAULT FALSE,
  cash_collected_confirmed_by_customer BOOLEAN NOT NULL DEFAULT FALSE,
  error_code TEXT,
  error_description TEXT,
  metadata JSONB NOT NULL DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  captured_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS public.ledger_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  transaction_ref TEXT UNIQUE NOT NULL,
  transaction_type journal_type NOT NULL,
  booking_id UUID REFERENCES public.bookings(id) ON DELETE SET NULL,
  payment_id UUID REFERENCES public.payments(id) ON DELETE SET NULL,
  actor_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  description TEXT NOT NULL,
  metadata JSONB NOT NULL DEFAULT '{}',
  posted_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.ledger_entries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  transaction_id UUID NOT NULL REFERENCES public.ledger_transactions(id) ON DELETE CASCADE,
  account_id UUID NOT NULL REFERENCES public.ledger_accounts(id) ON DELETE RESTRICT,
  labor_id UUID REFERENCES public.labor_profiles(id) ON DELETE RESTRICT,
  customer_id UUID REFERENCES public.customer_profiles(id) ON DELETE RESTRICT,
  debit_paise BIGINT NOT NULL DEFAULT 0 CHECK (debit_paise >= 0),
  credit_paise BIGINT NOT NULL DEFAULT 0 CHECK (credit_paise >= 0),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (debit_paise > 0 OR credit_paise > 0),
  CHECK (NOT (debit_paise > 0 AND credit_paise > 0))
);

CREATE TABLE IF NOT EXISTS public.cash_settlements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  settlement_ref TEXT UNIQUE NOT NULL,
  labor_id UUID NOT NULL REFERENCES public.labor_profiles(id) ON DELETE RESTRICT,
  amount_paise BIGINT NOT NULL CHECK (amount_paise > 0),
  status payment_status_type NOT NULL DEFAULT 'pending',
  razorpay_order_id TEXT UNIQUE,
  razorpay_payment_id TEXT UNIQUE,
  razorpay_signature TEXT,
  settled_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.labor_payouts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  payout_ref TEXT UNIQUE NOT NULL,
  labor_id UUID NOT NULL REFERENCES public.labor_profiles(id) ON DELETE RESTRICT,
  amount_paise BIGINT NOT NULL CHECK (amount_paise > 0),
  payout_method TEXT NOT NULL,
  bank_account TEXT,
  bank_ifsc TEXT,
  upi_id TEXT,
  razorpay_payout_id TEXT UNIQUE,
  status TEXT NOT NULL DEFAULT 'pending',
  failure_reason TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  processed_at TIMESTAMPTZ
);

-- Step 5: Database Functions & Triggers
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
    RAISE EXCEPTION 'Ledger imbalance: Debits (%) != Credits (%)', v_total_debit, v_total_credit;
  END IF;
  RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION public.update_labor_bayesian_rating()
RETURNS TRIGGER AS $$
DECLARE
  v_m CONSTANT NUMERIC := 5.0;
  v_c CONSTANT NUMERIC := 4.5;
  v_v NUMERIC;
  v_r NUMERIC;
  v_new_bayesian NUMERIC(3, 2);
BEGIN
  SELECT COUNT(*), AVG(rating_score)
  INTO v_v, v_r
  FROM public.ratings
  WHERE labor_id = NEW.labor_id;

  v_new_bayesian := ROUND(((v_v / (v_v + v_m)) * v_r + (v_m / (v_v + v_m)) * v_c)::numeric, 2);

  UPDATE public.labor_profiles
  SET rating_count = v_v::int, rating_avg = ROUND(v_r::numeric, 2), bayesian_rating = v_new_bayesian, updated_at = NOW()
  WHERE id = NEW.labor_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_after_rating_insert ON public.ratings;
CREATE TRIGGER trg_after_rating_insert
AFTER INSERT OR UPDATE ON public.ratings
FOR EACH ROW EXECUTE FUNCTION public.update_labor_bayesian_rating();

CREATE OR REPLACE FUNCTION public.handle_booking_state_transition()
RETURNS TRIGGER AS $$
DECLARE
  v_has_other_active_job BOOLEAN;
BEGIN
  IF OLD.status IS NOT NULL AND OLD.status <> NEW.status THEN
    IF OLD.status IN ('CLOSED', 'CANCELLED', 'EXPIRED') THEN
      RAISE EXCEPTION 'Cannot modify booking in terminal status %', OLD.status;
    END IF;

    INSERT INTO public.booking_status_history (booking_id, from_status, to_status, changed_by, reason, created_at)
    VALUES (NEW.id, OLD.status, NEW.status, auth.uid(), 'State transition triggered', NOW());

    IF NEW.labor_id IS NOT NULL THEN
      IF NEW.status IN ('ACCEPTED', 'ON_THE_WAY', 'ARRIVED', 'IN_PROGRESS') THEN
        SELECT EXISTS(
          SELECT 1 FROM public.bookings
          WHERE labor_id = NEW.labor_id AND id <> NEW.id AND status IN ('ACCEPTED', 'ON_THE_WAY', 'ARRIVED', 'IN_PROGRESS')
        ) INTO v_has_other_active_job;

        IF v_has_other_active_job THEN
          RAISE EXCEPTION 'Worker % already has an active in-progress job', NEW.labor_id;
        END IF;

        UPDATE public.labor_profiles SET is_occupied = TRUE, updated_at = NOW() WHERE id = NEW.labor_id;
      ELSIF NEW.status IN ('WORK_DONE', 'CLOSED', 'CANCELLED') THEN
        SELECT EXISTS(
          SELECT 1 FROM public.bookings
          WHERE labor_id = NEW.labor_id AND id <> NEW.id AND status IN ('ACCEPTED', 'ON_THE_WAY', 'ARRIVED', 'IN_PROGRESS')
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

DROP TRIGGER IF EXISTS trg_booking_state_transition ON public.bookings;
CREATE TRIGGER trg_booking_state_transition
BEFORE UPDATE ON public.bookings
FOR EACH ROW EXECUTE FUNCTION public.handle_booking_state_transition();

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
    ST_Distance(lp.current_location, ST_SetSRID(ST_MakePoint(p_longitude, p_latitude), 4326)::geography) AS distance_meters,
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
    AND ST_DWithin(lp.current_location, ST_SetSRID(ST_MakePoint(p_longitude, p_latitude), 4326)::geography, LEAST(p_max_distance_meters, lp.travel_radius_km * 1000))
  ORDER BY lp.bayesian_rating DESC, distance_meters ASC
  LIMIT p_limit;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

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
  SET platform_dues_paise = v_new_dues,
      gross_cash_collected_paise = gross_cash_collected_paise + p_gross_cash_paise,
      is_cash_locked = (v_new_dues >= v_limit),
      updated_at = NOW()
  WHERE id = p_labor_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 6: PostGIS Spatial & Operational Indexes
CREATE INDEX IF NOT EXISTS idx_labor_location ON public.labor_profiles USING GIST (current_location);
CREATE INDEX IF NOT EXISTS idx_booking_location ON public.bookings USING GIST (service_location);
CREATE INDEX IF NOT EXISTS idx_booking_status ON public.bookings(status);
CREATE INDEX IF NOT EXISTS idx_booking_customer ON public.bookings(customer_id);
CREATE INDEX IF NOT EXISTS idx_booking_labor ON public.bookings(labor_id);

-- Step 7: Seed Data (Services & Categories)
INSERT INTO public.service_categories (id, name, slug, icon_name, display_order, is_active) VALUES
  ('c1000000-0000-0000-0000-000000000001', 'Plumbing', 'plumbing', 'plumbing', 1, TRUE),
  ('c1000000-0000-0000-0000-000000000002', 'Electrical', 'electrical', 'bolt', 2, TRUE),
  ('c1000000-0000-0000-0000-000000000003', 'Carpentry', 'carpentry', 'handyman', 3, TRUE),
  ('c1000000-0000-0000-0000-000000000004', 'AC & Appliance Repair', 'ac-repair', 'ac_unit', 4, TRUE),
  ('c1000000-0000-0000-0000-000000000005', 'Home Cleaning', 'cleaning', 'cleaning_services', 5, TRUE),
  ('c1000000-0000-0000-0000-000000000006', 'Painting', 'painting', 'format_paint', 6, TRUE)
ON CONFLICT (slug) DO NOTHING;

INSERT INTO public.services (
  id, category_id, name, description, min_estimate_paise, max_estimate_paise,
  visiting_charge_paise, typical_duration_minutes, commission_percentage, fixed_platform_fee_paise
) VALUES
  ('b1000000-0000-0000-0000-000000000001', 'c1000000-0000-0000-0000-000000000001', 'Tap & Mixer Repair / Replacement', 'Fix dripping taps, mixer leakage or new installation', 15000, 50000, 9900, 45, 15.00, 4900),
  ('b1000000-0000-0000-0000-000000000002', 'c1000000-0000-0000-0000-000000000001', 'Drainage & Pipe Blockage Clearance', 'Heavy duty unclogging of kitchen sink or bathroom drain', 25000, 90000, 9900, 60, 15.00, 4900),
  ('b1000000-0000-0000-0000-000000000004', 'c1000000-0000-0000-0000-000000000002', 'Switchboard & Socket Wiring', 'Repair sparking switches, short-circuits or MCB trips', 15000, 60000, 9900, 45, 15.00, 4900),
  ('b1000000-0000-0000-0000-000000000008', 'c1000000-0000-0000-0000-000000000004', 'Split / Window AC Deep Jet Servicing', 'Indoor cooling coil foaming, outdoor unit wash and filter clean', 49900, 120000, 19900, 60, 15.00, 4900)
ON CONFLICT (id) DO NOTHING;

-- Step 8: Row-Level Security (RLS) Policies (Zero-Trust Data Protection)
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role = 'admin' AND is_active = TRUE
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

-- Enable RLS across all exposed tables
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.customer_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.labor_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.labor_kyc ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.service_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.services ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.labor_services ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bookings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.booking_status_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.booking_quotes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.disputes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ratings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ledger_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ledger_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ledger_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cash_settlements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.labor_payouts ENABLE ROW LEVEL SECURITY;

-- Profiles Policies
CREATE POLICY "Users can view own profile" ON public.profiles FOR SELECT USING (id = auth.uid() OR public.is_admin());
CREATE POLICY "Users can update own profile" ON public.profiles FOR UPDATE USING (id = auth.uid() OR public.is_admin());

-- Customer Profiles Policies
CREATE POLICY "Customers manage own profile" ON public.customer_profiles FOR ALL USING (id = auth.uid() OR public.is_admin());

-- Labor Profiles Policies
CREATE POLICY "Public view verified labor profiles" ON public.labor_profiles FOR SELECT USING (kyc_status = 'verified' OR id = auth.uid() OR public.is_admin());
CREATE POLICY "Laborers update own status" ON public.labor_profiles FOR UPDATE USING (id = auth.uid() OR public.is_admin());

-- KYC Policies (Strict: worker views/submits own, only admin updates)
CREATE POLICY "Laborers view own KYC" ON public.labor_kyc FOR SELECT USING (labor_id = auth.uid() OR public.is_admin());
CREATE POLICY "Laborers insert own KYC" ON public.labor_kyc FOR INSERT WITH CHECK (labor_id = auth.uid());
CREATE POLICY "Only admins review KYC" ON public.labor_kyc FOR UPDATE USING (public.is_admin());

-- Services & Categories (Public read, admin write)
CREATE POLICY "Public view categories" ON public.service_categories FOR SELECT USING (is_active = TRUE OR public.is_admin());
CREATE POLICY "Admins manage categories" ON public.service_categories FOR ALL USING (public.is_admin());
CREATE POLICY "Public view services" ON public.services FOR SELECT USING (is_active = TRUE OR public.is_admin());
CREATE POLICY "Admins manage services" ON public.services FOR ALL USING (public.is_admin());
CREATE POLICY "Laborers manage mapped services" ON public.labor_services FOR ALL USING (labor_id = auth.uid() OR public.is_admin());

-- Bookings Policies (Customers view/insert own, assigned workers view/update)
CREATE POLICY "Participants view bookings" ON public.bookings FOR SELECT USING (customer_id = auth.uid() OR labor_id = auth.uid() OR public.is_admin());
CREATE POLICY "Customers create bookings" ON public.bookings FOR INSERT WITH CHECK (customer_id = auth.uid());
CREATE POLICY "Participants update bookings" ON public.bookings FOR UPDATE USING (customer_id = auth.uid() OR labor_id = auth.uid() OR public.is_admin());

-- Quotes Policies
CREATE POLICY "Participants view quotes" ON public.booking_quotes FOR SELECT USING (
  EXISTS (SELECT 1 FROM public.bookings b WHERE b.id = booking_id AND (b.customer_id = auth.uid() OR b.labor_id = auth.uid())) OR public.is_admin()
);
CREATE POLICY "Workers submit quotes" ON public.booking_quotes FOR INSERT WITH CHECK (labor_id = auth.uid());
CREATE POLICY "Participants update quotes" ON public.booking_quotes FOR UPDATE USING (
  labor_id = auth.uid() OR EXISTS (SELECT 1 FROM public.bookings b WHERE b.id = booking_id AND b.customer_id = auth.uid()) OR public.is_admin()
);

-- Disputes Policies
CREATE POLICY "Participants view disputes" ON public.disputes FOR SELECT USING (
  raised_by = auth.uid() OR EXISTS (SELECT 1 FROM public.bookings b WHERE b.id = booking_id AND (b.customer_id = auth.uid() OR b.labor_id = auth.uid())) OR public.is_admin()
);
CREATE POLICY "Customers raise disputes" ON public.disputes FOR INSERT WITH CHECK (raised_by = auth.uid());
CREATE POLICY "Admins resolve disputes" ON public.disputes FOR UPDATE USING (public.is_admin());

-- Chat Messages Policies
CREATE POLICY "Participants read chat" ON public.chat_messages FOR SELECT USING (
  EXISTS (SELECT 1 FROM public.bookings b WHERE b.id = booking_id AND (b.customer_id = auth.uid() OR b.labor_id = auth.uid())) OR public.is_admin()
);
CREATE POLICY "Participants send chat" ON public.chat_messages FOR INSERT WITH CHECK (
  sender_id = auth.uid() AND EXISTS (SELECT 1 FROM public.bookings b WHERE b.id = booking_id AND (b.customer_id = auth.uid() OR b.labor_id = auth.uid()))
);

-- Ledger & Accounting Policies (Strict: Admin & Service Role only)
CREATE POLICY "Admins view ledger accounts" ON public.ledger_accounts FOR SELECT USING (public.is_admin());
CREATE POLICY "Admins view ledger transactions" ON public.ledger_transactions FOR SELECT USING (public.is_admin());
CREATE POLICY "Users view own ledger entries" ON public.ledger_entries FOR SELECT USING (labor_id = auth.uid() OR customer_id = auth.uid() OR public.is_admin());
CREATE POLICY "Workers view settlements" ON public.cash_settlements FOR SELECT USING (labor_id = auth.uid() OR public.is_admin());
CREATE POLICY "Workers view payouts" ON public.labor_payouts FOR SELECT USING (labor_id = auth.uid() OR public.is_admin());
CREATE POLICY "Participants view payments" ON public.payments FOR SELECT USING (
  EXISTS (SELECT 1 FROM public.bookings b WHERE b.id = booking_id AND (b.customer_id = auth.uid() OR b.labor_id = auth.uid())) OR public.is_admin()
);

-- ============================================================================
-- Step 9: Auxiliary, Telemetry, Notifications, Auditing & India Compliance
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.device_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  fcm_token TEXT NOT NULL,
  device_type TEXT NOT NULL DEFAULT 'android',
  device_model TEXT,
  app_version TEXT,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(user_id, fcm_token)
);

CREATE TABLE IF NOT EXISTS public.labor_availability (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  labor_id UUID NOT NULL REFERENCES public.labor_profiles(id) ON DELETE CASCADE,
  day_of_week INT NOT NULL CHECK (day_of_week BETWEEN 0 AND 6),
  start_time TIME NOT NULL DEFAULT '08:00:00',
  end_time TIME NOT NULL DEFAULT '20:00:00',
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(labor_id, day_of_week)
);

CREATE TABLE IF NOT EXISTS public.labor_leaves (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  labor_id UUID NOT NULL REFERENCES public.labor_profiles(id) ON DELETE CASCADE,
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  reason TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (end_date >= start_date)
);

CREATE TABLE IF NOT EXISTS public.service_price_guide_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  service_id UUID NOT NULL REFERENCES public.services(id) ON DELETE CASCADE,
  item_name TEXT NOT NULL,
  description TEXT,
  unit_of_measure TEXT NOT NULL DEFAULT 'per unit',
  min_price_paise BIGINT NOT NULL DEFAULT 10000,
  max_price_paise BIGINT NOT NULL DEFAULT 50000,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.labor_live_location (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  labor_id UUID NOT NULL REFERENCES public.labor_profiles(id) ON DELETE CASCADE,
  current_location GEOGRAPHY(POINT, 4326) NOT NULL,
  heading DOUBLE PRECISION,
  speed_meters_per_sec DOUBLE PRECISION,
  battery_level_percent INT CHECK (battery_level_percent BETWEEN 0 AND 100),
  recorded_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.booking_assignments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id UUID NOT NULL REFERENCES public.bookings(id) ON DELETE CASCADE,
  labor_id UUID NOT NULL REFERENCES public.labor_profiles(id) ON DELETE CASCADE,
  dispatch_attempt_number INT NOT NULL DEFAULT 1,
  dispatched_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  responded_at TIMESTAMPTZ,
  response_action TEXT,
  rejection_reason TEXT,
  expires_at TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL '2 minutes')
);

CREATE TABLE IF NOT EXISTS public.notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  notification_type TEXT NOT NULL,
  data JSONB NOT NULL DEFAULT '{}',
  is_read BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.support_tickets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ticket_number TEXT UNIQUE NOT NULL,
  booking_id UUID REFERENCES public.bookings(id) ON DELETE SET NULL,
  raised_by UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  category TEXT NOT NULL,
  subject TEXT NOT NULL,
  description TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'open',
  priority TEXT NOT NULL DEFAULT 'medium',
  resolution_notes TEXT,
  resolved_by UUID REFERENCES public.profiles(id),
  resolved_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.promo_codes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code TEXT UNIQUE NOT NULL,
  description TEXT NOT NULL,
  discount_percentage NUMERIC(5, 2) NOT NULL DEFAULT 10.00,
  max_discount_paise BIGINT NOT NULL DEFAULT 15000,
  min_order_paise BIGINT NOT NULL DEFAULT 30000,
  valid_from TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  valid_until TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL '30 days'),
  max_uses INT NOT NULL DEFAULT 1000,
  current_uses INT NOT NULL DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.promo_redemptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  promo_id UUID NOT NULL REFERENCES public.promo_codes(id) ON DELETE RESTRICT,
  booking_id UUID UNIQUE NOT NULL REFERENCES public.bookings(id) ON DELETE CASCADE,
  customer_id UUID NOT NULL REFERENCES public.customer_profiles(id) ON DELETE CASCADE,
  discount_applied_paise BIGINT NOT NULL,
  redeemed_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.saved_addresses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id UUID NOT NULL REFERENCES public.customer_profiles(id) ON DELETE CASCADE,
  label TEXT NOT NULL,
  address_line TEXT NOT NULL,
  landmark TEXT,
  location GEOGRAPHY(POINT, 4326) NOT NULL,
  is_default BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.saved_laborers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id UUID NOT NULL REFERENCES public.customer_profiles(id) ON DELETE CASCADE,
  labor_id UUID NOT NULL REFERENCES public.labor_profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(customer_id, labor_id)
);

CREATE TABLE IF NOT EXISTS public.refunds (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  payment_id UUID NOT NULL REFERENCES public.payments(id) ON DELETE RESTRICT,
  booking_id UUID NOT NULL REFERENCES public.bookings(id) ON DELETE RESTRICT,
  amount_paise BIGINT NOT NULL,
  reason TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending',
  razorpay_refund_id TEXT UNIQUE,
  processed_by UUID REFERENCES public.profiles(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  processed_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS public.financial_adjustments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  adjustment_ref TEXT UNIQUE NOT NULL,
  labor_id UUID REFERENCES public.labor_profiles(id) ON DELETE SET NULL,
  customer_id UUID REFERENCES public.customer_profiles(id) ON DELETE SET NULL,
  amount_paise BIGINT NOT NULL,
  direction TEXT NOT NULL CHECK (direction IN ('credit', 'debit')),
  reason TEXT NOT NULL,
  authorized_by UUID NOT NULL REFERENCES public.profiles(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.app_config (
  key TEXT PRIMARY KEY,
  value JSONB NOT NULL,
  description TEXT,
  updated_by UUID REFERENCES public.profiles(id),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  action TEXT NOT NULL,
  entity_type TEXT NOT NULL,
  entity_id TEXT,
  old_data JSONB,
  new_data JSONB,
  ip_address TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.consent_records (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  consent_type TEXT NOT NULL,
  version TEXT NOT NULL DEFAULT '1.0',
  ip_address TEXT,
  consented_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.account_deletion_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  reason TEXT,
  status TEXT NOT NULL DEFAULT 'pending',
  scheduled_purge_date TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL '30 days'),
  requested_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Enable RLS & Policies for Auxiliary Tables
ALTER TABLE public.device_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.labor_availability ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.labor_leaves ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.service_price_guide_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.labor_live_location ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.booking_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.support_tickets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.promo_codes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.promo_redemptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.saved_addresses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.saved_laborers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.refunds ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.financial_adjustments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.app_config ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.consent_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.account_deletion_requests ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users manage own device tokens" ON public.device_tokens FOR ALL USING (user_id = auth.uid() OR public.is_admin());
CREATE POLICY "Laborers manage own availability" ON public.labor_availability FOR ALL USING (labor_id = auth.uid() OR public.is_admin());
CREATE POLICY "Public view active labor availability" ON public.labor_availability FOR SELECT USING (is_active = TRUE OR public.is_admin());
CREATE POLICY "Laborers manage leaves" ON public.labor_leaves FOR ALL USING (labor_id = auth.uid() OR public.is_admin());
CREATE POLICY "Public view price guide" ON public.service_price_guide_items FOR SELECT USING (is_active = TRUE OR public.is_admin());
CREATE POLICY "Admins manage price guide" ON public.service_price_guide_items FOR ALL USING (public.is_admin());
CREATE POLICY "Laborers insert live location" ON public.labor_live_location FOR INSERT WITH CHECK (labor_id = auth.uid());
CREATE POLICY "Authorized view live location" ON public.labor_live_location FOR SELECT USING (labor_id = auth.uid() OR public.is_admin());
CREATE POLICY "Users view own notifications" ON public.notifications FOR ALL USING (user_id = auth.uid() OR public.is_admin());
CREATE POLICY "Users manage own support tickets" ON public.support_tickets FOR ALL USING (raised_by = auth.uid() OR public.is_admin());
CREATE POLICY "Public view active promo codes" ON public.promo_codes FOR SELECT USING (is_active = TRUE AND NOW() BETWEEN valid_from AND valid_until);
CREATE POLICY "Admins manage promo codes" ON public.promo_codes FOR ALL USING (public.is_admin());
CREATE POLICY "Customers manage saved addresses" ON public.saved_addresses FOR ALL USING (customer_id = auth.uid() OR public.is_admin());
CREATE POLICY "Customers manage saved laborers" ON public.saved_laborers FOR ALL USING (customer_id = auth.uid() OR public.is_admin());
CREATE POLICY "Admins manage refunds" ON public.refunds FOR ALL USING (public.is_admin());
CREATE POLICY "Admins manage financial adjustments" ON public.financial_adjustments FOR ALL USING (public.is_admin());
CREATE POLICY "Public view app config" ON public.app_config FOR SELECT USING (TRUE);
CREATE POLICY "Admins manage app config" ON public.app_config FOR ALL USING (public.is_admin());
CREATE POLICY "Admins view audit logs" ON public.audit_logs FOR SELECT USING (public.is_admin());
CREATE POLICY "Users view and submit consent" ON public.consent_records FOR ALL USING (user_id = auth.uid() OR public.is_admin());
CREATE POLICY "Users manage deletion requests" ON public.account_deletion_requests FOR ALL USING (user_id = auth.uid() OR public.is_admin());

-- ============================================================================
-- Step 10: Worker Onboarding, Existence Checks & Approval Notifications
-- ============================================================================

CREATE OR REPLACE FUNCTION public.check_worker_exists(
  p_phone TEXT,
  p_email TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_phone_exists BOOLEAN := FALSE;
  v_email_exists BOOLEAN := FALSE;
BEGIN
  IF p_phone IS NOT NULL AND LENGTH(TRIM(p_phone)) > 0 THEN
    SELECT EXISTS (
      SELECT 1 FROM public.profiles 
      WHERE phone = TRIM(p_phone)
    ) INTO v_phone_exists;
  END IF;

  IF p_email IS NOT NULL AND LENGTH(TRIM(p_email)) > 0 THEN
    SELECT EXISTS (
      SELECT 1 FROM public.profiles 
      WHERE LOWER(email) = LOWER(TRIM(p_email))
    ) INTO v_email_exists;
  END IF;

  RETURN jsonb_build_object(
    'phone_exists', v_phone_exists,
    'email_exists', v_email_exists,
    'can_proceed', (NOT v_phone_exists AND NOT v_email_exists)
  );
END;
$$;

CREATE TABLE IF NOT EXISTS public.email_notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  recipient_email TEXT NOT NULL,
  recipient_name TEXT,
  template_type TEXT NOT NULL,
  provider TEXT NOT NULL DEFAULT 'brevo',
  status TEXT NOT NULL DEFAULT 'pending',
  subject TEXT NOT NULL,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  error_message TEXT,
  sent_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_email_notifications_status ON public.email_notifications(status, created_at);

CREATE OR REPLACE FUNCTION public.trig_labor_kyc_approved_notify()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_worker_name TEXT;
  v_worker_email TEXT;
BEGIN
  IF NEW.kyc_status = 'verified' AND (OLD.kyc_status IS DISTINCT FROM 'verified') THEN
    SELECT full_name, email INTO v_worker_name, v_worker_email
    FROM public.profiles
    WHERE id = NEW.id;

    IF v_worker_email IS NOT NULL AND LENGTH(TRIM(v_worker_email)) > 0 THEN
      INSERT INTO public.email_notifications (
        recipient_email,
        recipient_name,
        template_type,
        provider,
        status,
        subject,
        metadata
      ) VALUES (
        v_worker_email,
        COALESCE(v_worker_name, 'Professional Partner'),
        'worker_approved',
        'brevo',
        'pending',
        '🎉 Your CivilHand Professional Account is Approved! Start Accepting Jobs',
        jsonb_build_object(
          'labor_id', NEW.id,
          'experience_years', NEW.experience_years,
          'approved_at', NOW()
        )
      );
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_labor_kyc_approved ON public.labor_profiles;
CREATE TRIGGER trg_labor_kyc_approved
  AFTER UPDATE OF kyc_status ON public.labor_profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.trig_labor_kyc_approved_notify();

-- Enable RLS on email_notifications
ALTER TABLE public.email_notifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins manage email notifications"
  ON public.email_notifications
  FOR ALL
  USING (public.is_admin());

CREATE POLICY "Users view own email notifications"
  ON public.email_notifications
  FOR SELECT
  USING (recipient_email = auth.jwt() ->> 'email' OR public.is_admin());



