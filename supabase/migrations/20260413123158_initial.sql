-- quizzes
create table quizzes (
  id          uuid primary key default gen_random_uuid(),
  title       text not null,
  created_at  timestamptz not null default now()
);
alter table quizzes enable row level security;

-- questions
create table questions (
  id             uuid primary key default gen_random_uuid(),
  quiz_id        uuid not null references quizzes(id) on delete cascade,
  order_index    integer not null,
  question_text  text not null,
  time_limit     integer not null default 30,
  points         integer not null default 1000,
  image_url      text
);
alter table questions enable row level security;

-- answers
create table answers (
  id           uuid primary key default gen_random_uuid(),
  question_id  uuid not null references questions(id) on delete cascade,
  order_index  integer not null,
  answer_text  text not null,
  is_correct   boolean not null default false
);
alter table answers enable row level security;

-- sessions
create table sessions (
  id                      uuid primary key default gen_random_uuid(),
  quiz_id                 uuid not null references quizzes(id),
  join_code               text not null unique,
  state                   text not null default 'waiting',
  current_question_index  integer,
  created_at              timestamptz not null default now()
);
alter table sessions enable row level security;

-- players
create table players (
  id          uuid primary key default gen_random_uuid(),
  session_id  uuid not null references sessions(id) on delete cascade,
  nickname    text not null,
  score       integer not null default 0,
  joined_at   timestamptz not null default now()
);
alter table players enable row level security;
