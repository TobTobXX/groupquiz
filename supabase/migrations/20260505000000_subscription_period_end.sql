-- Add subscription_period_end to profiles.
-- Stores the Unix timestamp (as timestamptz) from Stripe's invoice.period_end,
-- written by the stripe-webhook Edge Function on every invoice.paid event.
-- Cleared to NULL when the subscription is deleted.

ALTER TABLE public.profiles
  ADD COLUMN subscription_period_end timestamptz;
