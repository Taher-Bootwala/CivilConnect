// CivilHand Edge Function: respond-booking
// Handles worker acceptance or rejection with concurrency locking

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

    const { booking_id, action, rejection_reason } = await req.json(); // action: 'accept' | 'reject'

    if (!booking_id || !action) {
      return new Response(JSON.stringify({ error: "booking_id and action required" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 1. Fetch worker profile checks
    const { data: worker, error: workerErr } = await supabase
      .from("labor_profiles")
      .select("is_occupied, is_cash_locked, kyc_status")
      .eq("id", user.id)
      .single();

    if (workerErr || !worker) throw new Error("Worker profile not found");
    if (worker.kyc_status !== "verified") throw new Error("Worker KYC is not verified");
    if (worker.is_cash_locked) throw new Error("Cash limit exceeded; settle platform dues to accept jobs");
    if (worker.is_occupied && action === "accept") throw new Error("Worker already has an active in-progress job");

    // 2. Fetch booking and verify state
    const { data: booking, error: bErr } = await supabase
      .from("bookings")
      .select("id, status, labor_id, service_id, service_location")
      .eq("id", booking_id)
      .single();

    if (bErr || !booking) throw new Error("Booking not found");

    if (action === "accept") {
      if (booking.status !== "REQUESTED") {
        return new Response(JSON.stringify({ error: "Booking is no longer available" }), {
          status: 409,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }

      // Update booking to ACCEPTED
      const { error: updateErr } = await supabase
        .from("bookings")
        .update({
          labor_id: user.id,
          status: "ACCEPTED",
          accepted_at: new Date().toISOString(),
        })
        .eq("id", booking_id)
        .eq("status", "REQUESTED"); // Atomic conditional update

      if (updateErr) throw updateErr;

      return new Response(JSON.stringify({ success: true, status: "ACCEPTED" }), {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    } else if (action === "reject") {
      // Worker rejected: release labor_id and search next fallback worker
      await supabase
        .from("bookings")
        .update({
          labor_id: null,
          dispatched_at: null,
        })
        .eq("id", booking_id);

      return new Response(JSON.stringify({ success: true, status: "REJECTED_AND_REQUEUED" }), {
        status: 200,
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
