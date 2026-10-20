-- CivilHand Seed Data
-- Module: Categories, Services, Pricing & Demo Data

-- 1. Service Categories
INSERT INTO public.service_categories (id, name, slug, icon_name, display_order, is_active) VALUES
  ('c1000000-0000-0000-0000-000000000001', 'Plumbing', 'plumbing', 'plumbing', 1, TRUE),
  ('c1000000-0000-0000-0000-000000000002', 'Electrical', 'electrical', 'bolt', 2, TRUE),
  ('c1000000-0000-0000-0000-000000000003', 'Carpentry', 'carpentry', 'handyman', 3, TRUE),
  ('c1000000-0000-0000-0000-000000000004', 'AC & Appliance Repair', 'ac-repair', 'ac_unit', 4, TRUE),
  ('c1000000-0000-0000-0000-000000000005', 'Home Cleaning', 'cleaning', 'cleaning_services', 5, TRUE),
  ('c1000000-0000-0000-0000-000000000006', 'Painting', 'painting', 'format_paint', 6, TRUE)
ON CONFLICT (slug) DO NOTHING;

-- 2. Services
INSERT INTO public.services (
  id, category_id, name, description, min_estimate_paise, max_estimate_paise,
  visiting_charge_paise, typical_duration_minutes, commission_percentage, fixed_platform_fee_paise
) VALUES
  -- Plumbing
  ('b1000000-0000-0000-0000-000000000001', 'c1000000-0000-0000-0000-000000000001', 'Tap & Mixer Repair / Replacement', 'Fix dripping taps, mixer leakage or new installation', 15000, 50000, 9900, 45, 15.00, 4900),
  ('b1000000-0000-0000-0000-000000000002', 'c1000000-0000-0000-0000-000000000001', 'Drainage & Pipe Blockage Clearance', 'Heavy duty unclogging of kitchen sink or bathroom drain', 25000, 90000, 9900, 60, 15.00, 4900),
  ('b1000000-0000-0000-0000-000000000003', 'c1000000-0000-0000-0000-000000000001', 'Water Tank & Motor Repair', 'Overhead tank float valve, pressure pump or piping check', 35000, 150000, 14900, 90, 15.00, 4900),

  -- Electrical
  ('b1000000-0000-0000-0000-000000000004', 'c1000000-0000-0000-0000-000000000002', 'Switchboard & Socket Wiring', 'Repair sparking switches, short-circuits or MCB trips', 15000, 60000, 9900, 45, 15.00, 4900),
  ('b1000000-0000-0000-0000-000000000005', 'c1000000-0000-0000-0000-000000000002', 'Fan & Light Fitting Installation', 'Ceiling fan hanging, decorative chandelier or LED tubes', 20000, 75000, 9900, 60, 15.00, 4900),

  -- Carpentry
  ('b1000000-0000-0000-0000-000000000006', 'c1000000-0000-0000-0000-000000000003', 'Door Lock & Handle Repair', 'Mortise lock installation, latch tightening or alignment', 20000, 80000, 9900, 60, 15.00, 4900),
  ('b1000000-0000-0000-0000-000000000007', 'c1000000-0000-0000-0000-000000000003', 'Furniture Assembly & Hinge Fix', 'Wardrobe hinges, bed assembly, chair stability repair', 30000, 120000, 14900, 90, 15.00, 4900),

  -- AC & Appliance
  ('b1000000-0000-0000-0000-000000000008', 'c1000000-0000-0000-0000-000000000004', 'Split / Window AC Deep Jet Servicing', 'Indoor cooling coil foaming, outdoor unit wash and filter clean', 49900, 120000, 19900, 60, 15.00, 4900),
  ('b1000000-0000-0000-0000-000000000009', 'c1000000-0000-0000-0000-000000000004', 'AC Gas Refill & Leak Testing', 'Refrigerant R32/R410A top-up and condenser brazing', 150000, 300000, 19900, 90, 15.00, 4900)
ON CONFLICT (id) DO NOTHING;
