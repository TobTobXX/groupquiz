-- Permissive policies for all tables until auth is added in v0.8.
-- These will be replaced with proper user-scoped policies then.

create policy "allow all" on quizzes    for all using (true) with check (true);
create policy "allow all" on questions  for all using (true) with check (true);
create policy "allow all" on answers    for all using (true) with check (true);
create policy "allow all" on sessions   for all using (true) with check (true);
create policy "allow all" on players    for all using (true) with check (true);
