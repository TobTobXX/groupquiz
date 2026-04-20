-- Color is always deterministic from slot_index (0=red, 1=blue, 2=yellow, 3=green),
-- so storing it in session_question_answers is redundant. Drop the column and
-- remove it from the assign_answer_slots RPC and its JSONB broadcast.

ALTER TABLE "public"."session_question_answers" DROP COLUMN "color";

CREATE OR REPLACE FUNCTION "public"."assign_answer_slots"("p_session_id" "uuid", "p_question_id" "uuid", "p_shuffle" boolean) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_slot_index integer := 0;
  v_result     jsonb := '[]'::jsonb;
  v_icons      text[] := array['circle', 'diamond', 'triangle', 'square'];
  v_ordered    uuid[];
  v_i          integer;
  v_j          integer;
  v_tmp        uuid;
  v_ans        uuid;
BEGIN
  -- Collect answer ids in order_index order
  SELECT array_agg(a.id ORDER BY a.order_index)
    INTO v_ordered
    FROM public.answers a
   WHERE a.question_id = p_question_id;

  -- Fisher-Yates shuffle if requested
  IF p_shuffle AND array_length(v_ordered, 1) > 1 THEN
    FOR v_i IN REVERSE array_length(v_ordered, 1) .. 2 LOOP
      v_j := 1 + floor(random() * v_i)::int;
      v_tmp := v_ordered[v_i];
      v_ordered[v_i] := v_ordered[v_j];
      v_ordered[v_j] := v_tmp;
    END LOOP;
  END IF;

  -- Delete any existing slot assignments for this session+question (idempotent on replay)
  DELETE FROM public.session_question_answers
   WHERE session_id = p_session_id AND question_id = p_question_id;

  -- Insert one row per slot
  FOR v_i IN 1..coalesce(array_length(v_ordered, 1), 0) LOOP
    v_ans := v_ordered[v_i];
    INSERT INTO public.session_question_answers (session_id, question_id, slot_index, answer_id, icon)
    VALUES (p_session_id, p_question_id, v_slot_index, v_ans, v_icons[v_slot_index + 1]);

    v_result := v_result || jsonb_build_object(
      'slot_index', v_slot_index,
      'answer_id',  v_ans,
      'icon',       v_icons[v_slot_index + 1]
    );
    v_slot_index := v_slot_index + 1;
  END LOOP;

  RETURN v_result;
END;
$$;
