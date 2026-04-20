-- Support multiple correct answers (Option A: any correct answer is accepted).
--
-- Changes:
--   1. Replace get_correct_answer_id (returns single uuid) with
--      get_correct_answer_ids (returns uuid[]) so the player feedback screen
--      can highlight all correct slots.
--   2. Update close_question to check answers.is_correct directly instead of
--      comparing to a single fetched correct ID, so any correct answer is scored.

-- -----------------------------------------------------------------------------
-- Drop old single-answer RPC and grant
-- -----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.get_correct_answer_id(uuid, uuid);


-- -----------------------------------------------------------------------------
-- New RPC: get_correct_answer_ids
-- Returns all correct answer IDs for a question, but only after the answer
-- window is closed (same guard as before).
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_correct_answer_ids(
  p_session_id  uuid,
  p_question_id uuid
) RETURNS uuid[]
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_question_open boolean;
BEGIN
  SELECT question_open INTO v_question_open
    FROM public.sessions WHERE id = p_session_id;

  IF v_question_open IS DISTINCT FROM false THEN
    RAISE EXCEPTION 'Question window is still open';
  END IF;

  RETURN ARRAY(
    SELECT id FROM public.answers
     WHERE question_id = p_question_id AND is_correct = true
  );
END;
$$;
ALTER FUNCTION public.get_correct_answer_ids(uuid, uuid) OWNER TO postgres;

GRANT ALL ON FUNCTION public.get_correct_answer_ids(uuid, uuid) TO anon;
GRANT ALL ON FUNCTION public.get_correct_answer_ids(uuid, uuid) TO authenticated;
GRANT ALL ON FUNCTION public.get_correct_answer_ids(uuid, uuid) TO service_role;


-- -----------------------------------------------------------------------------
-- Updated close_question: check is_correct directly on the submitted answer
-- instead of fetching a single correct ID with LIMIT 1.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.close_question(
  p_session_id  uuid,
  p_host_secret uuid
) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_question_index integer;
  v_quiz_id        uuid;
  v_question_id    uuid;
  v_points         integer;
  v_time_limit     integer;

  v_rec            record;
  v_elapsed        numeric;
  v_points_earned  integer;
  v_new_streak     integer;
  v_flame_count    integer;
  v_is_correct     boolean;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.sessions WHERE id = p_session_id AND host_secret = p_host_secret) THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  UPDATE public.sessions SET question_open = false WHERE id = p_session_id;

  SELECT s.current_question_index, s.quiz_id
    INTO v_question_index, v_quiz_id
    FROM public.sessions s
   WHERE s.id = p_session_id;

  SELECT q.id, q.points, q.time_limit
    INTO v_question_id, v_points, v_time_limit
    FROM public.questions q
   WHERE q.quiz_id = v_quiz_id AND q.order_index = v_question_index;

  IF v_question_id IS NULL THEN
    RETURN;
  END IF;

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

    -- Check correctness directly on the submitted answer (supports multiple correct answers)
    SELECT is_correct INTO v_is_correct
      FROM public.answers WHERE id = v_rec.answer_id;

    -- Streak and flame bonus; wrong answers score 0
    IF v_is_correct THEN
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
           correct_count = correct_count + (CASE WHEN v_is_correct THEN 1 ELSE 0 END)
     WHERE id = v_rec.player_id;
  END LOOP;
END;
$$;
ALTER FUNCTION public.close_question(uuid, uuid) OWNER TO postgres;
