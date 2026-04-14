# TODOS — Streaks

A streak is a run of consecutive correct answers. Starting from the 3rd correct answer in a row, the player earns flames (🔥). Each flame gives +10% bonus on top of the base (time-decayed) points for that question. One wrong answer resets the streak to 0. Missed answers (no submission before time runs out) do not reset the streak.

Flames are shown next to points on every leaderboard view: the post-question feedback leaderboard, the game-over leaderboard for players, and the host's final results leaderboard.

---

## 1. Schema migration: add `streak` to `players` and apply bonus in `submit_answer`

The streak counter lives on the `players` row. `submit_answer` already owns all scoring logic, so it is the right place to read the current streak, apply the flame bonus, and update the streak.

> **Relevant files:**
> - `supabase/migrations/20260418000000_response_time.sql` — most recent `submit_answer` definition; new migration must have a later timestamp.
> - `supabase/migrations/` — pick timestamp `20260419000000`.
>
> **Watch out:**
> - Column default is `0`, not null.
> - The streak fetch must happen **before** the `INSERT INTO player_answers`, so the correct new streak value is applied. Read `players.streak` into a local variable at the top of the function.
> - Flame count: `v_flame_count := greatest(0, (v_streak + 1) - 2)` — i.e. flames kick in only when the new streak ≥ 3. (+1 because the correct answer increments the streak first.)
> - Bonus multiplier: `1.0 + v_flame_count * 0.10`. Apply it to `v_points_earned` (already time-decayed): `v_points_earned := round(v_points_earned * (1.0 + v_flame_count * 0.10))::integer`.
> - Only increment streak on a correct answer; reset to 0 on a wrong answer. A missed answer (no RPC call) leaves the streak unchanged.
> - The `UPDATE players` at the bottom of `submit_answer` must now also set `streak = v_new_streak`. Combine into a single UPDATE: `SET score = score + v_points_earned, streak = v_new_streak`.
> - When the answer is wrong: `v_points_earned` is 0 and `v_new_streak` is 0, so the combined UPDATE sets `streak = 0` (no score change) — correct.
> - Run `nix run nixpkgs#supabase-cli -- db push` after writing the migration.

- [x] Create `supabase/migrations/20260419000000_streaks.sql`.
- [x] `ALTER TABLE players ADD COLUMN streak integer NOT NULL DEFAULT 0;`
- [x] In the new migration, `CREATE OR REPLACE FUNCTION submit_answer(...)` with the full updated body:
  - Declare `v_streak integer; v_new_streak integer; v_flame_count integer;` alongside existing locals.
  - After determining `v_is_correct` (from the answers + questions join), fetch `SELECT streak INTO v_streak FROM players WHERE id = p_player_id;`.
  - Compute `v_new_streak := CASE WHEN v_is_correct THEN v_streak + 1 ELSE 0 END;`.
  - Compute `v_flame_count := GREATEST(0, v_new_streak - 2);` (0 for streaks < 3).
  - Apply flame bonus after the existing `v_points_earned` computation: `IF v_is_correct THEN v_points_earned := ROUND(v_points_earned * (1.0 + v_flame_count * 0.10))::integer; END IF;`
  - Change the final `UPDATE players` to `SET score = score + v_points_earned, streak = v_new_streak WHERE id = p_player_id;` (remove the `IF v_is_correct` guard — the UPDATE now runs unconditionally because wrong answers update streak to 0 with 0 points added).
- [x] Run `nix run nixpkgs#supabase-cli -- db push` to apply.
- [x] Commit the migration.

---

## 2. Include `streak` in all leaderboard fetches

Every place that reads `players` for leaderboard display needs to select the `streak` column so it's available for rendering flames.

> **Relevant files:**
> - `src/pages/Play.jsx` — two leaderboard fetches:
>   1. Inside `loadFeedback` (line ~83): `supabase.from('players').select('id, nickname, score')` → add `streak`.
>   2. Effect 3 (line ~258): same select → add `streak`.
> - `src/components/HostResults.jsx` (line ~20): same select → add `streak`.
> - `src/components/FeedbackView.jsx` — receives `leaderboard` prop; no fetch here, but will consume `streak` from the data.
>
> **Watch out:** The `FeedbackView` leaderboard currently shows only a 3-row slice (player above/self/below). The streak/flame display needs to work on that slice as well as the full list (game-over, HostResults).

- [x] In `Play.jsx` `loadFeedback`, change the players select to `'id, nickname, score, streak'`.
- [x] In `Play.jsx` Effect 3 (finished leaderboard), change the same select to `'id, nickname, score, streak'`.
- [x] In `HostResults.jsx`, change the leaderboard select to `'id, nickname, score, streak'`.

---

## 3. Render flames in all leaderboard views

A helper to compute flame count from a streak value, then flames rendered as 🔥 emoji characters wherever scores appear in leaderboard rows.

> **Relevant files:**
> - `src/components/FeedbackView.jsx` — leaderboard rows AND the result banner.
> - `src/pages/Play.jsx` — game-over leaderboard block (lines 377–396).
> - `src/components/HostResults.jsx` — final leaderboard section.
>
> **Design spec:**
> - `flameCount(streak)` = `Math.max(0, streak - 2)` — 0 flames for streak 0–2, 1 flame at streak 3, etc.
> - Flames are rendered as `'🔥'.repeat(count)` immediately after the score in each leaderboard row. Keep it inline (no separate component needed).
> - In `FeedbackView`'s result banner (the green "Correct!" or red "Wrong" div): when `isCorrect` is true and the player's streak (derived from the leaderboard) yields ≥ 1 flame, append the flames after "+X points". Example: "Correct! +850 points 🔥🔥".
> - The player's streak for the banner is derived from `leaderboard.find(p => p.id === playerId)?.streak ?? 0`. This leaderboard is already loaded by `loadFeedback` before `FeedbackView` is rendered.
>
> **Watch out:**
> - `FeedbackView` already receives `leaderboard` and `playerId` as props — no new props needed for the banner; derive streak inline.
> - The 3-row leaderboard slice in `FeedbackView` comes from the full `leaderboard` array (already has `streak`). Flames should appear in each of the three visible rows.
> - In the game-over leaderboard in `Play.jsx`, every row should show flames — not just the current player's row.
> - In `HostResults.jsx`, the leaderboard section currently shows `nickname` and `score`; add flames after the score.

- [x] In `FeedbackView.jsx`, derive `playerStreak` from `leaderboard.find(p => p.id === playerId)?.streak ?? 0` and `playerFlames = Math.max(0, playerStreak - 2)`.
- [x] Update the "Correct!" banner in `FeedbackView` to append `{'🔥'.repeat(playerFlames)}` after `+${pointsEarned} points` when `playerFlames > 0`.
- [x] In `FeedbackView`'s leaderboard rows, after the score `<span>`, add `{Math.max(0, p.streak - 2) > 0 && <span>{'🔥'.repeat(Math.max(0, p.streak - 2))}</span>}`.
- [x] In `Play.jsx`'s game-over leaderboard (the `sessionState === 'finished'` block), add flames after each player's score in the same pattern.
- [x] In `HostResults.jsx`'s leaderboard section, add flames after each player's score.

---

## 4. Lint + build verification

> **Run after all sections above are complete.**

- [x] `nix shell nixpkgs#nodejs -c npm run lint` — fix any new lint errors.
- [x] `nix shell nixpkgs#nodejs -c npm run build` — verify production build succeeds.
- [ ] Manual smoke test:
  - Start a session; answer Q1 correctly → no flames on feedback leaderboard.
  - Answer Q2 correctly → still no flames.
  - Answer Q3 correctly → 1 flame (🔥) appears next to your score; feedback banner shows "Correct! +X points 🔥".
  - Answer Q4 correctly → 2 flames (🔥🔥) appear; points bonus is ~+20% above base.
  - Answer Q5 wrong → streak resets; no flames on next feedback.
  - Skip a question (don't answer before time runs out) → streak is preserved on the next correct answer.
  - Host's HostResults leaderboard shows flames beside scores of players who ended the game on a streak.
  - Game-over screen for players shows flames beside scores.
