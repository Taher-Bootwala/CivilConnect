-- CivilHand Auxiliary & Compliance Migration
-- Module: Schedules, Telemetry, Notifications, Support, Auditing & India Compliance

-- 1. Device Tokens for Firebase Cloud Messaging (FCM)
CREATE TABLE IF NOT EXISTS public.device_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  fcm_token TEXT NOT NULL,
  device_type TEXT NOT NULL DEFAULT 'android', -- 'android', 'ios', 'web'
  device_model TEXT,
  app_version TEXT,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(user_id, fcm_token)
);

-- 2. Professional Weekly Availability Slots
CREATE TABLE IF NOT EXISTS public.labor_availability (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  labor_id UUID NOT NULL REFERENCES public.labor_profiles(id) ON DELETE CASCADE,
  day_of_week INT NOT NULL CHECK (day_of_week BETWEEN 0 AND 6), -- 0=Sunday, 6=Saturday
  start_time TIME NOT NULL DEFAULT '08:00:00',
  end_time TIME NOT NULL DEFAULT '20:00:00',
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(labor_id, day_of_week)
);

-- 3. Professional Leaves & Holidays
CREATE TABLE IF NOT EXISTS public.labor_leaves (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  labor_id UUID NOT NULL REFERENCES public.labor_profiles(id) ON DELETE CASCADE,
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  reason TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (end_date >= start_date)
);

-- 4. Service Price-Guide Items (Catalog of Standard Rates)
CREATE TABLE IF NOT EXISTS public.service_price_guide_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  service_id UUID NOT NULL REFERENCES public.services(id) ON DELETE CASCADE,
  item_name TEXT NOT NULL,
  description TEXT,
  unit_of_measure TEXT NOT NULL DEFAULT 'per unit', -- 'per point', 'per meter', 'per tap'
  min_price_paise BIGINT NOT NULL DEFAULT 10000,
  max_price_paise BIGINT NOT NULL DEFAULT 50000,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 5. Labor Live GPS Telemetry History (Battery-conscious breadcrumbs)
CREATE TABLE IF NOT EXISTS public.labor_live_location (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  labor_id UUID NOT NULL REFERENCES public.labor_profiles(id) ON DELETE CASCADE,
  current_location GEOGRAPHY(POINT, 4326) NOT NULL,
  heading DOUBLE PRECISION,
  speed_meters_per_sec DOUBLE PRECISION,
  battery_level_percent INT CHECK (battery_level_percent BETWEEN 0 AND 100),
  recorded_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 6. Booking Dispatch Queue & Attempts (Prevents race conditions)
CREATE TABLE IF NOT EXISTS public.booking_assignments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id UUID NOT NULL REFERENCES public.bookings(id) ON DELETE CASCADE,
  labor_id UUID NOT NULL REFERENCES public.labor_profiles(id) ON DELETE CASCADE,
  dispatch_attempt_number INT NOT NULL DEFAULT 1,
  dispatched_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  responded_at TIMESTAMPTZ,
  response_action TEXT, -- 'accepted', 'rejected', 'expired'
  rejection_reason TEXT,
  expires_at TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL '2 minutes')
);

-- 7. In-App Notifications Inbox
CREATE TABLE IF NOT EXISTS public.notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  notification_type TEXT NOT NULL, -- 'booking_request', 'quote_approved', 'dispute', 'settlement_alert'
  data JSONB NOT NULL DEFAULT '{}',
  is_read BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 8. Customer Support & Dispute Escalation Tickets
CREATE TABLE IF NOT EXISTS public.support_tickets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ticket_number TEXT UNIQUE NOT NULL,
  booking_id UUID REFERENCES public.bookings(id) ON DELETE SET NULL,
  raised_by UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  category TEXT NOT NULL, -- 'dispute', 'safety_sos', 'payment_issue', 'worker_conduct'
  subject TEXT NOT NULL,
  description TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'open', -- 'open', 'investigating', 'resolved', 'closed'
  priority TEXT NOT NULL DEFAULT 'medium', -- 'low', 'medium', 'high', 'urgent'
  resolution_notes TEXT,
  resolved_by UUID REFERENCES public.profiles(id),
  resolved_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 9. Promotional Codes & Redemptions
CREATE TABLE IF NOT EXISTS public.promo_codes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code TEXT UNIQUE NOT NULL,
  description TEXT NOT NULL,
  discount_percentage NUMERIC(5, 2) NOT NULL DEFAULT 10.00,
  max_discount_paise BIGINT NOT NULL DEFAULT 15000, -- Max ₹150 off
  min_order_paise BIGINT NOT NULL DEFAULT 30000, -- Min ₹300 booking
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

-- 10. Customer Saved Addresses & Saved Professionals
CREATE TABLE IF NOT EXISTS public.saved_addresses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id UUID NOT NULL REFERENCES public.customer_profiles(id) ON DELETE CASCADE,
  label TEXT NOT NULL, -- 'Home', 'Work', 'Parents'
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

-- 11. Refunds & Financial Adjustments
CREATE TABLE IF NOT EXISTS public.refunds (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  payment_id UUID NOT NULL REFERENCES public.payments(id) ON DELETE RESTRICT,
  booking_id UUID NOT NULL REFERENCES public.bookings(id) ON DELETE RESTRICT,
  amount_paise BIGINT NOT NULL,
  reason TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending', -- 'pending', 'processed', 'failed'
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

-- 12. App-wide Dynamic Configuration
CREATE TABLE IF NOT EXISTS public.app_config (
  key TEXT PRIMARY KEY,
  value JSONB NOT NULL,
  description TEXT,
  updated_by UUID REFERENCES public.profiles(id),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Seed baseline dynamic configuration
INSERT INTO public.app_config (key, value, description) VALUES
  ('cash_limit_default_paise', '500000', 'Maximum outstanding cash obligation allowed before soft lock (paise)'),
  ('cash_warning_ratio', '0.80', 'Ratio of limit at which soft warning is delivered'),
  ('min_advance_booking_minutes', '30', 'Minimum lead time in minutes for bookings from current server time'),
  ('max_advance_booking_days', '14', 'Maximum days ahead a booking can be scheduled'),
  ('worker_acceptance_timeout_seconds', '120', 'Countdown timer before sequential re-dispatch'),
  ('dispute_escalation_minutes', '15', 'Time before an unresolved quote dispute is automatically escalated')
ON CONFLICT (key) DO NOTHING;

-- 13. System Audit Log (Immutable append-only trail)
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

-- 14. India Compliance: Consent & Account Deletion Requests
CREATE TABLE IF NOT EXISTS public.consent_records (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  consent_type TEXT NOT NULL, -- 'terms_of_service', 'privacy_policy', 'background_location'
  version TEXT NOT NULL DEFAULT '1.0',
  ip_address TEXT,
  consented_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.account_deletion_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  reason TEXT,
  status TEXT NOT NULL DEFAULT 'pending', -- 'pending', 'processing', 'completed', 'cancelled'
  scheduled_purge_date TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL '30 days'),
  requested_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_fcm_user ON public.device_tokens(user_id);
CREATE INDEX IF NOT EXISTS idx_labor_availability ON public.labor_availability(labor_id, day_of_week);
CREATE INDEX IF NOT EXISTS idx_labor_telemetry ON public.labor_live_location USING GIST (current_location);
CREATE INDEX IF NOT EXISTS idx_notifications_user ON public.notifications(user_id, is_read);
CREATE INDEX IF NOT EXISTS idx_support_tickets_status ON public.support_tickets(status, priority);
CREATE INDEX IF NOT EXISTS idx_audit_logs_actor ON public.audit_logs(actor_id, created_at);

-- Enable RLS on all auxiliary tables
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

-- RLS Policies
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
