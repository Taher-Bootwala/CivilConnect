-- CivilHand PostgreSQL Initial Schema Migration
-- Module: Core Schema & PostGIS Setup

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "postgis";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Enums
CREATE TYPE user_role AS ENUM ('customer', 'professional', 'admin');
CREATE TYPE kyc_status AS ENUM ('pending', 'submitted', 'verified', 'rejected');
CREATE TYPE booking_status AS ENUM (
  'REQUESTED',
  'ACCEPTED',
  'ON_THE_WAY',
  'ARRIVED',
  'IN_PROGRESS',
  'WORK_DONE',
  'AMOUNT_PENDING_APPROVAL',
  'APPROVED',
  'DISPUTED',
  'PAYMENT_PENDING',
  'PAID',
  'CLOSED',
  'CANCELLED',
  'EXPIRED'
);
CREATE TYPE quote_status AS ENUM ('pending', 'approved', 'disputed', 'revised', 'superseded');
CREATE TYPE payment_method_type AS ENUM ('online_razorpay', 'cash');
CREATE TYPE payment_status_type AS ENUM ('pending', 'captured', 'failed', 'refunded');
CREATE TYPE dispute_status_type AS ENUM ('open', 'quote_revised', 'escalated_to_admin', 'resolved_by_admin');

-- 1. Canonical Profiles
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

-- 2. Customer Profiles
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

-- 3. Professional (Labor) Profiles
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
  
  -- Cash Exposure & Soft-Lock Controls (in integer paise)
  gross_cash_collected_paise BIGINT NOT NULL DEFAULT 0,
  platform_dues_paise BIGINT NOT NULL DEFAULT 0,
  cash_limit_paise BIGINT NOT NULL DEFAULT 500000, -- Default ₹5,000 (in paise)
  is_cash_locked BOOLEAN NOT NULL DEFAULT FALSE,
  
  -- Bank Details for Payouts
  bank_account_number TEXT,
  bank_ifsc TEXT,
  bank_account_holder TEXT,
  upi_id TEXT,
  
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 4. Labor KYC Documents
CREATE TABLE IF NOT EXISTS public.labor_kyc (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  labor_id UUID NOT NULL REFERENCES public.labor_profiles(id) ON DELETE CASCADE,
  id_type TEXT NOT NULL, -- 'aadhaar', 'pan', 'driving_license'
  id_number_masked TEXT NOT NULL,
  id_document_front_url TEXT NOT NULL,
  id_document_back_url TEXT,
  status kyc_status NOT NULL DEFAULT 'submitted',
  rejection_reason TEXT,
  reviewed_by UUID REFERENCES public.profiles(id),
  reviewed_at TIMESTAMPTZ,
  submitted_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 5. Service Categories
CREATE TABLE IF NOT EXISTS public.service_categories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  slug TEXT UNIQUE NOT NULL,
  icon_name TEXT NOT NULL,
  display_order INT NOT NULL DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 6. Services & Commission Config
CREATE TABLE IF NOT EXISTS public.services (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  category_id UUID NOT NULL REFERENCES public.service_categories(id) ON DELETE RESTRICT,
  name TEXT NOT NULL,
  description TEXT NOT NULL,
  min_estimate_paise BIGINT NOT NULL DEFAULT 15000, -- ₹150 in paise
  max_estimate_paise BIGINT NOT NULL DEFAULT 200000, -- ₹2,000 in paise
  visiting_charge_paise BIGINT NOT NULL DEFAULT 9900, -- ₹99 in paise
  typical_duration_minutes INT NOT NULL DEFAULT 60,
  
  -- Commission & Fixed Platform Fee (Integer paise / percentage points)
  commission_percentage NUMERIC(5, 2) NOT NULL DEFAULT 15.00, -- 15%
  fixed_platform_fee_paise BIGINT NOT NULL DEFAULT 4900, -- ₹49 in paise
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 7. Labor Service Mapping
CREATE TABLE IF NOT EXISTS public.labor_services (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  labor_id UUID NOT NULL REFERENCES public.labor_profiles(id) ON DELETE CASCADE,
  service_id UUID NOT NULL REFERENCES public.services(id) ON DELETE CASCADE,
  is_verified BOOLEAN NOT NULL DEFAULT TRUE,
  UNIQUE(labor_id, service_id)
);

-- 8. Bookings
CREATE TABLE IF NOT EXISTS public.bookings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_code TEXT UNIQUE NOT NULL,
  customer_id UUID NOT NULL REFERENCES public.customer_profiles(id) ON DELETE RESTRICT,
  labor_id UUID REFERENCES public.labor_profiles(id) ON DELETE SET NULL,
  service_id UUID NOT NULL REFERENCES public.services(id) ON DELETE RESTRICT,
  status booking_status NOT NULL DEFAULT 'REQUESTED',
  
  -- Dispatching
  dispatch_mode TEXT NOT NULL DEFAULT 'auto', -- 'auto' or 'manual'
  dispatch_timeout_seconds INT NOT NULL DEFAULT 120,
  
  -- Timing
  is_asap BOOLEAN NOT NULL DEFAULT TRUE,
  scheduled_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  
  -- Coordinates & Address Snapshot
  service_location GEOGRAPHY(POINT, 4326) NOT NULL,
  address_snapshot TEXT NOT NULL,
  address_landmark TEXT,
  
  -- Problem Details
  problem_description TEXT NOT NULL,
  problem_photos TEXT[] DEFAULT '{}',
  problem_voice_url TEXT,
  
  -- Security: 4-digit start OTP (stored hashed)
  start_otp_hash TEXT NOT NULL,
  
  -- Tracking Timestamps
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

-- 9. Booking Status History
CREATE TABLE IF NOT EXISTS public.booking_status_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id UUID NOT NULL REFERENCES public.bookings(id) ON DELETE CASCADE,
  from_status booking_status,
  to_status booking_status NOT NULL,
  changed_by UUID REFERENCES public.profiles(id),
  reason TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 10. Booking Quotes (Submitted by worker upon work completion)
CREATE TABLE IF NOT EXISTS public.booking_quotes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id UUID NOT NULL REFERENCES public.bookings(id) ON DELETE CASCADE,
  labor_id UUID NOT NULL REFERENCES public.labor_profiles(id) ON DELETE RESTRICT,
  version INT NOT NULL DEFAULT 1,
  
  -- Itemized breakdown in integer paise
  labor_charge_paise BIGINT NOT NULL,
  material_charge_paise BIGINT NOT NULL DEFAULT 0,
  visiting_charge_paise BIGINT NOT NULL DEFAULT 0,
  fixed_platform_fee_paise BIGINT NOT NULL,
  commission_paise BIGINT NOT NULL,
  tax_paise BIGINT NOT NULL DEFAULT 0,
  
  -- Calculated Totals
  total_customer_paise BIGINT NOT NULL, -- labor + material + visiting + platform_fee + tax
  net_labor_paise BIGINT NOT NULL, -- labor + material + visiting - commission
  
  explanation_note TEXT,
  before_photos TEXT[] DEFAULT '{}',
  after_photos TEXT[] DEFAULT '{}',
  material_receipt_photos TEXT[] DEFAULT '{}',
  
  status quote_status NOT NULL DEFAULT 'pending',
  customer_response_note TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  responded_at TIMESTAMPTZ
);

-- 11. Disputes
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

-- 12. Ratings & Reviews
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

-- 13. In-App Chat Messages
CREATE TABLE IF NOT EXISTS public.chat_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id UUID NOT NULL REFERENCES public.bookings(id) ON DELETE CASCADE,
  sender_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  message_text TEXT NOT NULL,
  media_url TEXT,
  is_read BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 14. Spatial & Operational Indexes
CREATE INDEX IF NOT EXISTS idx_labor_location ON public.labor_profiles USING GIST (current_location);
CREATE INDEX IF NOT EXISTS idx_booking_location ON public.bookings USING GIST (service_location);
CREATE INDEX IF NOT EXISTS idx_booking_status ON public.bookings(status);
CREATE INDEX IF NOT EXISTS idx_booking_customer ON public.bookings(customer_id);
CREATE INDEX IF NOT EXISTS idx_booking_labor ON public.bookings(labor_id);
CREATE INDEX IF NOT EXISTS idx_booking_scheduled ON public.bookings(scheduled_at);
CREATE INDEX IF NOT EXISTS idx_quotes_booking ON public.booking_quotes(booking_id);
CREATE INDEX IF NOT EXISTS idx_chat_booking ON public.chat_messages(booking_id, created_at);
