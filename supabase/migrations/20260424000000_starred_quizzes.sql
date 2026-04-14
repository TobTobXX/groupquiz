-- Starred quizzes: logged-in users can star public quizzes
create table starred_quizzes (
  user_id  uuid not null references auth.users(id) on delete cascade,
  quiz_id  uuid not null references quizzes(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, quiz_id)
);

alter table starred_quizzes enable row level security;

-- Users can only see and manage their own stars
create policy "owner select" on starred_quizzes
  for select using (auth.uid() = user_id);

create policy "owner insert" on starred_quizzes
  for insert with check (auth.uid() = user_id);

create policy "owner delete" on starred_quizzes
  for delete using (auth.uid() = user_id);
