-- Atomic quiz creation: insert quiz + all questions + all answers in one transaction.
-- Runs as SECURITY INVOKER so existing RLS policies on quizzes/questions/answers apply
-- unchanged (the caller's JWT is used for auth.uid() checks).
--
-- p_questions shape:
--   [ { order_index, question_text, time_limit, points, image_url,
--       answers: [ { order_index, answer_text, is_correct }, ... ] }, ... ]

create or replace function save_quiz(
  p_title     text,
  p_is_public boolean,
  p_questions jsonb
) returns uuid
language plpgsql
as $$
declare
  v_quiz_id     uuid;
  v_question    jsonb;
  v_answer      jsonb;
  v_question_id uuid;
begin
  insert into quizzes (title, is_public, creator_id)
  values (p_title, p_is_public, auth.uid())
  returning id into v_quiz_id;

  for v_question in select * from jsonb_array_elements(p_questions)
  loop
    insert into questions (quiz_id, order_index, question_text, time_limit, points, image_url)
    values (
      v_quiz_id,
      (v_question->>'order_index')::integer,
      v_question->>'question_text',
      (v_question->>'time_limit')::integer,
      (v_question->>'points')::integer,
      nullif(v_question->>'image_url', '')
    )
    returning id into v_question_id;

    for v_answer in select * from jsonb_array_elements(v_question->'answers')
    loop
      insert into answers (question_id, order_index, answer_text, is_correct)
      values (
        v_question_id,
        (v_answer->>'order_index')::integer,
        v_answer->>'answer_text',
        (v_answer->>'is_correct')::boolean
      );
    end loop;
  end loop;

  return v_quiz_id;
end;
$$;
