// CivilHand Edge Function: payment-handler
// Handles Razorpay Orders, Webhooks, Cash Collection & Double-Entry Ledger Posting

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.4";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-razorpay-signature",
};

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const rzpKeyId = Deno.env.get("RAZORPAY_KEY_ID") || "rzp_test_placeholder";
    const rzpKeySecret = Deno.env.get("RAZORPAY_KEY_SECRET") || "secret_placeholder";
    const supabase = createClient(supabaseUrl, supabaseKey);

    // 1. Check for incoming Razorpay Webhook
    const rzpSignature = req.headers.get("x-razorpay-signature");
    if (rzpSignature) {
      const rawBody = await req.text();
      // Verify HMAC-SHA256 signature using native Web Crypto API
      const enc = new TextEncoder();
      const key = await crypto.subtle.importKey(
        "raw",
        enc.encode(rzpKeySecret),
        { name: "HMAC", hash: "SHA-256" },
        false,
        ["sign"]
      );
      const signatureBuffer = await crypto.subtle.sign("HMAC", key, enc.encode(rawBody));
      const expectedSignature = Array.from(new Uint8Array(signatureBuffer))
        .map((b) => b.toString(16).padStart(2, "0"))
        .join("");

      if (expectedSignature !== rzpSignature) {
        return new Response(JSON.stringify({ error: "Invalid webhook signature" }), { status: 400 });
      }

      const event = JSON.parse(rawBody);
      if (event.event === "payment.captured" || event.event === "order.paid") {
        const orderId = event.payload.payment.entity.order_id;
        const paymentId = event.payload.payment.entity.id;
        const amountPaise = event.payload.payment.entity.amount;

        // Fetch payment row
        const { data: payment } = await supabase
          .from("payments")
          .select("*, booking:bookings(*)")
          .eq("razorpay_order_id", orderId)
          .single();

        if (payment && payment.payment_status !== "captured") {
          await supabase
            .from("payments")
            .update({
              payment_status: "captured",
              razorpay_payment_id: paymentId,
              captured_at: new Date().toISOString(),
            })
            .eq("id", payment.id);

          await supabase
            .from("bookings")
            .update({ status: "PAID" })
            .eq("id", payment.booking_id);

          // Post balanced double-entry ledger journal
          // DR 1000 (Razorpay Clearing)
          // CR 4000 (Commission), CR 4100 (Fixed Fee), CR 2000 (Worker Payable)
          const { data: quote } = await supabase
            .from("booking_quotes")
            .select("*")
            .eq("id", payment.quote_id)
            .single();

          if (quote) {
            const { data: tx } = await supabase
              .from("ledger_transactions")
              .insert({
                transaction_ref: `TXN-ONLINE-${orderId}`,
                transaction_type: "BOOKING_ONLINE_PAYMENT",
                booking_id: payment.booking_id,
                payment_id: payment.id,
                description: `Online payment for booking ${payment.booking.booking_code}`,
              })
              .select()
              .single();

            if (tx) {
              // 1000: Asset (Razorpay Clearing)
              const { data: acc1000 } = await supabase.from("ledger_accounts").select("id").eq("code", "1000").single();
              // 4000: Revenue (Commission)
              const { data: acc4000 } = await supabase.from("ledger_accounts").select("id").eq("code", "4000").single();
              // 4100: Revenue (Fixed Fee)
              const { data: acc4100 } = await supabase.from("ledger_accounts").select("id").eq("code", "4100").single();
              // 2000: Liability (Professional Payable)
              const { data: acc2000 } = await supabase.from("ledger_accounts").select("id").eq("code", "2000").single();

              await supabase.from("ledger_entries").insert([
                // Debit total paid
                { transaction_id: tx.id, account_id: acc1000.id, customer_id: payment.booking.customer_id, debit_paise: amountPaise, credit_paise: 0 },
                // Credits: Commission + Fixed fee + Net worker earnings
                { transaction_id: tx.id, account_id: acc4000.id, debit_paise: 0, credit_paise: quote.commission_paise },
                { transaction_id: tx.id, account_id: acc4100.id, debit_paise: 0, credit_paise: quote.fixed_platform_fee_paise },
                { transaction_id: tx.id, account_id: acc2000.id, labor_id: payment.booking.labor_id, debit_paise: 0, credit_paise: quote.net_labor_paise },
              ]);
            }
          }
        }
      }

      return new Response(JSON.stringify({ status: "processed" }), { status: 200 });
    }

    // 2. Client API Actions
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) throw new Error("Missing authorization header");
    const { data: { user }, error: authErr } = await supabase.auth.getUser(authHeader.replace("Bearer ", ""));
    if (authErr || !user) throw new Error("Unauthorized");

    const body = await req.json();
    const { action, booking_id } = body;

    // A. Create Razorpay Online Order
    if (action === "create_razorpay_order") {
      const { data: booking } = await supabase
        .from("bookings")
        .select("*, quotes:booking_quotes(*)")
        .eq("id", booking_id)
        .single();

      if (!booking) throw new Error("Booking not found");
      const approvedQuote = booking.quotes?.find((q: any) => q.status === "approved");
      if (!approvedQuote) throw new Error("No approved quote found for this booking");

      const amountPaise = approvedQuote.total_customer_paise;

      // In real deployment: fetch from Razorpay API
      // const rzpRes = await fetch("https://api.razorpay.com/v1/orders", {
      //   method: "POST",
      //   headers: {
      //     "Content-Type": "application/json",
      //     Authorization: `Basic ${btoa(`${rzpKeyId}:${rzpKeySecret}`)}`,
      //   },
      //   body: JSON.stringify({ amount: amountPaise, currency: "INR", receipt: booking.booking_code }),
      // });
      // const rzpOrder = await rzpRes.json();
      const mockOrderId = `order_${Date.now().toString(36)}_${Math.random().toString(36).substring(2, 7)}`;

      const { data: payment, error: pErr } = await supabase
        .from("payments")
        .insert({
          booking_id,
          quote_id: approvedQuote.id,
          amount_paise: amountPaise,
          payment_method: "online_razorpay",
          razorpay_order_id: mockOrderId,
          payment_status: "pending",
        })
        .select()
        .single();

      if (pErr) throw pErr;

      return new Response(
        JSON.stringify({
          success: true,
          order_id: mockOrderId,
          amount_paise: amountPaise,
          key_id: rzpKeyId,
          booking_code: booking.booking_code,
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // B. Confirm Cash Payment
    if (action === "confirm_cash_payment") {
      const { data: booking } = await supabase
        .from("bookings")
        .select("*, quotes:booking_quotes(*)")
        .eq("id", booking_id)
        .single();

      if (!booking) throw new Error("Booking not found");
      const approvedQuote = booking.quotes?.find((q: any) => q.status === "approved");
      if (!approvedQuote) throw new Error("Quote must be approved before collecting cash");

      // Platform Dues from this cash booking = Commission + Fixed Platform Fee
      const platformDuesPaise = approvedQuote.commission_paise + approvedQuote.fixed_platform_fee_paise;
      const grossCashPaise = approvedQuote.total_customer_paise;

      // 1. Insert payment record
      const { data: payment } = await supabase
        .from("payments")
        .insert({
          booking_id,
          quote_id: approvedQuote.id,
          amount_paise: grossCashPaise,
          payment_method: "cash",
          payment_status: "captured",
          cash_collected_confirmed_by_worker: true,
          cash_collected_confirmed_by_customer: true,
          captured_at: new Date().toISOString(),
        })
        .select()
        .single();

      // 2. Post Double-Entry Ledger Journal
      // DR 1100 (Laborer Cash In Hand / Platform Receivable) : Commission + Fee
      // CR 4000 (Commission Revenue) : Commission
      // CR 4100 (Platform Fixed Fee Revenue) : Fee
      const { data: tx } = await supabase
        .from("ledger_transactions")
        .insert({
          transaction_ref: `TXN-CASH-${booking.booking_code}`,
          transaction_type: "BOOKING_CASH_COLLECTED",
          booking_id: booking.id,
          payment_id: payment.id,
          description: `Cash collection for booking ${booking.booking_code}`,
        })
        .select()
        .single();

      if (tx) {
        const { data: acc1100 } = await supabase.from("ledger_accounts").select("id").eq("code", "1100").single();
        const { data: acc4000 } = await supabase.from("ledger_accounts").select("id").eq("code", "4000").single();
        const { data: acc4100 } = await supabase.from("ledger_accounts").select("id").eq("code", "4100").single();

        await supabase.from("ledger_entries").insert([
          { transaction_id: tx.id, account_id: acc1100.id, labor_id: booking.labor_id, debit_paise: platformDuesPaise, credit_paise: 0 },
          { transaction_id: tx.id, account_id: acc4000.id, debit_paise: 0, credit_paise: approvedQuote.commission_paise },
          { transaction_id: tx.id, account_id: acc4100.id, debit_paise: 0, credit_paise: approvedQuote.fixed_platform_fee_paise },
        ]);
      }

      // 3. Update worker cash exposure & apply ₹5,000 soft-lock if threshold reached
      await supabase.rpc("update_labor_cash_exposure", {
        p_labor_id: booking.labor_id,
        p_additional_dues_paise: platformDuesPaise,
        p_gross_cash_paise: grossCashPaise,
      });

      // 4. Close booking
      await supabase
        .from("bookings")
        .update({ status: "CLOSED" })
        .eq("id", booking_id);

      return new Response(JSON.stringify({ success: true, status: "CLOSED", dues_added_paise: platformDuesPaise }), {
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
