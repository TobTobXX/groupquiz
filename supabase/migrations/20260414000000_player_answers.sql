-- player_answers
create table player_answers (
  id           uuid primary key default gen_random_uuid(),
  player_id    uuid not null references players(id) on delete cascade,
  question_id  uuid not null references questions(id) on delete cascade,
  answer_id    uuid not null references answers(id) on delete cascade,
  created_at   timestamptz not null default now(),
  unique (player_id, question_id)
);
alter table player_answers enable row level security;

-- question_open flag on sessions (true = question is accepting answers)
alter table sessions add column question_open boolean not null default true;

-- enable realtime on player_answers and players
alter publication supabase_realtime add table player_answers;
alter publication supabase_realtime add table players;
