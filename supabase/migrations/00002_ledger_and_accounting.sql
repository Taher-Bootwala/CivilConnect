-- CivilHand Double-Entry Ledger & Financial System Migration
-- Module: Accounting, Payments, Cash Settlement, and Payouts

CREATE TYPE account_type AS ENUM ('ASSET', 'LIABILITY', 'EQUITY', 'REVENUE', 'EXPENSE');
CREATE TYPE journal_type AS ENUM (
  'BOOKING_ONLINE_PAYMENT',
  'BOOKING_CASH_COLLECTED',
  'CASH_SETTLEMENT_DEPOSIT',
  'PROFESSIONAL_PAYOUT',
  'REFUND',
  'CANCELLATION_PENALTY',
  'ADMIN_ADJUSTMENT'
);

-- 1. Chart of Accounts (COA)
CREATE TABLE IF NOT EXISTS public.ledger_accounts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code TEXT UNIQUE NOT NULL,
  name TEXT NOT NULL,
  account_type account_type NOT NULL,
  description TEXT,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Seed standard Chart of Accounts
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

-- 2. Payments (Online Razorpay orders & cash receipt records)
CREATE TABLE IF NOT EXISTS public.payments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id UUID NOT NULL REFERENCES public.bookings(id) ON DELETE RESTRICT,
  quote_id UUID REFERENCES public.booking_quotes(id) ON DELETE RESTRICT,
  amount_paise BIGINT NOT NULL,
  currency TEXT NOT NULL DEFAULT 'INR',
  payment_method payment_method_type NOT NULL,
  payment_status payment_status_type NOT NULL DEFAULT 'pending',
  
  -- Razorpay details
  razorpay_order_id TEXT UNIQUE,
  razorpay_payment_id TEXT UNIQUE,
  razorpay_signature TEXT,
  
  -- Cash verification
  cash_collected_confirmed_by_worker BOOLEAN NOT NULL DEFAULT FALSE,
  cash_collected_confirmed_by_customer BOOLEAN NOT NULL DEFAULT FALSE,
  
  error_code TEXT,
  error_description TEXT,
  metadata JSONB NOT NULL DEFAULT '{}',
  
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  captured_at TIMESTAMPTZ
);

-- 3. Journal Headers (Ledger Transactions)
CREATE TABLE IF NOT EXISTS public.ledger_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  transaction_ref TEXT UNIQUE NOT NULL, -- e.g. TXN-BOOK-12345
  transaction_type journal_type NOT NULL,
  booking_id UUID REFERENCES public.bookings(id) ON DELETE SET NULL,
  payment_id UUID REFERENCES public.payments(id) ON DELETE SET NULL,
  actor_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  description TEXT NOT NULL,
  metadata JSONB NOT NULL DEFAULT '{}',
  posted_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 4. Journal Lines (Ledger Entries)
-- Strictly append-only: modifications must be done via reversal transactions
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
  CHECK (NOT (debit_paise > 0 AND credit_paise > 0)) -- Must be either debit or credit
);

-- 5. Cash Settlements (Worker remitting platform dues via Razorpay)
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

-- 6. Professional Payouts (Platform transferring earnings to Worker bank/UPI)
CREATE TABLE IF NOT EXISTS public.labor_payouts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  payout_ref TEXT UNIQUE NOT NULL,
  labor_id UUID NOT NULL REFERENCES public.labor_profiles(id) ON DELETE RESTRICT,
  amount_paise BIGINT NOT NULL CHECK (amount_paise > 0),
  payout_method TEXT NOT NULL, -- 'IMPS', 'NEFT', 'UPI'
  bank_account TEXT,
  bank_ifsc TEXT,
  upi_id TEXT,
  razorpay_payout_id TEXT UNIQUE,
  status TEXT NOT NULL DEFAULT 'pending', -- pending, processing, processed, failed, reversed
  failure_reason TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  processed_at TIMESTAMPTZ
);

-- 7. Refunds & Adjustments
CREATE TABLE IF NOT EXISTS public.refunds (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  payment_id UUID NOT NULL REFERENCES public.payments(id) ON DELETE RESTRICT,
  booking_id UUID NOT NULL REFERENCES public.bookings(id) ON DELETE RESTRICT,
  amount_paise BIGINT NOT NULL CHECK (amount_paise > 0),
  reason TEXT NOT NULL,
  status payment_status_type NOT NULL DEFAULT 'pending',
  razorpay_refund_id TEXT UNIQUE,
  initiated_by UUID NOT NULL REFERENCES public.profiles(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  processed_at TIMESTAMPTZ
);

-- Indexes for Financial & Ledger queries
CREATE INDEX IF NOT EXISTS idx_payments_booking ON public.payments(booking_id);
CREATE INDEX IF NOT EXISTS idx_payments_razorpay_order ON public.payments(razorpay_order_id);
CREATE INDEX IF NOT EXISTS idx_ledger_tx_ref ON public.ledger_transactions(transaction_ref);
CREATE INDEX IF NOT EXISTS idx_ledger_entries_tx ON public.ledger_entries(transaction_id);
CREATE INDEX IF NOT EXISTS idx_ledger_entries_labor ON public.ledger_entries(labor_id);
CREATE INDEX IF NOT EXISTS idx_cash_settlements_labor ON public.cash_settlements(labor_id);
CREATE INDEX IF NOT EXISTS idx_labor_payouts_labor ON public.labor_payouts(labor_id);
