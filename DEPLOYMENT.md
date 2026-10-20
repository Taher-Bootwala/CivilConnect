# CivilHand: Production Deployment & System Runbook

This guide covers deployment procedures for **CivilHand** — an on-demand verified home services marketplace for India.

---

## 1. Architecture Overview

- **Mobile Client**: Flutter (Android & iOS) utilizing Riverpod state management and Supabase Realtime SDK.
- **Admin Console**: Next.js 14, React 18, and Tailwind CSS.
- **Backend & Database**: Supabase PostgreSQL with PostGIS proximity queries, RLS security policies, and transactional triggers.
- **Serverless API**: Supabase Deno Edge Functions for privileged operations (booking dispatch, OTP generation, quotes, payments, payouts).
- **Payment Processing**: Razorpay Orders, HMAC-SHA256 signed webhooks, and double-entry accounting.
- **Storage**: Private Cloudinary & Supabase Storage buckets for KYC identity documents and work before/after photos.

---

## 2. Environment Variables & Secrets

### Mobile Application (`lib/core/constants.dart`)
Compile-time Dart defines (`--dart-define`):
```bash
flutter run \
  --dart-define=SUPABASE_URL=https://<your-project>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<your-anon-key> \
  --dart-define=CLOUDINARY_CLOUD_NAME=<your-cloud-name> \
  --dart-define=CLOUDINARY_UPLOAD_PRESET=<your-preset>
```

### Supabase Edge Functions Secrets
Configure using the Supabase CLI:
```bash
supabase secrets set \
  RAZORPAY_KEY_ID="rzp_live_xxxxxxxxxxxx" \
  RAZORPAY_KEY_SECRET="your_live_secret" \
  FCM_SERVER_KEY="your_firebase_cloud_messaging_key" \
  SUPABASE_SERVICE_ROLE_KEY="your_service_role_key"
```

---

## 3. Database Migration Deployment

### Option A: 1-Click Cloud Setup (Recommended)
Copy the entire contents of [`supabase/full_schema_setup.sql`](file:///d:/GTU/Projects/Nirav%20sir/civilhand/supabase/full_schema_setup.sql) and paste it into your Supabase Dashboard **SQL Editor**, then click **Run**.

### Option B: Supabase CLI Migrations
```bash
supabase db push
```
This applies the migration sequence:
1. `00001_initial_schema.sql` (PostGIS, canonical profiles, bookings, quotes)
2. `00002_ledger_and_accounting.sql` (Double-entry COA, journal headers & lines)
3. `00003_functions_and_triggers.sql` (Bayesian rating, state machine, proximity query)
4. `00004_row_level_security.sql` (Role-based access control policies)
5. `00005_seed_data.sql` (Initial service categories and price estimates)
6. `00006_auxiliary_and_compliance.sql` (FCM tokens, schedules, support tickets, audit logs)

---

## 4. Deploying Edge Functions

Deploy each function to your remote Supabase project:
```bash
supabase functions deploy dispatch-booking
supabase functions deploy respond-booking
supabase functions deploy verify-job
supabase functions deploy quote-lifecycle
supabase functions deploy payment-handler
supabase functions deploy payout-handler
supabase functions deploy notification-dispatcher
supabase functions deploy admin-dispute-resolution
```

---

## 5. Razorpay Webhook Configuration

In the Razorpay Dashboard (`Settings > Webhooks`):
- **Webhook URL**: `https://<your-project>.supabase.co/functions/v1/payment-handler`
- **Secret**: Must match your `RAZORPAY_KEY_SECRET`.
- **Subscribed Events**:
  - `payment.captured`
  - `order.paid`
  - `payment.failed`
  - `payout.processed`

---

## 6. Next.js Admin Dashboard Deployment

The admin console is located in [`admin-dashboard/`](file:///d:/GTU/Projects/Nirav%20sir/civilhand/admin-dashboard).

### Local Development:
```bash
cd admin-dashboard
npm install
npm run dev
```

### Production Build / Vercel:
```bash
npm run build
npm start
```
Configure environment variables:
- `NEXT_PUBLIC_SUPABASE_URL`
- `NEXT_PUBLIC_SUPABASE_ANON_KEY`

---

## 7. Testing & Verification

Run the automated test suite locally:
```bash
flutter test
```
Verifies:
- Integer paise financial precision
- Double-entry debit/credit balancing
- ₹5,000 cash limit warning & soft lock triggers
- Booking state machine transition rules and terminal immutability
