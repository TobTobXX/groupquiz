-- =============================================================================
-- Session model refactor
-- =============================================================================
-- Replaces session_question_answers + player_answers with a cleaner pair:
--
--   session_questions  — snapshot of each question as it is shown: text, image,
--                        time limit, points, slot assignments. correct_slot_indices
--                        is null until score_question fires, so the correct answer
--                        is never visible while the question is live.
--
--   session_answers    — one row per player per question, keyed on
--                        session_question_id + slot_index (no FK into user-data
--                        tables).
--
-- Security improvements:
--   • answers.is_correct is no longer readable by anon (column-level grant).
--   • questions / answers RLS no longer has an "active session" exemption.
--     Anon reads question data exclusively through session_questions snapshots,
--     closing the cheat vector (pre-fetching future questions) and the is_correct
--     leak — both listed as technical debt in TASKS.md.
--
-- Sessions table is slimmed down:
--   Drops: current_question_index, question_open, question_opened_at,
--          current_question_slots.
--   Question lifecycle state now lives on session_questions rows.
--
-- RPCs replaced:
--   create_session           → start_session       (same logic, renamed)
--   start_game +
--   open_next_question       → next_question        (combined; also transitions
--                                                    waiting → active on first call)
--   close_question           → score_question
--   end_game                 → end_session
--   submit_answer(... question_id, answer_id)
--                            → submit_answer(... session_question_id, slot_index)
--   get_correct_answer_ids   → obsolete (correct_slot_indices on session_questions)
--   assign_answer_slots      → absorbed into next_question
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 0. Remove old tables from the realtime publication before dropping them
-- -----------------------------------------------------------------------------
ALTER PUBLICATION supabase_realtime DROP TABLE public.player_answers;
ALTER PUBLICATION supabase_realtime DROP TABLE public.session_question_answers;


-- -----------------------------------------------------------------------------
-- 1. Clear all session data
--    Sessions are ephemeral (12-hour pg_cron cleanup). Truncating avoids a
--    complex data migration and evicts any in-progress sessions.
-- -----------------------------------------------------------------------------
TRUNCATE public.sessions CASCADE;


-- -----------------------------------------------------------------------------
-- 2. Drop old triggers and functions
-- -----------------------------------------------------------------------------
DROP TRIGGER  IF EXISTS sessions_question_opened_at_trigger ON public.sessions;
DROP FUNCTION IF EXISTS public.sessions_set_question_opened_at();
DROP FUNCTION IF EXISTS public.assign_answer_slots(uuid, uuid, boolean);
DROP FUNCTION IF EXISTS public.start_game(uuid, uuid, uuid, boolean);
DROP FUNCTION IF EXISTS public.open_next_question(uuid, uuid, integer, uuid, boolean);
DROP FUNCTION IF EXISTS public.close_question(uuid, uuid);
DROP FUNCTION IF EXISTS public.end_game(uuid, uuid);
DROP FUNCTION IF EXISTS public.create_session(uuid);
DROP FUNCTION IF EXISTS public.submit_answer(uuid, uuid, uuid, uuid);
DROP FUNCTION IF EXISTS public.get_correct_answer_ids(uuid, uuid);


-- -----------------------------------------------------------------------------
-- 3. Drop old session tables
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS public.player_answers;
DROP TABLE IF EXISTS public.session_question_answers;


-- -----------------------------------------------------------------------------
-- 4. Slim down the sessions table — question lifecycle state moves to
--    session_questions rows
-- -----------------------------------------------------------------------------
ALTER TABLE public.sessions
  DROP COLUMN IF EXISTS current_question_index,
  DROP COLUMN IF EXISTS question_open,
  DROP COLUMN IF EXISTS question_opened_at,
  DROP COLUMN IF EXISTS current_question_slots;


-- -----------------------------------------------------------------------------
-- 5. Create session_questions
--    One row per question shown; inserted by next_question RPC.
--    slots JSONB: [{slot_index, answer_id, answer_text, icon}]
--      answer_id is present for internal use by score_question (SECURITY DEFINER).
--      Anon can read this table; they cannot derive is_correct because that
--      column is revoked from anon on the answers table (see section 8).
--    correct_slot_indices: null while open; set by score_question, e.g. [0, 2].
-- -----------------------------------------------------------------------------
CREATE TABLE public.session_questions (
  id                   uuid        DEFAULT gen_random_uuid() NOT NULL,
  session_id           uuid        NOT NULL,
  question_index       integer     NOT NULL,
  question_text        text        NOT NULL,
  image_url            text,
  time_limit           integer     NOT NULL DEFAULT 30,
  points               integer     NOT NULL DEFAULT 1000,
  slots                jsonb       NOT NULL,
  started_at           timestamptz NOT NULL DEFAULT now(),
  closed_at            timestamptz,
  correct_slot_indices jsonb,
  CONSTRAINT session_questions_pkey
    PRIMARY KEY (id),
  CONSTRAINT session_questions_session_id_question_index_key
    UNIQUE (session_id, question_index),
  CONSTRAINT session_questions_session_id_fkey
    FOREIGN KEY (session_id) REFERENCES public.sessions (id) ON DELETE CASCADE
);


-- -----------------------------------------------------------------------------
-- 6. Create session_answers
--    One row per player per question. References session_question_id + slot_index
--    — no foreign key into user-data tables (questions / answers).
--    points_earned defaults to 0; set by score_question.
-- -----------------------------------------------------------------------------
CREATE TABLE public.session_answers (
  id                  uuid        DEFAULT gen_random_uuid() NOT NULL,
  session_question_id uuid        NOT NULL,
  player_id           uuid        NOT NULL,
  slot_index          integer     NOT NULL,
  points_earned       integer     NOT NULL DEFAULT 0,
  response_time_ms    integer,
  created_at          timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT session_answers_pkey
    PRIMARY KEY (id),
  CONSTRAINT session_answers_session_question_id_player_id_key
    UNIQUE (session_question_id, player_id),
  CONSTRAINT session_answers_session_question_id_fkey
    FOREIGN KEY (session_question_id) REFERENCES public.session_questions (id) ON DELETE CASCADE,
  CONSTRAINT session_answers_player_id_fkey
    FOREIGN KEY (player_id) REFERENCES public.players (id) ON DELETE CASCADE
);


-- -----------------------------------------------------------------------------
-- 7. Add new tables to the realtime publication
-- -----------------------------------------------------------------------------
ALTER PUBLICATION supabase_realtime ADD TABLE public.session_questions;
ALTER PUBLICATION supabase_realtime ADD TABLE public.session_answers;


-- -----------------------------------------------------------------------------
-- 8. RLS
-- -----------------------------------------------------------------------------

-- session_questions: readable by all; written only via next_question RPC
ALTER TABLE public.session_questions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "session_questions_select" ON public.session_questions
  FOR SELECT USING (true);


-- session_answers: readable by all; written only via submit_answer RPC
ALTER TABLE public.session_answers ENABLE ROW LEVEL SECURITY;

CREATE POLICY "session_answers_select" ON public.session_answers
  FOR SELECT USING (true);


-- questions: remove the "active session" exemption.
-- Anon no longer reads questions directly during gameplay; all question data
-- is served from session_questions snapshots.
DROP POLICY IF EXISTS "questions_select_visible" ON public.questions;

CREATE POLICY "questions_select_visible" ON public.questions
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.quizzes
       WHERE quizzes.id = questions.quiz_id
         AND (quizzes.is_public = true OR quizzes.creator_id = auth.uid())
    )
  );


-- answers: same simplification; is_correct grant handled separately below
DROP POLICY IF EXISTS "answers_select_visible" ON public.answers;

CREATE POLICY "answers_select_visible" ON public.answers
  FOR SELECT USING (
    EXISTS (
      SELECT 1
        FROM public.questions q
        JOIN public.quizzes quz ON quz.id = q.quiz_id
       WHERE q.id = answers.question_id
         AND (quz.is_public = true OR quz.creator_id = auth.uid())
    )
  );


-- -----------------------------------------------------------------------------
-- 9. Column-level grant: hide answers.is_correct from anon
--    Revoke the broad table-level SELECT, then re-grant only the safe columns.
--    authenticated keeps full access so the quiz editor can display is_correct.
-- -----------------------------------------------------------------------------
REVOKE SELECT ON public.answers FROM anon;
GRANT  SELECT (id, question_id, order_index, answer_text) ON public.answers TO anon;


-- -----------------------------------------------------------------------------
-- 10. New RPCs
-- -----------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- start_session: creates a new session (renamed from create_session).
-- Returns {session_id, join_code, host_secret}. host_secret must be stored
-- client-side (localStorage) and passed to all subsequent host RPCs.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.start_session(p_quiz_id uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_session_id  uuid;
  v_join_code   text;
  v_host_secret uuid;
  v_chars       text    := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  v_i           integer;
  v_attempt     integer := 0;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.quizzes
     WHERE id = p_quiz_id
       AND (is_public = true OR creator_id = auth.uid())
  ) THEN
    RAISE EXCEPTION 'Quiz not found or not accessible';
  END IF;

  LOOP
    v_join_code := '';
    FOR v_i IN 1..6 LOOP
      v_join_code := v_join_code
        || substr(v_chars, 1 + floor(random() * length(v_chars))::integer, 1);
    END LOOP;

    BEGIN
      INSERT INTO public.sessions (quiz_id, join_code, state)
      VALUES (p_quiz_id, v_join_code, 'waiting')
      RETURNING id, host_secret INTO v_session_id, v_host_secret;
      EXIT;
    EXCEPTION WHEN unique_violation THEN
      v_attempt := v_attempt + 1;
      IF v_attempt >= 5 THEN
        RAISE EXCEPTION 'Failed to generate a unique join code after 5 attempts';
      END IF;
    END;
  END LOOP;

  RETURN jsonb_build_object(
    'session_id',  v_session_id,
    'join_code',   v_join_code,
    'host_secret', v_host_secret
  );
END;
$$;
ALTER FUNCTION public.start_session(uuid) OWNER TO postgres;


-- ---------------------------------------------------------------------------
-- next_question: opens the next question (or the first one, transitioning
-- waiting → active). Reads question + answer data from the quiz and snapshots
-- it into session_questions with slot assignments.
--
-- On the first call (state = 'waiting') the session transitions to 'active'.
-- Returns the new session_questions row so the caller has it immediately
-- without waiting for the realtime INSERT event.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.next_question(
  p_session_id  uuid,
  p_host_secret uuid,
  p_shuffle     boolean DEFAULT false
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_quiz_id    uuid;
  v_state      text;
  v_next_index integer;
  v_q          record;
  v_ans_ids    uuid[];
  v_ans_texts  text[];
  v_icons      text[] := array['circle', 'diamond', 'triangle', 'square'];
  v_tmp_id     uuid;
  v_tmp_text   text;
  v_i          integer;
  v_j          integer;
  v_slots      jsonb := '[]'::jsonb;
  v_sq_id      uuid;
BEGIN
  SELECT quiz_id, state
    INTO v_quiz_id, v_state
    FROM public.sessions
   WHERE id = p_session_id AND host_secret = p_host_secret;

  IF v_quiz_id IS NULL THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;
  IF v_state = 'finished' THEN
    RAISE EXCEPTION 'Session is finished';
  END IF;

  -- Guard: the previous question must be closed before opening a new one
  IF EXISTS (
    SELECT 1 FROM public.session_questions
     WHERE session_id = p_session_id AND closed_at IS NULL
  ) THEN
    RAISE EXCEPTION 'Current question is still open';
  END IF;

  -- Determine the next question index
  IF v_state = 'waiting' THEN
    v_next_index := 0;
  ELSE
    SELECT COALESCE(MAX(question_index) + 1, 0)
      INTO v_next_index
      FROM public.session_questions
     WHERE session_id = p_session_id;
  END IF;

  -- Read question metadata
  SELECT q.id, q.question_text, q.image_url, q.time_limit, q.points
    INTO v_q
    FROM public.questions q
   WHERE q.quiz_id = v_quiz_id AND q.order_index = v_next_index;

  IF v_q.id IS NULL THEN
    RAISE EXCEPTION 'No question at index %', v_next_index;
  END IF;

  -- Read answers in order_index order
  SELECT
    array_agg(a.id          ORDER BY a.order_index),
    array_agg(a.answer_text ORDER BY a.order_index)
  INTO v_ans_ids, v_ans_texts
  FROM public.answers a
  WHERE a.question_id = v_q.id;

  -- Fisher-Yates shuffle: shuffles answers between slots; icons are positional
  -- (slot 0 = circle, 1 = diamond, 2 = triangle, 3 = square) and stay fixed.
  IF p_shuffle AND array_length(v_ans_ids, 1) > 1 THEN
    FOR v_i IN REVERSE array_length(v_ans_ids, 1) .. 2 LOOP
      v_j := 1 + floor(random() * v_i)::int;

      v_tmp_id         := v_ans_ids[v_i];
      v_ans_ids[v_i]   := v_ans_ids[v_j];
      v_ans_ids[v_j]   := v_tmp_id;

      v_tmp_text         := v_ans_texts[v_i];
      v_ans_texts[v_i]   := v_ans_texts[v_j];
      v_ans_texts[v_j]   := v_tmp_text;
    END LOOP;
  END IF;

  -- Build slots JSONB
  -- answer_id is included for use by score_question (SECURITY DEFINER);
  -- anon can read the slots but cannot determine correctness because
  -- answers.is_correct is revoked from anon at the column level.
  FOR v_i IN 1..coalesce(array_length(v_ans_ids, 1), 0) LOOP
    v_slots := v_slots || jsonb_build_object(
      'slot_index',  v_i - 1,
      'answer_id',   v_ans_ids[v_i],
      'answer_text', v_ans_texts[v_i],
      'icon',        v_icons[v_i]
    );
  END LOOP;

  -- Snapshot the question
  INSERT INTO public.session_questions
    (session_id, question_index, question_text, image_url, time_limit, points, slots)
  VALUES
    (p_session_id, v_next_index,
     v_q.question_text, v_q.image_url, v_q.time_limit, v_q.points,
     v_slots)
  RETURNING id INTO v_sq_id;

  -- Transition waiting → active on the first question
  IF v_state = 'waiting' THEN
    UPDATE public.sessions SET state = 'active' WHERE id = p_session_id;
  END IF;

  RETURN jsonb_build_object(
    'id',             v_sq_id,
    'question_index', v_next_index,
    'question_text',  v_q.question_text,
    'image_url',      v_q.image_url,
    'time_limit',     v_q.time_limit,
    'points',         v_q.points,
    'slots',          v_slots
  );
END;
$$;
ALTER FUNCTION public.next_question(uuid, uuid, boolean) OWNER TO postgres;


-- ---------------------------------------------------------------------------
-- score_question: closes the current open question, computes correct_slot_indices
-- by reading answers.is_correct (SECURITY DEFINER bypasses the column-level
-- grant), and scores all submitted answers. Same time-decay + streak-bonus
-- logic as the old close_question.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.score_question(
  p_session_id  uuid,
  p_host_secret uuid
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_sq               record;
  v_slot             record;
  v_correct_arr      int[]  := '{}';
  v_correct_slots    jsonb;
  v_rec              record;
  v_is_correct       boolean;
  v_points_earned    integer;
  v_new_streak       integer;
  v_flame_count      integer;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.sessions
     WHERE id = p_session_id AND host_secret = p_host_secret
  ) THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  -- Find the single open question for this session
  SELECT * INTO v_sq
    FROM public.session_questions
   WHERE session_id = p_session_id AND closed_at IS NULL
   ORDER BY question_index DESC
   LIMIT 1;

  IF v_sq.id IS NULL THEN
    RAISE EXCEPTION 'No open question for session %', p_session_id;
  END IF;

  -- Close the question window
  UPDATE public.session_questions
     SET closed_at = now()
   WHERE id = v_sq.id;

  -- Determine which slot indices map to correct answers.
  -- answers.is_correct is readable here because the function is SECURITY DEFINER.
  FOR v_slot IN
    SELECT
      (s->>'slot_index')::integer AS slot_index,
      (s->>'answer_id')::uuid     AS answer_id
    FROM jsonb_array_elements(v_sq.slots) AS s
  LOOP
    IF EXISTS (
      SELECT 1 FROM public.answers
       WHERE id = v_slot.answer_id AND is_correct = true
    ) THEN
      v_correct_arr := v_correct_arr || v_slot.slot_index;
    END IF;
  END LOOP;

  v_correct_slots := to_jsonb(v_correct_arr);

  UPDATE public.session_questions
     SET correct_slot_indices = v_correct_slots
   WHERE id = v_sq.id;

  -- Score each submitted answer
  FOR v_rec IN
    SELECT sa.id, sa.player_id, sa.slot_index, sa.response_time_ms,
           pl.streak AS current_streak
      FROM public.session_answers sa
      JOIN public.players pl ON pl.id = sa.player_id
     WHERE sa.session_question_id = v_sq.id
  LOOP
    v_is_correct := v_rec.slot_index = ANY(v_correct_arr);

    IF v_is_correct THEN
      -- Time-decayed score: 50–100 % of face value based on response speed
      IF v_sq.time_limit > 0 AND v_rec.response_time_ms IS NOT NULL THEN
        v_points_earned := round(
          v_sq.points * (
            0.5 + 0.5 * greatest(0.0,
              1.0 - v_rec.response_time_ms::numeric / (v_sq.time_limit * 1000.0)
            )
          )
        );
      ELSE
        v_points_earned := v_sq.points;
      END IF;
      -- Streak bonus: +10 % per flame above 2 consecutive correct answers
      v_new_streak    := v_rec.current_streak + 1;
      v_flame_count   := greatest(0, v_new_streak - 2);
      v_points_earned := round(v_points_earned * (1.0 + v_flame_count * 0.10))::integer;
    ELSE
      v_new_streak    := 0;
      v_points_earned := 0;
    END IF;

    UPDATE public.session_answers
       SET points_earned = v_points_earned
     WHERE id = v_rec.id;

    UPDATE public.players
       SET score         = score + v_points_earned,
           streak        = v_new_streak,
           correct_count = correct_count + (CASE WHEN v_is_correct THEN 1 ELSE 0 END)
     WHERE id = v_rec.player_id;
  END LOOP;
END;
$$;
ALTER FUNCTION public.score_question(uuid, uuid) OWNER TO postgres;


-- ---------------------------------------------------------------------------
-- end_session: transitions the session to 'finished' (renamed from end_game).
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.end_session(
  p_session_id  uuid,
  p_host_secret uuid
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.sessions
     WHERE id = p_session_id AND host_secret = p_host_secret
  ) THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  UPDATE public.sessions SET state = 'finished' WHERE id = p_session_id;
END;
$$;
ALTER FUNCTION public.end_session(uuid, uuid) OWNER TO postgres;


-- ---------------------------------------------------------------------------
-- join_session: unchanged logic; included here for completeness.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.join_session(p_join_code text, p_nickname text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_session_id    uuid;
  v_session_state text;
  v_player_id     uuid;
  v_secret        uuid;
BEGIN
  SELECT id, state
    INTO v_session_id, v_session_state
    FROM public.sessions
   WHERE join_code = p_join_code;

  IF v_session_id IS NULL THEN
    RAISE EXCEPTION 'Session not found';
  END IF;
  IF v_session_state = 'finished' THEN
    RAISE EXCEPTION 'Session has ended';
  END IF;

  INSERT INTO public.players (session_id, nickname)
  VALUES (v_session_id, p_nickname)
  RETURNING id, secret INTO v_player_id, v_secret;

  RETURN jsonb_build_object('player_id', v_player_id, 'secret', v_secret);
END;
$$;
ALTER FUNCTION public.join_session(text, text) OWNER TO postgres;


-- ---------------------------------------------------------------------------
-- submit_answer: new signature — references session_question_id + slot_index
-- instead of question_id + answer_id. Players never need UUIDs from the
-- user-data tables.
-- response_time_ms is computed server-side from session_questions.started_at.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.submit_answer(
  p_player_id           uuid,
  p_player_secret       uuid,
  p_session_question_id uuid,
  p_slot_index          integer
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_session_id uuid;
  v_sq         record;
  v_elapsed    numeric;
  v_resp_ms    integer;
BEGIN
  -- Verify player identity
  IF NOT EXISTS (
    SELECT 1 FROM public.players
     WHERE id = p_player_id AND secret = p_player_secret
  ) THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  SELECT session_id INTO v_session_id
    FROM public.players
   WHERE id = p_player_id;

  -- Validate the session_question belongs to this player's session
  SELECT * INTO v_sq
    FROM public.session_questions
   WHERE id = p_session_question_id AND session_id = v_session_id;

  IF v_sq.id IS NULL THEN
    RAISE EXCEPTION 'Invalid session question';
  END IF;

  -- Guard: question must still be open
  IF v_sq.closed_at IS NOT NULL THEN
    RAISE EXCEPTION 'Answer window is closed';
  END IF;

  -- Guard: slot_index must exist in this question's slots
  IF NOT EXISTS (
    SELECT 1 FROM jsonb_array_elements(v_sq.slots) s
     WHERE (s->>'slot_index')::integer = p_slot_index
  ) THEN
    RAISE EXCEPTION 'Invalid slot index %', p_slot_index;
  END IF;

  -- Compute response time server-side
  v_elapsed := extract(epoch FROM (now() - v_sq.started_at));
  IF v_sq.time_limit > 0 THEN
    v_resp_ms := round(v_elapsed * 1000)::integer;
  ELSE
    v_resp_ms := NULL;
  END IF;

  -- points_earned defaults to 0 and is set by score_question
  INSERT INTO public.session_answers
    (session_question_id, player_id, slot_index, response_time_ms)
  VALUES
    (p_session_question_id, p_player_id, p_slot_index, v_resp_ms);
END;
$$;
ALTER FUNCTION public.submit_answer(uuid, uuid, uuid, integer) OWNER TO postgres;


-- -----------------------------------------------------------------------------
-- 11. Grants
-- -----------------------------------------------------------------------------

-- New tables
GRANT SELECT ON public.session_questions TO anon;
GRANT SELECT ON public.session_questions TO authenticated;
GRANT SELECT ON public.session_questions TO service_role;

GRANT SELECT ON public.session_answers TO anon;
GRANT SELECT ON public.session_answers TO authenticated;
GRANT SELECT ON public.session_answers TO service_role;

-- New RPCs (callable by anon — secrets act as auth tokens)
GRANT EXECUTE ON FUNCTION public.start_session(uuid)                     TO anon;
GRANT EXECUTE ON FUNCTION public.start_session(uuid)                     TO authenticated;
GRANT EXECUTE ON FUNCTION public.start_session(uuid)                     TO service_role;

GRANT EXECUTE ON FUNCTION public.next_question(uuid, uuid, boolean)      TO anon;
GRANT EXECUTE ON FUNCTION public.next_question(uuid, uuid, boolean)      TO authenticated;
GRANT EXECUTE ON FUNCTION public.next_question(uuid, uuid, boolean)      TO service_role;

GRANT EXECUTE ON FUNCTION public.score_question(uuid, uuid)              TO anon;
GRANT EXECUTE ON FUNCTION public.score_question(uuid, uuid)              TO authenticated;
GRANT EXECUTE ON FUNCTION public.score_question(uuid, uuid)              TO service_role;

GRANT EXECUTE ON FUNCTION public.end_session(uuid, uuid)                 TO anon;
GRANT EXECUTE ON FUNCTION public.end_session(uuid, uuid)                 TO authenticated;
GRANT EXECUTE ON FUNCTION public.end_session(uuid, uuid)                 TO service_role;

GRANT EXECUTE ON FUNCTION public.join_session(text, text)                TO anon;
GRANT EXECUTE ON FUNCTION public.join_session(text, text)                TO authenticated;
GRANT EXECUTE ON FUNCTION public.join_session(text, text)                TO service_role;

GRANT EXECUTE ON FUNCTION public.submit_answer(uuid, uuid, uuid, integer) TO anon;
GRANT EXECUTE ON FUNCTION public.submit_answer(uuid, uuid, uuid, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.submit_answer(uuid, uuid, uuid, integer) TO service_role;
