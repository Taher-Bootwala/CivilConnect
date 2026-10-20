// CivilHand Edge Function: dispatch-booking
// Handles customer booking creation, start-OTP generation, and nearby tradesperson matching

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

    // Verify authenticated caller
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) throw new Error("Missing authorization header");
    const { data: { user }, error: authErr } = await supabase.auth.getUser(authHeader.replace("Bearer ", ""));
    if (authErr || !user) throw new Error("Unauthorized");

    const body = await req.json();
    const {
      service_id,
      latitude,
      longitude,
      address_snapshot,
      address_landmark,
      problem_description,
      problem_photos = [],
      scheduled_at,
      dispatch_mode = "auto", // 'auto' or 'manual'
      selected_labor_id = null,
    } = body;

    if (!service_id || !latitude || !longitude || !problem_description) {
      return new Response(JSON.stringify({ error: "Missing required fields" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 1. Generate secure 4-digit start OTP
    const rawOtp = Math.floor(1000 + Math.random() * 9000).toString();
    // Compute SHA-256 hash using Web Crypto API (native standard library)
    const msgBuffer = new TextEncoder().encode(rawOtp);
    const hashBuffer = await crypto.subtle.digest("SHA-256", msgBuffer);
    const hashArray = Array.from(new Uint8Array(hashBuffer));
    const otpHash = hashArray.map((b) => b.toString(16).padStart(2, "0")).join("");

    // Unique human-readable booking code: e.g. CH-2026-XXXXX
    const bookingCode = `CH-${Date.now().toString(36).toUpperCase()}-${Math.floor(100 + Math.random() * 900)}`;

    // 2. Insert booking in requested state
    const pointWkt = `POINT(${longitude} ${latitude})`;
    const { data: booking, error: bookErr } = await supabase
      .from("bookings")
      .insert({
        booking_code: bookingCode,
        customer_id: user.id,
        service_id,
        service_location: pointWkt,
        address_snapshot,
        address_landmark,
        problem_description,
        problem_photos,
        start_otp_hash: otpHash,
        dispatch_mode,
        status: "REQUESTED",
        scheduled_at: scheduled_at || new Date().toISOString(),
        labor_id: selected_labor_id,
      })
      .select()
      .single();

    if (bookErr) throw bookErr;

    // 3. Match nearby professionals if auto dispatch
    let eligiblePros = [];
    if (dispatch_mode === "auto" && !selected_labor_id) {
      const { data: pros, error: proErr } = await supabase.rpc("find_nearby_eligible_pros", {
        p_latitude: latitude,
        p_longitude: longitude,
        p_service_id: service_id,
        p_max_distance_meters: 15000,
        p_limit: 10,
      });

      if (!proErr && pros && pros.length > 0) {
        eligiblePros = pros;
        // Assign to top Bayesian-ranked pro
        const topPro = pros[0];
        await supabase
          .from("bookings")
          .update({
            labor_id: topPro.labor_id,
            dispatched_at: new Date().toISOString(),
          })
          .eq("id", booking.id);
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        booking_id: booking.id,
        booking_code: bookingCode,
        start_otp: rawOtp, // Returned to customer to display securely
        assigned_pro: selected_labor_id || (eligiblePros[0]?.labor_id ?? null),
        nearby_pros_count: eligiblePros.length,
      }),
      { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err: any) {
    return new Response(JSON.stringify({ error: err.message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
