alter table public.profiles
  add column if not exists stripe_cancel_at_period_end boolean not null default false;
