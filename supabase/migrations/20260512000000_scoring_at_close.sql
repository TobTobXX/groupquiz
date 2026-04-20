-- Move scoring from submit_answer to close_question.
--
-- Before: submit_answer computed score decay + streak bonus and updated
--         players immediately when an answer was recorded.
-- After:  submit_answer only records the answer and response_time_ms.
--         close_question evaluates all recorded answers in batch, assigns
--         points_earned per player_answers row, and updates players totals.
--
-- This means scores appear all at once when the host closes a question,
-- which is cleaner and fixes 0-point questions (correctness is now derived
-- from answer_id comparison, not points_earned > 0).


-- submit_answer: validates player secret, answer window, question match, and
-- slot validity; computes response_time_ms server-side; inserts a
-- player_answers row with points_earned = 0 (filled in by close_question).
CREATE OR REPLACE FUNCTION public.submit_answer(
    p_player_id     uuid,
    p_player_secret uuid,
    p_question_id   uuid,
    p_answer_id     uuid
) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_session_id             uuid;
  v_question_open          boolean;
  v_current_question_index integer;
  v_quiz_id                uuid;
  v_current_question_id    uuid;
  v_time_limit             integer;
  v_opened_at              timestamptz;
  v_elapsed                numeric;
  v_response_time_ms       integer;
  v_slot_valid             boolean;
BEGIN
  -- Verify player secret
  IF NOT EXISTS (SELECT 1 FROM public.players WHERE id = p_player_id AND secret = p_player_secret) THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  SELECT pl.session_id INTO v_session_id FROM public.players pl WHERE pl.id = p_player_id;

  -- Guard: answer window must be open
  SELECT s.question_open, s.current_question_index, s.quiz_id
    INTO v_question_open, v_current_question_index, v_quiz_id
    FROM public.sessions s
   WHERE s.id = v_session_id;

  IF NOT v_question_open THEN
    RAISE EXCEPTION 'Answer window is closed for session %', v_session_id;
  END IF;

  -- Guard: p_question_id must match the current question
  SELECT q.id INTO v_current_question_id
    FROM public.questions q
   WHERE q.quiz_id = v_quiz_id AND q.order_index = v_current_question_index;

  IF v_current_question_id IS DISTINCT FROM p_question_id THEN
    RAISE EXCEPTION 'Question % is not the current question in session %', p_question_id, v_session_id;
  END IF;

  -- Gate: answer must be present in session_question_answers for this session
  SELECT EXISTS (
    SELECT 1 FROM public.session_question_answers
     WHERE session_id = v_session_id AND question_id = p_question_id AND answer_id = p_answer_id
  ) INTO v_slot_valid;

  IF NOT v_slot_valid THEN
    RAISE EXCEPTION 'Answer % is not valid for question % in session %', p_answer_id, p_question_id, v_session_id;
  END IF;

  -- Compute response_time_ms server-side from question_opened_at
  SELECT s.question_opened_at, q.time_limit
    INTO v_opened_at, v_time_limit
    FROM public.sessions s
    JOIN public.questions q ON q.id = p_question_id
   WHERE s.id = v_session_id;

  v_elapsed := extract(epoch FROM (now() - coalesce(v_opened_at, now())));

  IF v_time_limit IS NOT NULL AND v_time_limit > 0 THEN
    v_response_time_ms := round(v_elapsed * 1000)::integer;
  ELSE
    v_response_time_ms := NULL;
  END IF;

  -- Record answer; points_earned defaults to 0 and is set by close_question
  INSERT INTO public.player_answers (player_id, question_id, answer_id, response_time_ms)
  VALUES (p_player_id, p_question_id, p_answer_id, v_response_time_ms);
END;
$$;


-- close_question: marks question_open = false, then evaluates all submitted
-- answers for the current question and updates scores/streaks in batch.
--
-- Score formula (same as before, now applied at close time):
--   base    = points * (0.5 + 0.5 * max(0, 1 - response_time_ms/1000 / time_limit))
--   bonus   = base * (1 + max(0, streak - 2) * 0.10)  [flame bonus ≥ 3-streak]
--   wrong   = 0 points, streak reset to 0
--   no time limit = full points for correct answer, no decay
CREATE OR REPLACE FUNCTION public.close_question(p_session_id uuid, p_host_secret uuid) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_question_index integer;
  v_quiz_id        uuid;
  v_question_id    uuid;
  v_points         integer;
  v_time_limit     integer;
  v_correct_id     uuid;

  -- cursor over submitted answers for this question
  v_rec            record;
  v_elapsed        numeric;
  v_points_earned  integer;
  v_new_streak     integer;
  v_flame_count    integer;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.sessions WHERE id = p_session_id AND host_secret = p_host_secret) THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  UPDATE public.sessions SET question_open = false WHERE id = p_session_id;

  -- Look up the current question
  SELECT s.current_question_index, s.quiz_id
    INTO v_question_index, v_quiz_id
    FROM public.sessions s
   WHERE s.id = p_session_id;

  SELECT q.id, q.points, q.time_limit
    INTO v_question_id, v_points, v_time_limit
    FROM public.questions q
   WHERE q.quiz_id = v_quiz_id AND q.order_index = v_question_index;

  IF v_question_id IS NULL THEN
    RETURN; -- no question to score (shouldn't happen in normal flow)
  END IF;

  -- Find the correct answer for this question
  SELECT id INTO v_correct_id
    FROM public.answers
   WHERE question_id = v_question_id AND is_correct = true
   LIMIT 1;

  -- Evaluate each player's submitted answer
  FOR v_rec IN
    SELECT pa.player_id, pa.answer_id, pa.response_time_ms,
           pl.streak AS current_streak
      FROM public.player_answers pa
      JOIN public.players pl ON pl.id = pa.player_id
     WHERE pa.question_id = v_question_id
  LOOP
    -- Compute time-decayed score
    IF v_time_limit IS NOT NULL AND v_time_limit > 0 AND v_rec.response_time_ms IS NOT NULL THEN
      v_elapsed       := v_rec.response_time_ms::numeric / 1000.0;
      v_points_earned := round(v_points * (0.5 + 0.5 * greatest(0.0, 1.0 - v_elapsed / v_time_limit)));
    ELSE
      v_points_earned := v_points;
    END IF;

    -- Streak and flame bonus; wrong answers score 0
    IF v_rec.answer_id = v_correct_id THEN
      v_new_streak    := v_rec.current_streak + 1;
      v_flame_count   := greatest(0, v_new_streak - 2);
      v_points_earned := round(v_points_earned * (1.0 + v_flame_count * 0.10))::integer;
    ELSE
      v_new_streak    := 0;
      v_points_earned := 0;
    END IF;

    UPDATE public.player_answers
       SET points_earned = v_points_earned
     WHERE player_id = v_rec.player_id AND question_id = v_question_id;

    UPDATE public.players
       SET score         = score + v_points_earned,
           streak        = v_new_streak,
           correct_count = correct_count + (CASE WHEN v_rec.answer_id = v_correct_id THEN 1 ELSE 0 END)
     WHERE id = v_rec.player_id;
  END LOOP;
END;
$$;
