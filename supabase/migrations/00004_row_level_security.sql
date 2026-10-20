-- CivilHand Row-Level Security (RLS) Policies
-- Module: Multi-tenant Data Protection & Role-Based Access Control

-- Helper: Check if executing user has admin role
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role = 'admin' AND is_active = TRUE
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

-- Enable RLS on all tables
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

-- 1. Profiles
CREATE POLICY "Users can view their own profile"
  ON public.profiles FOR SELECT
  USING (id = auth.uid() OR public.is_admin());

CREATE POLICY "Users can update their own profile"
  ON public.profiles FOR UPDATE
  USING (id = auth.uid() OR public.is_admin());

-- 2. Customer Profiles
CREATE POLICY "Customers can manage own customer profile"
  ON public.customer_profiles FOR ALL
  USING (id = auth.uid() OR public.is_admin());

-- 3. Labor Profiles
CREATE POLICY "Public can view basic verified labor profiles"
  ON public.labor_profiles FOR SELECT
  USING (kyc_status = 'verified' OR id = auth.uid() OR public.is_admin());

CREATE POLICY "Laborers can update their own availability & location"
  ON public.labor_profiles FOR UPDATE
  USING (id = auth.uid() OR public.is_admin());

-- 4. Labor KYC
CREATE POLICY "Laborers can view and submit their own KYC"
  ON public.labor_kyc FOR SELECT
  USING (labor_id = auth.uid() OR public.is_admin());

CREATE POLICY "Laborers can insert own KYC"
  ON public.labor_kyc FOR INSERT
  WITH CHECK (labor_id = auth.uid());

CREATE POLICY "Only admins can update KYC status"
  ON public.labor_kyc FOR UPDATE
  USING (public.is_admin());

-- 5. Services & Categories (Public read, admin write)
CREATE POLICY "Anyone can view active categories"
  ON public.service_categories FOR SELECT
  USING (is_active = TRUE OR public.is_admin());

CREATE POLICY "Admins manage categories"
  ON public.service_categories FOR ALL
  USING (public.is_admin());

CREATE POLICY "Anyone can view active services"
  ON public.services FOR SELECT
  USING (is_active = TRUE OR public.is_admin());

CREATE POLICY "Admins manage services"
  ON public.services FOR ALL
  USING (public.is_admin());

CREATE POLICY "Laborers view own and manage mapped services"
  ON public.labor_services FOR ALL
  USING (labor_id = auth.uid() OR public.is_admin());

-- 6. Bookings
CREATE POLICY "Customers can view their own bookings"
  ON public.bookings FOR SELECT
  USING (customer_id = auth.uid() OR labor_id = auth.uid() OR public.is_admin());

CREATE POLICY "Customers can insert their own bookings"
  ON public.bookings FOR INSERT
  WITH CHECK (customer_id = auth.uid());

CREATE POLICY "Participants can update their booking"
  ON public.bookings FOR UPDATE
  USING (customer_id = auth.uid() OR labor_id = auth.uid() OR public.is_admin());

-- 7. Quotes
CREATE POLICY "Participants can view booking quotes"
  ON public.booking_quotes FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.bookings b
      WHERE b.id = booking_id AND (b.customer_id = auth.uid() OR b.labor_id = auth.uid())
    ) OR public.is_admin()
  );

CREATE POLICY "Laborers can submit quotes for their bookings"
  ON public.booking_quotes FOR INSERT
  WITH CHECK (labor_id = auth.uid());

CREATE POLICY "Participants can update quotes"
  ON public.booking_quotes FOR UPDATE
  USING (
    labor_id = auth.uid() OR
    EXISTS (SELECT 1 FROM public.bookings b WHERE b.id = booking_id AND b.customer_id = auth.uid()) OR
    public.is_admin()
  );

-- 8. Disputes
CREATE POLICY "Participants and admins can view disputes"
  ON public.disputes FOR SELECT
  USING (
    raised_by = auth.uid() OR
    EXISTS (SELECT 1 FROM public.bookings b WHERE b.id = booking_id AND (b.customer_id = auth.uid() OR b.labor_id = auth.uid())) OR
    public.is_admin()
  );

CREATE POLICY "Customers can raise disputes"
  ON public.disputes FOR INSERT
  WITH CHECK (raised_by = auth.uid());

CREATE POLICY "Admins resolve disputes"
  ON public.disputes FOR UPDATE
  USING (public.is_admin());

-- 9. Chat Messages
CREATE POLICY "Booking participants can read chat"
  ON public.chat_messages FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.bookings b
      WHERE b.id = booking_id AND (b.customer_id = auth.uid() OR b.labor_id = auth.uid())
    ) OR public.is_admin()
  );

CREATE POLICY "Booking participants can send chat"
  ON public.chat_messages FOR INSERT
  WITH CHECK (
    sender_id = auth.uid() AND
    EXISTS (
      SELECT 1 FROM public.bookings b
      WHERE b.id = booking_id AND (b.customer_id = auth.uid() OR b.labor_id = auth.uid())
    )
  );

-- 10. Financial Ledger & Payouts (Strict: Admin & Service Role only)
CREATE POLICY "Admins can view ledger accounts"
  ON public.ledger_accounts FOR SELECT
  USING (public.is_admin());

CREATE POLICY "Admins can view ledger transactions"
  ON public.ledger_transactions FOR SELECT
  USING (public.is_admin());

CREATE POLICY "Workers and customers can view their ledger entries"
  ON public.ledger_entries FOR SELECT
  USING (labor_id = auth.uid() OR customer_id = auth.uid() OR public.is_admin());

CREATE POLICY "Workers can view their settlements and payouts"
  ON public.cash_settlements FOR SELECT
  USING (labor_id = auth.uid() OR public.is_admin());

CREATE POLICY "Workers can view their payout status"
  ON public.labor_payouts FOR SELECT
  USING (labor_id = auth.uid() OR public.is_admin());

CREATE POLICY "Booking participants can view payments"
  ON public.payments FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.bookings b
      WHERE b.id = booking_id AND (b.customer_id = auth.uid() OR b.labor_id = auth.uid())
    ) OR public.is_admin()
  );
