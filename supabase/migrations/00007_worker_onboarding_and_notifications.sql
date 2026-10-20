-- CivilHand Migration 00007: Worker Onboarding, Existence Checks & Approval Notifications
-- Supports Brevo / Resend transactional dispatch and duplicate worker pre-check

-- 1. Helper Function: Check if Worker Phone or Email already exists before step progression
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

-- 2. Email Notifications Queue / Audit Table
CREATE TABLE IF NOT EXISTS public.email_notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  recipient_email TEXT NOT NULL,
  recipient_name TEXT,
  template_type TEXT NOT NULL, -- 'worker_approved', 'worker_welcome', 'booking_receipt'
  provider TEXT NOT NULL DEFAULT 'brevo', -- 'brevo' or 'resend'
  status TEXT NOT NULL DEFAULT 'pending', -- 'pending', 'sent', 'failed'
  subject TEXT NOT NULL,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  error_message TEXT,
  sent_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Index for queue polling if using workers
CREATE INDEX IF NOT EXISTS idx_email_notifications_status ON public.email_notifications(status, created_at);

-- 3. Trigger Function: Automatically queue approval email when labor KYC is marked 'verified'
CREATE OR REPLACE FUNCTION public.trig_labor_kyc_approved_notify()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_worker_name TEXT;
  v_worker_email TEXT;
BEGIN
  -- Trigger only when status transitions to 'verified'
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

-- 4. Enable RLS on email_notifications (Zero-Trust protection for recipient emails)
ALTER TABLE public.email_notifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins manage email notifications"
  ON public.email_notifications
  FOR ALL
  USING (public.is_admin());

CREATE POLICY "Users view own email notifications"
  ON public.email_notifications
  FOR SELECT
  USING (recipient_email = auth.jwt() ->> 'email' OR public.is_admin());

