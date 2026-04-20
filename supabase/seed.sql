-- Seed data for local development.
-- Applied automatically by `supabase start` (first run) and `supabase db reset`.
-- Provides a public quiz visible in Browse so the full play flow works without
-- needing to create a quiz creator account first.
--
-- Also sets up the Stripe FDW for local dev using the Stripe test key.
-- The migration's DO block skips server/table creation because it runs before
-- this seed file; we complete the setup here once the vault secret exists.

insert into quizzes (id, title, is_public, language, topic)
values ('00000000-0000-0000-0000-000000000001', 'Sample Quiz', true, 'en', 'General');

insert into questions (id, quiz_id, order_index, question_text, time_limit, points)
values
  ('00000000-0000-0000-0001-000000000001', '00000000-0000-0000-0000-000000000001', 0, 'What is 2 + 2?', 30, 1000),
  ('00000000-0000-0000-0001-000000000002', '00000000-0000-0000-0000-000000000001', 1, 'What is the capital of France?', 30, 1000),
  ('00000000-0000-0000-0001-000000000003', '00000000-0000-0000-0000-000000000001', 2, 'Which planet is closest to the Sun?', 20, 1000);

insert into answers (id, question_id, order_index, answer_text, is_correct)
values
  -- Q1: 2+2
  ('00000000-0000-0000-0002-000000000001', '00000000-0000-0000-0001-000000000001', 0, '3',  false),
  ('00000000-0000-0000-0002-000000000002', '00000000-0000-0000-0001-000000000001', 1, '4',  true),
  ('00000000-0000-0000-0002-000000000003', '00000000-0000-0000-0001-000000000001', 2, '5',  false),
  ('00000000-0000-0000-0002-000000000004', '00000000-0000-0000-0001-000000000001', 3, '22', false),
  -- Q2: capital of France
  ('00000000-0000-0000-0002-000000000005', '00000000-0000-0000-0001-000000000002', 0, 'London', false),
  ('00000000-0000-0000-0002-000000000006', '00000000-0000-0000-0001-000000000002', 1, 'Paris',  true),
  ('00000000-0000-0000-0002-000000000007', '00000000-0000-0000-0001-000000000002', 2, 'Berlin', false),
  ('00000000-0000-0000-0002-000000000008', '00000000-0000-0000-0001-000000000002', 3, 'Madrid', false),
  -- Q3: closest planet to Sun
  ('00000000-0000-0000-0002-000000000009', '00000000-0000-0000-0001-000000000003', 0, 'Venus',   false),
  ('00000000-0000-0000-0002-000000000010', '00000000-0000-0000-0001-000000000003', 1, 'Earth',   false),
  ('00000000-0000-0000-0002-000000000011', '00000000-0000-0000-0001-000000000003', 2, 'Mercury', true),
  ('00000000-0000-0000-0002-000000000012', '00000000-0000-0000-0001-000000000003', 3, 'Mars',    false);

-- Stripe FDW — local dev setup
-- Stores the Stripe test key in vault and completes the FDW server + table
-- creation that the migration skipped (no secret available at migration time).
DO $$
DECLARE
  v_secret_id uuid;
BEGIN
  -- The migration's DO block creates stripe_wrapper only when the Rust handler is
  -- loadable (Supabase managed Postgres). Skip here if it wasn't created.
  IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_foreign_data_wrapper WHERE fdwname = 'stripe_wrapper') THEN
    RAISE NOTICE 'stripe_wrapper FDW not available; skipping local Stripe FDW setup.';
    RETURN;
  END IF;

  -- Insert the test key only if it isn't already there (idempotent resets)
  IF NOT EXISTS (SELECT 1 FROM vault.secrets WHERE name = 'stripe_api_key_id') THEN
    SELECT vault.create_secret(
      'sk_test_placeholder_replace_via_dashboard',
      'stripe_api_key_id'
    ) INTO v_secret_id;
  ELSE
    SELECT id INTO v_secret_id FROM vault.secrets WHERE name = 'stripe_api_key_id';
  END IF;

  -- Create the server if the migration's DO block skipped it
  IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_foreign_server WHERE srvname = 'stripe_server') THEN
    EXECUTE format(
      'CREATE SERVER stripe_server FOREIGN DATA WRAPPER stripe_wrapper OPTIONS (api_key_id %L)',
      v_secret_id::text
    );
  END IF;

  CREATE SCHEMA IF NOT EXISTS stripe;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.foreign_tables
     WHERE foreign_table_schema = 'stripe' AND foreign_table_name = 'subscriptions'
  ) THEN
    EXECUTE $sql$
      CREATE FOREIGN TABLE stripe.subscriptions (
        id                   text,
        customer             text,
        status               text,
        current_period_start timestamp,
        current_period_end   timestamp,
        cancel_at_period_end boolean,
        attrs                jsonb
      )
      SERVER stripe_server
      OPTIONS (object 'subscriptions', rowid_column 'id')
    $sql$;
  END IF;
END;
$$;
