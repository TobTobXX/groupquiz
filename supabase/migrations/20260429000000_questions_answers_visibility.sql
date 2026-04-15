-- Restrict questions and answers to accessible quizzes only.
-- Previously both used USING (true), leaking content of private quizzes to
-- anyone who knew the quiz_id.
--
-- A quiz is accessible if:
--   (a) it is public, OR
--   (b) the caller is its creator, OR
--   (c) a live (non-finished) session exists for it — players need to read
--       questions/answers during gameplay even for private quizzes.

DROP POLICY IF EXISTS questions_select_open ON questions;
CREATE POLICY questions_select_visible ON questions FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM public.quizzes
    WHERE id = quiz_id AND (
      is_public = true
      OR creator_id = auth.uid()
      OR EXISTS (
        SELECT 1 FROM public.sessions
        WHERE quiz_id = quizzes.id AND state != 'finished'
      )
    )
  )
);

DROP POLICY IF EXISTS answers_select_open ON answers;
CREATE POLICY answers_select_visible ON answers FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM public.questions q
    JOIN public.quizzes quz ON quz.id = q.quiz_id
    WHERE q.id = question_id AND (
      quz.is_public = true
      OR quz.creator_id = auth.uid()
      OR EXISTS (
        SELECT 1 FROM public.sessions
        WHERE quiz_id = quz.id AND state != 'finished'
      )
    )
  )
);
