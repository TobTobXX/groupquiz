-- Simplify RLS on quizzes, questions, and answers.
-- Replace the per-operation policies with two policies per table:
--   <table>_modify_own    — FOR ALL TO authenticated; owner can do everything
--   <table>_select_public — FOR SELECT; anyone can read public content

-- -----------------------------------------------------------------------------
-- quizzes
-- -----------------------------------------------------------------------------
DROP POLICY IF EXISTS "quizzes_select_public" ON public.quizzes;
DROP POLICY IF EXISTS "quizzes_select_own"    ON public.quizzes;
DROP POLICY IF EXISTS "quizzes_insert_own"    ON public.quizzes;
DROP POLICY IF EXISTS "quizzes_update_own"    ON public.quizzes;
DROP POLICY IF EXISTS "quizzes_delete_own"    ON public.quizzes;

CREATE POLICY "quizzes_select_public" ON public.quizzes
  FOR SELECT USING (is_public = true);

CREATE POLICY "quizzes_modify_own" ON public.quizzes
  FOR ALL TO authenticated
  USING     (auth.uid() = creator_id)
  WITH CHECK (auth.uid() = creator_id);

-- -----------------------------------------------------------------------------
-- questions
-- -----------------------------------------------------------------------------
DROP POLICY IF EXISTS "questions_select_visible" ON public.questions;
DROP POLICY IF EXISTS "questions_insert_auth"    ON public.questions;
DROP POLICY IF EXISTS "questions_update_own"     ON public.questions;
DROP POLICY IF EXISTS "questions_delete_own"     ON public.questions;

CREATE POLICY "questions_select_public" ON public.questions
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.quizzes
       WHERE quizzes.id = questions.quiz_id
         AND quizzes.is_public = true
    )
  );

CREATE POLICY "questions_modify_own" ON public.questions
  FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.quizzes
       WHERE quizzes.id = questions.quiz_id
         AND quizzes.creator_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.quizzes
       WHERE quizzes.id = questions.quiz_id
         AND quizzes.creator_id = auth.uid()
    )
  );

-- -----------------------------------------------------------------------------
-- answers
-- -----------------------------------------------------------------------------
DROP POLICY IF EXISTS "answers_select_visible" ON public.answers;
DROP POLICY IF EXISTS "answers_insert_auth"    ON public.answers;
DROP POLICY IF EXISTS "answers_update_own"     ON public.answers;
DROP POLICY IF EXISTS "answers_delete_own"     ON public.answers;

CREATE POLICY "answers_select_public" ON public.answers
  FOR SELECT USING (
    EXISTS (
      SELECT 1
        FROM public.questions q
        JOIN public.quizzes quz ON quz.id = q.quiz_id
       WHERE q.id = answers.question_id
         AND quz.is_public = true
    )
  );

CREATE POLICY "answers_modify_own" ON public.answers
  FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1
        FROM public.questions q
        JOIN public.quizzes quz ON quz.id = q.quiz_id
       WHERE q.id = answers.question_id
         AND quz.creator_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
        FROM public.questions q
        JOIN public.quizzes quz ON quz.id = q.quiz_id
       WHERE q.id = answers.question_id
         AND quz.creator_id = auth.uid()
    )
  );
