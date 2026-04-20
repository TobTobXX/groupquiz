-- Drop stale RPC overloads left behind by the quiz_tags and rename_subject_to_topic
-- migrations.  Both were superseded by 5/6-param versions that accept p_language
-- and p_topic; no frontend caller ever invoked these shorter signatures.

DROP FUNCTION IF EXISTS public.save_quiz(text, boolean, jsonb);
DROP FUNCTION IF EXISTS public.update_quiz(uuid, text, boolean, jsonb);
