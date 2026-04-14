alter table sessions
  drop constraint sessions_quiz_id_fkey,
  add constraint sessions_quiz_id_fkey
    foreign key (quiz_id) references quizzes(id) on delete cascade;
