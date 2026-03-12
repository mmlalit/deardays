// Supabase Edge Function: revenuecat-webhook
//
// Receives RevenueCat server-to-server webhook events and updates the
// user's subscription status in the `profiles` table.
//
// Setup:
//   1. Deploy: `supabase functions deploy revenuecat-webhook`
//   2. Set secrets:
//      supabase secrets set REVENUECAT_WEBHOOK_AUTH_KEY=your_shared_secret
//   3. In RevenueCat dashboard → Project → Integrations → Webhooks:
//      URL: https://<project-ref>.supabase.co/functions/v1/revenuecat-webhook
//      Authorization Header: Bearer <your_shared_secret>

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const WEBHOOK_AUTH_KEY = Deno.env.get("REVENUECAT_WEBHOOK_AUTH_KEY") ?? "";

// RevenueCat event types that indicate an active subscription.
const ACTIVE_EVENTS = new Set([
  "INITIAL_PURCHASE",
  "RENEWAL",
  "PRODUCT_CHANGE",    // upgrade / downgrade
  "UNCANCELLATION",
  "SUBSCRIBER_ALIAS",
]);

// Events that indicate subscription ended / will end.
const INACTIVE_EVENTS = new Set([
  "CANCELLATION",
  "EXPIRATION",
  "BILLING_ISSUE",
]);

Deno.serve(async (req: Request) => {
  // Only accept POST.
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  // Verify shared secret — ALWAYS required in production.
  // If the env var is missing, reject all requests to prevent unauthenticated
  // callers from modifying subscription status.
  if (!WEBHOOK_AUTH_KEY) {
    console.error("REVENUECAT_WEBHOOK_AUTH_KEY is not set. Rejecting request.");
    return new Response("Server misconfigured", { status: 500 });
  }

  const authHeader = req.headers.get("authorization") ?? "";
  if (authHeader !== `Bearer ${WEBHOOK_AUTH_KEY}`) {
    return new Response("Unauthorized", { status: 401 });
  }

  try {
    const body = await req.json();
    const event = body?.event;

    if (!event) {
      return new Response(JSON.stringify({ error: "No event in body" }), {
        status: 400,
        headers: { "Content-Type": "application/json" },
      });
    }

    const eventType: string = event.type;
    const appUserId: string | undefined = event.app_user_id;
    const productId: string | undefined =
      event.product_id ?? event.presented_offering_id;
    const expiresAtMs: number | undefined = event.expiration_at_ms;

    if (!appUserId) {
      return new Response(
        JSON.stringify({ error: "Missing app_user_id" }),
        { status: 400, headers: { "Content-Type": "application/json" } },
      );
    }

    // Determine the plan from the product ID.
    let plan: string | null = null;
    if (productId) {
      plan = productId.includes("yearly") || productId.includes("annual")
        ? "yearly"
        : "monthly";
    }

    // Determine expiration date.
    let expiresAt: string | null = null;
    if (expiresAtMs) {
      expiresAt = new Date(expiresAtMs).toISOString();
    }

    // Build the update payload.
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    if (ACTIVE_EVENTS.has(eventType)) {
      const { error } = await supabase
        .from("profiles")
        .update({
          is_subscribed: true,
          subscription_plan: plan,
          subscription_expires_at: expiresAt,
          revenuecat_customer_id: appUserId,
        })
        .eq("id", appUserId);

      if (error) {
        console.error("Supabase update error (active):", error);
        return new Response(JSON.stringify({ error: error.message }), {
          status: 500,
          headers: { "Content-Type": "application/json" },
        });
      }
    } else if (INACTIVE_EVENTS.has(eventType)) {
      // For CANCELLATION, the user keeps access until expiration.
      // For EXPIRATION, they lose access immediately.
      const isExpired = eventType === "EXPIRATION";

      const updatePayload: Record<string, unknown> = {
        is_subscribed: !isExpired,
        subscription_expires_at: expiresAt,
      };

      if (isExpired) {
        updatePayload.subscription_plan = null;
      }

      const { error } = await supabase
        .from("profiles")
        .update(updatePayload)
        .eq("id", appUserId);

      if (error) {
        console.error("Supabase update error (inactive):", error);
        return new Response(JSON.stringify({ error: error.message }), {
          status: 500,
          headers: { "Content-Type": "application/json" },
        });
      }
    }

    return new Response(
      JSON.stringify({ ok: true, event_type: eventType }),
      { status: 200, headers: { "Content-Type": "application/json" } },
    );
  } catch (err) {
    console.error("Webhook processing error:", err);
    return new Response(
      JSON.stringify({ error: "Internal server error" }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }
});
