-- Section 5: Guard submit_answer against out-of-window submissions.
-- Two new checks added right after the player-session lookup:
--   1. question_open must be true — rejects submissions after the host closes the window.
--   2. p_question_id must match the session's current_question_index — rejects submissions
--      targeting past or future questions.

CREATE OR REPLACE FUNCTION submit_answer(
  p_player_id   uuid,
  p_question_id uuid,
  p_answer_id   uuid
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_session_id             uuid;
  v_question_open          boolean;
  v_current_question_index integer;
  v_quiz_id                uuid;
  v_current_question_id    uuid;
  v_is_correct             boolean;
  v_points                 integer;
  v_time_limit             integer;
  v_opened_at              timestamptz;
  v_elapsed                numeric;
  v_points_earned          integer;
  v_response_time_ms       integer;
  v_slot_valid             boolean;
  v_streak                 integer;
  v_new_streak             integer;
  v_flame_count            integer;
BEGIN
  -- Get the player's session
  SELECT pl.session_id INTO v_session_id FROM players pl WHERE pl.id = p_player_id;

  -- Guard: answer window must be open
  SELECT s.question_open, s.current_question_index, s.quiz_id
    INTO v_question_open, v_current_question_index, v_quiz_id
    FROM sessions s
   WHERE s.id = v_session_id;

  IF NOT v_question_open THEN
    RAISE EXCEPTION 'Answer window is closed for session %', v_session_id;
  END IF;

  -- Guard: p_question_id must match the current question
  SELECT q.id INTO v_current_question_id
    FROM questions q
   WHERE q.quiz_id = v_quiz_id
     AND q.order_index = v_current_question_index;

  IF v_current_question_id IS DISTINCT FROM p_question_id THEN
    RAISE EXCEPTION 'Question % is not the current question in session %', p_question_id, v_session_id;
  END IF;

  -- Gate: answer must be in session_question_answers for this session + question
  SELECT EXISTS (
    SELECT 1 FROM session_question_answers
     WHERE session_id = v_session_id AND question_id = p_question_id AND answer_id = p_answer_id
  ) INTO v_slot_valid;

  IF NOT v_slot_valid THEN
    RAISE EXCEPTION 'Answer % is not valid for question % in session %', p_answer_id, p_question_id, v_session_id;
  END IF;

  -- Answer correctness and question base points / time limit
  SELECT a.is_correct, q.points, q.time_limit
    INTO v_is_correct, v_points, v_time_limit
    FROM answers a
    JOIN questions q ON q.id = a.question_id
   WHERE a.id = p_answer_id;

  -- Read current streak before insert so we can compute the new value
  SELECT streak INTO v_streak FROM players WHERE id = p_player_id;

  -- Compute new streak and flame count
  v_new_streak  := CASE WHEN v_is_correct THEN v_streak + 1 ELSE 0 END;
  v_flame_count := greatest(0, v_new_streak - 2);

  -- When the current question was opened
  SELECT s.question_opened_at INTO v_opened_at FROM sessions s WHERE s.id = v_session_id;

  -- Elapsed seconds; NULL opened_at treated as 0 elapsed → full points
  v_elapsed := extract(epoch FROM (now() - coalesce(v_opened_at, now())));

  -- Score decay: full points at t=0, half points at t=time_limit, linear between
  IF v_time_limit IS NOT NULL AND v_time_limit > 0 THEN
    v_points_earned    := round(v_points * (0.5 + 0.5 * greatest(0.0, 1.0 - v_elapsed / v_time_limit)));
    v_response_time_ms := round(v_elapsed * 1000)::integer;
  ELSE
    v_points_earned    := v_points;
    v_response_time_ms := NULL;
  END IF;

  -- Apply flame bonus (correct) or zero out points (wrong)
  IF v_is_correct THEN
    v_points_earned := round(v_points_earned * (1.0 + v_flame_count * 0.10))::integer;
  ELSE
    v_points_earned := 0;
  END IF;

  INSERT INTO player_answers (player_id, question_id, answer_id, points_earned, response_time_ms)
  VALUES (p_player_id, p_question_id, p_answer_id, v_points_earned, v_response_time_ms);

  -- Unconditional update: wrong answers add 0 points, reset streak to 0, no correct_count change
  UPDATE players
     SET score         = score + v_points_earned,
         streak        = v_new_streak,
         correct_count = correct_count + (CASE WHEN v_is_correct THEN 1 ELSE 0 END)
   WHERE id = p_player_id;
END;
$$;
