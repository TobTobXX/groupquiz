-- Enable pg_cron and pg_net.
-- On Supabase hosted projects both are pre-installed; these are no-ops there.
CREATE EXTENSION IF NOT EXISTS pg_cron WITH SCHEMA extensions;
CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;

-- Daily cron job: call the sweep-orphan-images Edge Function at 03:00 UTC.
-- The function lists all objects in the 'images' storage bucket, compares them
-- against every image_url currently stored in questions, and deletes any that
-- are no longer referenced.  verify_jwt is disabled on the function so no
-- auth header is required.
SELECT cron.schedule(
  'sweep-orphan-images',
  '0 3 * * *',
  $$
  SELECT net.http_post(
    url     := 'https://qvglitqbidnrbfziotme.supabase.co/functions/v1/sweep-orphan-images',
    headers := '{}'::jsonb,
    body    := '{}'::jsonb
  );
  $$
);
