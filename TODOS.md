# TODOs — v0.6: Server-side score calculation

---

## 1. Migration: Postgres function + updated RLS

Move scoring into a SECURITY DEFINER Postgres function and tighten RLS so the client can no longer write scores directly or INSERT answers directly.

> **Files:** `supabase/migrations/`. **User action required:** After writing the migration file, push with `nix run nixpkgs#supabase-cli -- db push`. **Watch out:** The function must be `SECURITY DEFINER` so it runs as the DB owner and bypasses RLS when inserting into `player_answers` and updating `players.score`. The unique constraint on `player_answers(player_id, question_id)` still provides duplicate-answer protection — a second call will raise a `23505` error which propagates to the client just as before. **Policy names to drop:** the policy on `players` is named `"allow all"` (created in `20260413123160_open_policies.sql`); the policy on `player_answers` is also named `"allow all"` (created in `20260414000001_player_answers_policy.sql`). Keep `SELECT` open on both tables (the client still reads them for feedback and leaderboard). Keep `INSERT` open on `players` (needed so clients can insert a new player row when joining). Remove `INSERT` from `player_answers` (only the function should write there). Remove `UPDATE` from `players` (only the function should change scores).

- [x] Create `supabase/migrations/20260415000000_server_side_scoring.sql`
- [x] In the migration, drop the existing `"allow all"` policy on `players` and replace with two narrower policies: `players_select` (for select, `using (true)`) and `players_insert` (for insert, `with check (true)`)
- [x] In the migration, drop the existing `"allow all"` policy on `player_answers` and replace with a single `player_answers_select` policy (for select, `using (true)`)
- [x] In the migration, create function `submit_answer(p_player_id uuid, p_question_id uuid, p_answer_id uuid) returns void` as `language plpgsql security definer`:
  - INSERT into `player_answers(player_id, question_id, answer_id)` — constraint violation propagates naturally
  - SELECT `a.is_correct`, `q.points` from `answers a join questions q on q.id = a.question_id where a.id = p_answer_id`
  - If `is_correct`, UPDATE `players set score = score + v_points where id = p_player_id`
- [x] Run `nix run nixpkgs#supabase-cli -- db push` to apply the migration

---

## 2. Play page — remove `is_correct` from upfront questions query

The `is_correct` field must no longer be fetched in the initial questions load. This closes the cheat vector (network tab currently exposes correct answers before the player submits).

> **Files:** `src/pages/Play.jsx`. **Watch out:** `is_correct` is currently used in two places: (1) the questions SELECT query (two occurrences — one in the initial load path, one inside the realtime callback that loads questions when the session becomes active), and (2) `answerClassName`, which uses `answer.is_correct` to highlight the correct answer in the feedback view. Step 2 only removes `is_correct` from the query. Step 3 (next section) introduces `correctAnswerIds` state to make `answerClassName` work without it.

- [x] In the initial `load()` function, remove `is_correct` from the answers sub-select in the questions query: change `answers(id, answer_text, is_correct, order_index)` → `answers(id, answer_text, order_index)`
- [x] In the realtime callback that loads questions when `newState === 'active'`, make the same removal to the identical query string
- [x] Add state: `const [correctAnswerIds, setCorrectAnswerIds] = useState([])`
- [x] Reset `correctAnswerIds` to `[]` whenever the question index changes (in the same block that resets `feedbackShown`, `answerSubmitted`, etc.)
- [x] In `answerClassName`, replace `answer.is_correct` with `correctAnswerIds.includes(answer.id)` in both the "highlight correct answer green" and the "dim other answers" logic

---

## 3. Play page — replace direct INSERT with RPC call

Switch `submitAnswer` from a direct `player_answers` INSERT to a call to the `submit_answer` Postgres function. Also update `loadFeedback` to populate `correctAnswerIds` after the question closes.

> **Files:** `src/pages/Play.jsx`. **Watch out:** `supabase.rpc()` returns the same `{ data, error }` shape. When the unique constraint fires inside the function, Supabase propagates it as `error.code === '23505'` — the existing error-handling branch works unchanged. The `loadFeedback` function currently joins `player_answers` with `answers(is_correct)` to check the player's own answer; keep this join since `is_correct` is still valid post-submission. Add a second query inside `loadFeedback` to fetch all correct answer IDs for the question and call `setCorrectAnswerIds`.

- [x] In `submitAnswer`, replace the `supabase.from('player_answers').insert(...)` call with `supabase.rpc('submit_answer', { p_player_id: playerId, p_question_id: question.id, p_answer_id: answer.id })`
- [x] Keep the existing error-handling block unchanged (`error.code === '23505'` → `setAlreadyAnswered(true)`)
- [x] In `loadFeedback`, after the existing `player_answers` fetch, add a query: `supabase.from('answers').select('id').eq('question_id', closedQuestion.id).eq('is_correct', true)` — set `correctAnswerIds` to the returned IDs (or `[]` on error/null)

---

## 4. Smoke test

Run the full flow and verify scores actually accumulate in the DB (they were not written in v0.5) and that `is_correct` is no longer visible in the network tab before answering.

> **User action required:** `nix shell nixpkgs#nodejs -c npm run dev`. Open DevTools Network tab to verify `is_correct` does not appear in the questions response. After answering correctly, check the leaderboard reflects the updated score. **Context:** In v0.5 the leaderboard always showed 0 for all players because scores were never written to the DB — this is the first version where the leaderboard shows real accumulated scores.

- [x] Open DevTools Network tab — confirm the questions fetch response does NOT include `is_correct` in answer objects
- [x] Player answers correctly → leaderboard shows non-zero score matching the question's point value
- [x] Player answers incorrectly → leaderboard shows 0 (or unchanged score from previous questions)
- [x] A second answer attempt (double-click or refresh) still shows "You already answered this question"
- [x] Multiple questions: scores accumulate correctly across questions
- [x] Host ends game → game over screen shown as before
- [x] **RLS negative test:** In the browser DevTools console, run `await supabase.from('players').update({ score: 9999 }).eq('id', localStorage.getItem('player_id'))` and confirm it returns a permissions error (not a silent success)
