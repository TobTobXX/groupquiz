-- Simplify RLS on profiles and starred_quizzes to match the two-policy
-- pattern used for quizzes/questions/answers.
-- The anon column-level grant and read policy on profiles (from
-- 20260420000000_public_profile_usernames.sql) are unchanged.

-- -----------------------------------------------------------------------------
-- profiles
-- -----------------------------------------------------------------------------
DROP POLICY IF EXISTS "Users can insert own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can read own profile"   ON public.profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;

CREATE POLICY "profiles_own" ON public.profiles
  FOR ALL TO authenticated
  USING     (id = auth.uid())
  WITH CHECK (id = auth.uid());

-- -----------------------------------------------------------------------------
-- starred_quizzes
-- -----------------------------------------------------------------------------
DROP POLICY IF EXISTS "owner select" ON public.starred_quizzes;
DROP POLICY IF EXISTS "owner insert" ON public.starred_quizzes;
DROP POLICY IF EXISTS "owner delete" ON public.starred_quizzes;

CREATE POLICY "starred_quizzes_own" ON public.starred_quizzes
  FOR ALL TO authenticated
  USING     (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);
