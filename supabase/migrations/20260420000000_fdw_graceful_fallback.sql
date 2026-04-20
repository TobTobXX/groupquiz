-- Make get_my_subscription_period_end resilient to the Stripe FDW being absent
-- (e.g. local development).  Previously the function would raise
-- "relation does not exist" when the profile had Stripe IDs but the FDW
-- schema/table was not present.  Now it catches that error and returns null.

create or replace function public.get_my_subscription_period_end(p_env text)
returns timestamp
language plpgsql
security definer
stable
set search_path = public
as $$
declare
  v_sub_id  text;
  v_cust_id text;
  v_result  timestamp;
  v_table   text;
begin
  if p_env not in ('dev', 'prod') then
    raise exception 'p_env must be ''dev'' or ''prod''';
  end if;

  v_table := 'subscriptions_' || p_env;

  select stripe_subscription_id, stripe_customer_id
    into v_sub_id, v_cust_id
  from public.profiles
  where id = auth.uid();

  -- Nothing to look up
  if v_sub_id is null and v_cust_id is null then
    return null;
  end if;

  -- Prefer a direct subscription-ID lookup; fall back to customer-ID lookup.
  -- Catch undefined_table (42P01) so local dev without the Stripe FDW returns
  -- null instead of raising an error.
  begin
    if v_sub_id is not null then
      execute format(
        $q$select coalesce(
             current_period_end,
             to_timestamp((attrs->'items'->'data'->0->>'current_period_end')::bigint)::timestamp
           )
           from stripe.%I where id = $1 limit 1$q$,
        v_table
      ) into v_result using v_sub_id;
    end if;

    if v_result is null and v_cust_id is not null then
      execute format(
        $q$select coalesce(
             current_period_end,
             to_timestamp((attrs->'items'->'data'->0->>'current_period_end')::bigint)::timestamp
           )
           from stripe.%I where customer = $1
           order by coalesce(
             current_period_end,
             to_timestamp((attrs->'items'->'data'->0->>'current_period_end')::bigint)::timestamp
           ) desc nulls last limit 1$q$,
        v_table
      ) into v_result using v_cust_id;
    end if;
  exception when undefined_table then
    return null;
  end;

  return v_result;
end;
$$;

grant execute on function public.get_my_subscription_period_end(text) to authenticated;
