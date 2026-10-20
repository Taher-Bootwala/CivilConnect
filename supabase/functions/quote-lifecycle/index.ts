// CivilHand Edge Function: quote-lifecycle
// Handles quote calculation, submission by professional, and customer approval/dispute loop

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

    const authHeader = req.headers.get("Authorization");
    if (!authHeader) throw new Error("Missing authorization");
    const { data: { user }, error: authErr } = await supabase.auth.getUser(authHeader.replace("Bearer ", ""));
    if (authErr || !user) throw new Error("Unauthorized");

    const body = await req.json();
    const { action, booking_id } = body;

    // Fetch booking
    const { data: booking, error: bErr } = await supabase
      .from("bookings")
      .select("*, service:services(*)")
      .eq("id", booking_id)
      .single();

    if (bErr || !booking) throw new Error("Booking not found");

    if (action === "submit_quote") {
      if (booking.labor_id !== user.id) throw new Error("Only assigned worker can submit quote");
      if (booking.status !== "WORK_DONE" && booking.status !== "DISPUTED") {
        throw new Error("Work must be finished before submitting quote");
      }

      const {
        labor_charge_paise,
        material_charge_paise = 0,
        visiting_charge_paise = 0,
        explanation_note,
        before_photos = [],
        after_photos = [],
        material_receipt_photos = [],
      } = body;

      if (!labor_charge_paise || labor_charge_paise < 0) {
        throw new Error("Valid labor charge is required");
      }

      // Backend-authoritative financial calculation
      const commPct = Number(booking.service.commission_percentage);
      const fixedFee = Number(booking.service.fixed_platform_fee_paise);

      // Commission charged only on labor + visiting charge (materials pass through without commission)
      const commissionBasis = labor_charge_paise + visiting_charge_paise;
      const commissionPaise = Math.round((commissionBasis * commPct) / 100);
      const taxPaise = 0; // Tax configurable

      const totalCustomerPaise = labor_charge_paise + material_charge_paise + visiting_charge_paise + fixedFee + taxPaise;
      const netLaborPaise = (labor_charge_paise + material_charge_paise + visiting_charge_paise) - commissionPaise;

      // Check current quote version
      const { count } = await supabase
        .from("booking_quotes")
        .select("*", { count: "exact", head: true })
        .eq("booking_id", booking_id);

      const version = (count || 0) + 1;

      const { data: quote, error: qErr } = await supabase
        .from("booking_quotes")
        .insert({
          booking_id,
          labor_id: user.id,
          version,
          labor_charge_paise,
          material_charge_paise,
          visiting_charge_paise,
          fixed_platform_fee_paise: fixedFee,
          commission_paise: commissionPaise,
          tax_paise: taxPaise,
          total_customer_paise: totalCustomerPaise,
          net_labor_paise: netLaborPaise,
          explanation_note,
          before_photos,
          after_photos,
          material_receipt_photos,
          status: "pending",
        })
        .select()
        .single();

      if (qErr) throw qErr;

      await supabase
        .from("bookings")
        .update({ status: "AMOUNT_PENDING_APPROVAL" })
        .eq("id", booking_id);

      return new Response(JSON.stringify({ success: true, quote }), {
        status: 201,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    if (action === "approve_quote") {
      if (booking.customer_id !== user.id) throw new Error("Only the customer can approve the quote");

      const { quote_id } = body;
      const { data: quote, error: qErr } = await supabase
        .from("booking_quotes")
        .select("*")
        .eq("id", quote_id)
        .eq("booking_id", booking_id)
        .single();

      if (qErr || !quote) throw new Error("Quote not found");
      if (quote.status !== "pending") throw new Error("Quote is not pending approval");

      await supabase
        .from("booking_quotes")
        .update({ status: "approved", responded_at: new Date().toISOString() })
        .eq("id", quote_id);

      await supabase
        .from("bookings")
        .update({ status: "PAYMENT_PENDING" })
        .eq("id", booking_id);

      return new Response(JSON.stringify({ success: true, status: "PAYMENT_PENDING" }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    if (action === "dispute_quote") {
      if (booking.customer_id !== user.id) throw new Error("Only the customer can dispute the quote");

      const { quote_id, reason, counter_amount_paise } = body;
      if (!reason) throw new Error("Dispute reason is required");

      await supabase
        .from("booking_quotes")
        .update({ status: "disputed", customer_response_note: reason, responded_at: new Date().toISOString() })
        .eq("id", quote_id);

      await supabase.from("disputes").insert({
        booking_id,
        quote_id,
        raised_by: user.id,
        reason,
        proposed_counter_amount_paise: counter_amount_paise || null,
        status: "open",
      });

      await supabase
        .from("bookings")
        .update({ status: "DISPUTED" })
        .eq("id", booking_id);

      return new Response(JSON.stringify({ success: true, status: "DISPUTED" }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    return new Response(JSON.stringify({ error: "Invalid action" }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err: any) {
    return new Response(JSON.stringify({ error: err.message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
