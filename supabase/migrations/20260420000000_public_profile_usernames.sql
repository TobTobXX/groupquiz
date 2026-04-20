-- Allow anonymous users to read profile usernames (for the public quiz browse page).
-- Restricts anon to only the id and username columns; sensitive columns
-- (is_pro, stripe_customer_id, stripe_subscription_id, stripe_cancel_at_period_end)
-- remain invisible to unauthenticated callers.

-- Drop the broad table-level SELECT grant for anon, then re-grant only safe columns.
REVOKE SELECT ON "public"."profiles" FROM "anon";
GRANT SELECT ("id", "username") ON "public"."profiles" TO "anon";

-- Add a permissive row-level policy for anon (scoped to anon only so that the
-- existing owner-only policy for authenticated users is unaffected).
CREATE POLICY "Public can read profile usernames"
  ON "public"."profiles"
  FOR SELECT
  TO "anon"
  USING (true);
