import Stripe from "npm:stripe@17";
import { createClient } from "jsr:@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";
import { AuthMiddleware } from "../_shared/jwt.ts";

Deno.serve((req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  return AuthMiddleware(req, async (_req, userId) => {
    console.log(`[cancel-subscription] request from user ${userId}`);

    const stripeKey = Deno.env.get("STRIPE_SECRET_KEY");
    if (!stripeKey) {
      console.error("[cancel-subscription] STRIPE_SECRET_KEY is not set");
      return new Response(
        JSON.stringify({ error: "Server misconfiguration: STRIPE_SECRET_KEY not set" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const { data: profile, error: profileError } = await supabaseAdmin
      .from("profiles")
      .select("stripe_subscription_id, is_pro")
      .eq("id", userId)
      .single();

    if (profileError) {
      console.error(`[cancel-subscription] failed to fetch profile for ${userId}:`, profileError);
      return new Response(
        JSON.stringify({ error: "Failed to load user profile" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    if (!profile?.is_pro) {
      console.log(`[cancel-subscription] user ${userId} is not Pro — rejecting`);
      return new Response(
        JSON.stringify({ error: "Not a Pro subscriber" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    if (!profile?.stripe_subscription_id) {
      console.error(`[cancel-subscription] user ${userId} is Pro but has no stripe_subscription_id`);
      return new Response(
        JSON.stringify({ error: "No subscription found" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const stripe = new Stripe(stripeKey);

    try {
      await stripe.subscriptions.update(profile.stripe_subscription_id, {
        cancel_at_period_end: true,
      });
      console.log(`[cancel-subscription] set cancel_at_period_end=true for subscription ${profile.stripe_subscription_id}`);
    } catch (err) {
      console.error(`[cancel-subscription] Stripe update failed:`, err);
      return new Response(
        JSON.stringify({ error: "Failed to cancel subscription with Stripe" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const { error: updateError } = await supabaseAdmin
      .from("profiles")
      .update({ stripe_cancel_at_period_end: true })
      .eq("id", userId);

    if (updateError) {
      console.error(`[cancel-subscription] failed to set cancel flag for ${userId}:`, updateError);
      // Non-fatal: Stripe is the source of truth; the flag is a UI hint only.
    }

    return new Response(
      JSON.stringify({ ok: true }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  });
});
