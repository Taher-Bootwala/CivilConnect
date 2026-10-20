// CivilHand Edge Function: notification-dispatcher
// Handles FCM Push Notifications & In-App Notification Storage

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
    const fcmServerKey = Deno.env.get("FCM_SERVER_KEY") || "dummy_fcm_key";
    const supabase = createClient(supabaseUrl, supabaseKey);

    const { user_id, title, body, notification_type, data = {} } = await req.json();

    if (!user_id || !title || !body) {
      return new Response(JSON.stringify({ error: "user_id, title, and body are required" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 1. Persist notification in database inbox (source of truth)
    const { data: dbNotification, error: dbErr } = await supabase
      .from("notifications")
      .insert({
        user_id: user_id,
        title: title,
        body: body,
        notification_type: notification_type || "general",
        data: data,
        is_read: false,
      })
      .select()
      .single();

    if (dbErr) throw dbErr;

    // 2. Query active FCM device tokens for this user
    const { data: tokens } = await supabase
      .from("device_tokens")
      .select("fcm_token")
      .eq("user_id", user_id)
      .eq("is_active", true);

    const fcmResults = [];

    // 3. Dispatch to Firebase Cloud Messaging (FCM)
    if (tokens && tokens.length > 0 && fcmServerKey !== "dummy_fcm_key") {
      for (const t of tokens) {
        try {
          const fcmPayload = {
            to: t.fcm_token,
            notification: {
              title: title,
              body: body,
              sound: "default",
            },
            data: {
              ...data,
              notification_id: dbNotification.id,
              notification_type: notification_type,
            },
          };

          const res = await fetch("https://fcm.googleapis.com/fcm/send", {
            method: "POST",
            headers: {
              Authorization: `key=${fcmServerKey}`,
              "Content-Type": "application/json",
            },
            body: JSON.stringify(fcmPayload),
          });

          fcmResults.push({ token: t.fcm_token, status: res.status });
        } catch (fcmErr: any) {
          fcmResults.push({ token: t.fcm_token, error: fcmErr.message });
        }
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        notification: dbNotification,
        dispatched_tokens_count: tokens?.length || 0,
        fcm_results: fcmResults,
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
