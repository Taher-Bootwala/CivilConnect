// CivilHand Edge Function: admin-dispute-resolution
// Handles Authorized Admin Quote Dispute Arbitration & Financial Adjustments

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.4";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, supabaseKey);

    // Verify admin role
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) throw new Error("Missing authorization header");
    const { data: { user }, error: authErr } = await supabase.auth.getUser(authHeader.replace("Bearer ", ""));
    if (authErr || !user) throw new Error("Unauthorized");

    const { data: profile } = await supabase
      .from("profiles")
      .select("role")
      .eq("id", user.id)
      .single();

    if (!profile || profile.role !== "admin") {
      return new Response(JSON.stringify({ error: "Forbidden: Admin privileges required" }), {
        status: 403,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const body = await req.json();
    const {
      dispute_id,
      final_labor_paise,
      final_material_paise,
      admin_resolution_note,
    } = body;

    if (!dispute_id || !admin_resolution_note || final_labor_paise === undefined) {
      return new Response(
        JSON.stringify({ error: "dispute_id, final_labor_paise, and admin_resolution_note are mandatory" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 1. Fetch dispute & booking
    const { data: dispute, error: dErr } = await supabase
      .from("disputes")
      .select("*, booking:bookings(*, service:services(*)), quote:booking_quotes(*)")
      .eq("id", dispute_id)
      .single();

    if (dErr || !dispute) throw new Error("Dispute not found");

    const booking = dispute.booking;
    const oldQuote = dispute.quote;

    // 2. Re-calculate financial totals with admin overrides
    const commPct = Number(booking.service.commission_percentage);
    const fixedFee = Number(booking.service.fixed_platform_fee_paise);
    const visiting = Number(oldQuote.visiting_charge_paise);
    const labor = Number(final_labor_paise);
    const material = Number(final_material_paise ?? oldQuote.material_charge_paise);

    const commissionPaise = Math.round(((labor + visiting) * commPct) / 100);
    const totalCustomerPaise = labor + material + visiting + fixedFee;
    const netLaborPaise = (labor + material + visiting) - commissionPaise;

    // 3. Update quote to approved with admin-arbitrated snapshot
    await supabase
      .from("booking_quotes")
      .update({
        labor_charge_paise: labor,
        material_charge_paise: material,
        commission_paise: commissionPaise,
        total_customer_paise: totalCustomerPaise,
        net_labor_paise: netLaborPaise,
        status: "approved",
        customer_response_note: `Resolved by admin: ${admin_resolution_note}`,
        responded_at: new Date().toISOString(),
      })
      .eq("id", oldQuote.id);

    // 4. Update dispute record
    await supabase
      .from("disputes")
      .update({
        status: "resolved_by_admin",
        admin_resolution_note: admin_resolution_note,
        resolved_by: user.id,
        resolved_at: new Date().toISOString(),
      })
      .eq("id", dispute_id);

    // 5. Transition booking state to PAYMENT_PENDING
    await supabase
      .from("bookings")
      .update({ status: "PAYMENT_PENDING" })
      .eq("id", booking.id);

    // 6. Record immutable audit log
    await supabase.from("audit_logs").insert({
      actor_id: user.id,
      action: "RESOLVE_DISPUTE",
      entity_type: "disputes",
      entity_id: dispute_id,
      old_data: { quote_total: oldQuote.total_customer_paise },
      new_data: {
        new_total: totalCustomerPaise,
        labor: labor,
        material: material,
        note: admin_resolution_note,
      },
    });

    return new Response(
      JSON.stringify({
        success: true,
        dispute_id: dispute_id,
        booking_id: booking.id,
        total_customer_paise: totalCustomerPaise,
        status: "resolved_by_admin",
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err: any) {
    return new Response(JSON.stringify({ error: err.message || "Internal error" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
