// CivilHand Edge Function: send-worker-approval-email
// Dispatches account confirmation emails via Brevo (Sendinblue) or Resend
// Triggered when an admin verifies/approves a labor/tradesperson profile

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
    const brevoApiKey = Deno.env.get("BREVO_API_KEY");
    const resendApiKey = Deno.env.get("RESEND_API_KEY");
    const senderEmail = Deno.env.get("SENDER_EMAIL") || "no-reply@civilhand.in";
    const senderName = "CivilHand Pro Network";

    const supabase = createClient(supabaseUrl, supabaseKey);
    const body = await req.json();

    const { labor_id, worker_email, worker_name, skills = [] } = body;

    let targetEmail = worker_email;
    let targetName = worker_name || "Professional";

    // If labor_id is provided without email/name, fetch from database
    if (labor_id && (!targetEmail || !targetName)) {
      const { data: profile } = await supabase
        .from("profiles")
        .select("full_name, email, phone")
        .eq("id", labor_id)
        .single();

      if (profile) {
        targetEmail = targetEmail || profile.email;
        targetName = targetName || profile.full_name;
      }
    }

    if (!targetEmail) {
      return new Response(JSON.stringify({ error: "Worker email is required" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const skillsHtml = (skills && skills.length > 0)
      ? `<ul>${skills.map((s: string) => `<li style="margin-bottom: 4px;"><strong>${s}</strong></li>`).join("")}</ul>`
      : `<p>Your registered trade skills have been approved.</p>`;

    const emailHtml = `
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8">
        <style>
          body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background-color: #f8fafc; margin: 0; padding: 24px; color: #1e293b; }
          .container { max-width: 580px; margin: 0 auto; background: #ffffff; border-radius: 16px; overflow: hidden; border: 1px solid #e2e8f0; }
          .header { background: #4f46e5; padding: 32px 24px; text-align: center; color: #ffffff; }
          .header h1 { margin: 0; font-size: 24px; font-weight: 800; }
          .content { padding: 32px 24px; }
          .badge { display: inline-block; background: #ecfdf5; color: #059669; font-weight: 700; padding: 6px 14px; border-radius: 9999px; font-size: 13px; margin-bottom: 20px; }
          .cta-btn { display: inline-block; background: #4f46e5; color: #ffffff; font-weight: 700; text-decoration: none; padding: 14px 28px; border-radius: 12px; margin-top: 24px; text-align: center; }
          .footer { padding: 20px 24px; font-size: 12px; color: #64748b; text-align: center; border-top: 1px solid #f1f5f9; background: #fafafa; }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <h1>CivilHand Professional</h1>
          </div>
          <div class="content">
            <span class="badge">✓ ACCOUNT OFFICIALLY CONFIRMED</span>
            <h2>Welcome to the Network, ${targetName}!</h2>
            <p>Great news! Your CivilHand professional partner account and Aadhaar KYC have been verified and approved by our onboarding team.</p>
            <p><strong>Approved Trade Skills:</strong></p>
            ${skillsHtml}
            <p>You can now toggle your status to <strong>Online</strong> in the CivilHand app, receive instant local dispatch calls, quote jobs, and accept verified bookings directly.</p>
            <div style="text-align: center;">
              <a href="civilhand://partner/dashboard" class="cta-btn">Open Partner App & Start Earning</a>
            </div>
            <p style="margin-top: 28px; font-size: 13px; color: #64748b;">
              Note: Payouts are transferred automatically to your registered bank account / UPI daily.
            </p>
          </div>
          <div class="footer">
            &copy; ${new Date().getFullYear()} CivilHand Services Pvt. Ltd. All rights reserved.
          </div>
        </div>
      </body>
      </html>
    `;

    let providerResponse = null;
    let providerUsed = "none";

    // 1. Try Brevo (Sendinblue) if API key exists
    if (brevoApiKey) {
      providerUsed = "brevo";
      const brevoRes = await fetch("https://api.brevo.com/v3/smtp/email", {
        method: "POST",
        headers: {
          "api-key": brevoApiKey,
          "Content-Type": "application/json",
          Accept: "application/json",
        },
        body: JSON.stringify({
          sender: { name: senderName, email: senderEmail },
          to: [{ email: targetEmail, name: targetName }],
          subject: "🎉 Your CivilHand Professional Account is Approved! Start Accepting Jobs",
          htmlContent: emailHtml,
        }),
      });
      providerResponse = await brevoRes.json();
    } 
    // 2. Alternatively, try Resend if API key exists
    else if (resendApiKey) {
      providerUsed = "resend";
      const resendRes = await fetch("https://api.resend.com/emails", {
        method: "POST",
        headers: {
          Authorization: `Bearer ${resendApiKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          from: `${senderName} <${senderEmail}>`,
          to: [targetEmail],
          subject: "🎉 Your CivilHand Professional Account is Approved! Start Accepting Jobs",
          html: emailHtml,
        }),
      });
      providerResponse = await resendRes.json();
    } else {
      // In local development / demo mode when keys are not configured
      providerUsed = "mock_simulation";
      providerResponse = {
        mock_sent: true,
        to: targetEmail,
        note: "Neither BREVO_API_KEY nor RESEND_API_KEY was found in environment. Email simulated successfully.",
      };
    }

    return new Response(
      JSON.stringify({
        success: true,
        provider: providerUsed,
        recipient: targetEmail,
        response: providerResponse,
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err: any) {
    return new Response(JSON.stringify({ error: err.message || "Failed to send approval email" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
