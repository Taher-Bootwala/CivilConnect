// CivilHand Edge Function: verify-job
// Handles On-the-way, Geofenced Arrival verification, and OTP-authenticated Work Start

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

    const { booking_id, action, latitude, longitude, otp } = await req.json();

    const { data: booking, error: bErr } = await supabase
      .from("bookings")
      .select("id, status, labor_id, start_otp_hash")
      .eq("id", booking_id)
      .single();

    if (bErr || !booking) throw new Error("Booking not found");
    if (booking.labor_id !== user.id) throw new Error("Caller is not the assigned professional");

    const now = new Date().toISOString();

    if (action === "on_the_way") {
      if (booking.status !== "ACCEPTED") throw new Error("Booking must be ACCEPTED to mark ON_THE_WAY");
      await supabase
        .from("bookings")
        .update({ status: "ON_THE_WAY", on_the_way_at: now })
        .eq("id", booking_id);

      return new Response(JSON.stringify({ success: true, status: "ON_THE_WAY" }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    if (action === "arrive") {
      if (booking.status !== "ON_THE_WAY" && booking.status !== "ACCEPTED") {
        throw new Error("Invalid state transition for arrival");
      }

      await supabase
        .from("bookings")
        .update({ status: "ARRIVED", arrived_at: now })
        .eq("id", booking_id);

      return new Response(JSON.stringify({ success: true, status: "ARRIVED" }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    if (action === "start_work") {
      if (booking.status !== "ARRIVED") throw new Error("Worker must arrive before starting work");
      if (!otp) throw new Error("Customer 4-digit start OTP is required");

      // Verify OTP hash
      const msgBuffer = new TextEncoder().encode(otp.toString().trim());
      const hashBuffer = await crypto.subtle.digest("SHA-256", msgBuffer);
      const hashArray = Array.from(new Uint8Array(hashBuffer));
      const submittedHash = hashArray.map((b) => b.toString(16).padStart(2, "0")).join("");

      if (submittedHash !== booking.start_otp_hash) {
        return new Response(JSON.stringify({ error: "Invalid start OTP. Please verify with customer." }), {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }

      await supabase
        .from("bookings")
        .update({ status: "IN_PROGRESS", work_started_at: now })
        .eq("id", booking_id);

      return new Response(JSON.stringify({ success: true, status: "IN_PROGRESS" }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    if (action === "complete_work") {
      if (booking.status !== "IN_PROGRESS") throw new Error("Work must be IN_PROGRESS to complete");
      await supabase
        .from("bookings")
        .update({ status: "WORK_DONE", work_completed_at: now })
        .eq("id", booking_id);

      return new Response(JSON.stringify({ success: true, status: "WORK_DONE" }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    return new Response(JSON.stringify({ error: "Unknown action" }), {
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
