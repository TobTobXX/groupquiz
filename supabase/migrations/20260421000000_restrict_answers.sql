-- Section 1: Hide is_correct from anonymous clients.
-- Column-level revoke on the anon role so direct SELECT queries cannot read is_correct.
-- Authenticated users (quiz creators, hosts) retain full access via the authenticated role.
-- Players learn correctness through points_earned (in player_answers) or the
-- get_correct_answer_id RPC, which is gated on the question window being closed.

REVOKE SELECT (is_correct) ON answers FROM anon;

-- Returns the correct answer id for a question in a session, but only after
-- the host has closed the answer window.  Prevents players from querying
-- is_correct before a question is shown.
CREATE OR REPLACE FUNCTION get_correct_answer_id(
  p_session_id  uuid,
  p_question_id uuid
) RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_question_open boolean;
  v_correct_id    uuid;
BEGIN
  SELECT question_open INTO v_question_open
    FROM sessions
   WHERE id = p_session_id;

  IF v_question_open IS DISTINCT FROM false THEN
    RAISE EXCEPTION 'Question window is still open';
  END IF;

  SELECT id INTO v_correct_id
    FROM answers
   WHERE question_id = p_question_id
     AND is_correct = true
   LIMIT 1;

  RETURN v_correct_id;
END;
$$;
