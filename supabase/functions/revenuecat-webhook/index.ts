// Supabase Edge Function: RevenueCat Webhook Handler
// SECURITY: Verifies webhook authenticity before updating subscription status
//
// Setup in RevenueCat Dashboard:
// 1. Go to Project Settings > Integrations > Webhooks
// 2. Add webhook URL: https://<project>.supabase.co/functions/v1/revenuecat-webhook
// 3. Set Authorization header to the value of REVENUECAT_WEBHOOK_SECRET
//
// Setup in Supabase:
// supabase secrets set REVENUECAT_WEBHOOK_SECRET=your-secret-here

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const REVENUECAT_WEBHOOK_SECRET = Deno.env.get("REVENUECAT_WEBHOOK_SECRET");

// RevenueCat event types that indicate active subscription
const ACTIVE_EVENTS = [
  "INITIAL_PURCHASE",
  "RENEWAL",
  "UNCANCELLATION",
  "NON_RENEWING_PURCHASE",
  "SUBSCRIPTION_EXTENDED",
  "PRODUCT_CHANGE", // Upgrade/downgrade - check entitlements
];

// RevenueCat event types that indicate inactive subscription
const INACTIVE_EVENTS = [
  "CANCELLATION",
  "EXPIRATION",
  "BILLING_ISSUE",
  "SUBSCRIPTION_PAUSED",
];

// Events to track but not necessarily update status
const INFO_EVENTS = [
  "TRANSFER",
  "TEST", // Test events from RevenueCat dashboard
];

interface RevenueCatWebhook {
  api_version: string;
  event: {
    aliases: string[];
    app_id: string;
    app_user_id: string;
    commission_percentage: number;
    country_code: string;
    currency: string;
    entitlement_id: string | null;
    entitlement_ids: string[] | null;
    environment: "SANDBOX" | "PRODUCTION";
    event_timestamp_ms: number;
    expiration_at_ms: number | null;
    id: string;
    is_family_share: boolean;
    offer_code: string | null;
    original_app_user_id: string;
    original_transaction_id: string;
    period_type: string;
    presented_offering_id: string | null;
    price: number;
    price_in_purchased_currency: number;
    product_id: string;
    purchased_at_ms: number;
    store: string;
    subscriber_attributes: Record<string, { value: string; updated_at_ms: number }>;
    takehome_percentage: number;
    tax_percentage: number;
    transaction_id: string;
    type: string;
  };
}

Deno.serve(async (req: Request) => {
  // Only accept POST requests
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { "Content-Type": "application/json" },
    });
  }

  // Verify webhook secret
  const authHeader = req.headers.get("Authorization");
  if (!REVENUECAT_WEBHOOK_SECRET) {
    console.error("REVENUECAT_WEBHOOK_SECRET not configured");
    return new Response(JSON.stringify({ error: "Server misconfigured" }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  // RevenueCat sends: "Bearer <secret>" in Authorization header
  const expectedAuth = `Bearer ${REVENUECAT_WEBHOOK_SECRET}`;
  if (authHeader !== expectedAuth) {
    console.error("Invalid webhook authorization");
    return new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    });
  }

  // Parse webhook payload
  let payload: RevenueCatWebhook;
  try {
    payload = await req.json();
  } catch {
    return new Response(JSON.stringify({ error: "Invalid JSON" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  const event = payload.event;
  if (!event) {
    return new Response(JSON.stringify({ error: "Missing event data" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  console.log(`RevenueCat webhook: ${event.type} for user ${event.app_user_id}`);

  // Create Supabase client with service role (bypasses RLS)
  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

  // Log the webhook event for audit trail
  await supabase.from("subscription_webhook_events").insert({
    revenuecat_app_user_id: event.app_user_id,
    event_type: event.type,
    product_id: event.product_id,
    entitlement_id: event.entitlement_id,
    expiration_at: event.expiration_at_ms
      ? new Date(event.expiration_at_ms).toISOString()
      : null,
    environment: event.environment,
    raw_payload: payload,
  });

  // The app_user_id should be the Supabase user ID
  // This is set when calling RevenueCatService.login(supabaseUserId)
  const supabaseUserId = event.app_user_id;

  // Validate it looks like a UUID (Supabase user IDs are UUIDs)
  const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
  if (!uuidRegex.test(supabaseUserId)) {
    console.log(`app_user_id is not a Supabase UUID: ${supabaseUserId}, checking aliases`);

    // Check aliases for a UUID (RevenueCat anonymous ID might be primary)
    const aliasUuid = event.aliases?.find((alias) => uuidRegex.test(alias));
    if (!aliasUuid) {
      console.error(`No valid Supabase user ID found in app_user_id or aliases`);
      // Still return 200 to not trigger retries for invalid users
      return new Response(JSON.stringify({ success: true, skipped: "no_valid_user_id" }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    }
  }

  // Determine subscription status based on event type
  let isActive = false;
  let tier: "free" | "pro" = "free";

  if (ACTIVE_EVENTS.includes(event.type)) {
    isActive = true;
    tier = "pro";
  } else if (INACTIVE_EVENTS.includes(event.type)) {
    isActive = false;
    tier = "free"; // Could keep as 'pro' with isActive=false if you want to show "expired pro"
  } else if (INFO_EVENTS.includes(event.type)) {
    // For info events, just log and return success
    console.log(`Info event ${event.type}, no status update needed`);
    return new Response(JSON.stringify({ success: true, event_type: event.type }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } else {
    console.log(`Unknown event type: ${event.type}`);
  }

  // Check for specific entitlement (your pro entitlement ID)
  const proEntitlementId = "Chukdoo Pro"; // Must match AppConstants.proEntitlementId
  const hasProEntitlement =
    event.entitlement_id === proEntitlementId ||
    event.entitlement_ids?.includes(proEntitlementId);

  if (!hasProEntitlement && ACTIVE_EVENTS.includes(event.type)) {
    console.log(`Event ${event.type} but not for pro entitlement, skipping`);
    return new Response(JSON.stringify({ success: true, skipped: "wrong_entitlement" }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  }

  // Upsert subscription record
  const subscriptionData = {
    user_id: supabaseUserId,
    revenuecat_app_user_id: event.original_app_user_id || event.app_user_id,
    tier,
    is_active: isActive,
    expires_at: event.expiration_at_ms
      ? new Date(event.expiration_at_ms).toISOString()
      : null,
    product_identifier: event.product_id,
    entitlement_id: event.entitlement_id || proEntitlementId,
    original_purchase_date: event.purchased_at_ms
      ? new Date(event.purchased_at_ms).toISOString()
      : null,
    last_webhook_at: new Date().toISOString(),
  };

  const { error } = await supabase
    .from("user_subscriptions")
    .upsert(subscriptionData, { onConflict: "user_id" });

  if (error) {
    console.error("Failed to update subscription:", error);
    return new Response(JSON.stringify({ error: "Database error" }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  console.log(`Subscription updated: user=${supabaseUserId}, tier=${tier}, active=${isActive}`);

  return new Response(
    JSON.stringify({
      success: true,
      user_id: supabaseUserId,
      tier,
      is_active: isActive,
    }),
    {
      status: 200,
      headers: { "Content-Type": "application/json" },
    }
  );
});
