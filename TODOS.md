# TODOS — v0.10 Results, polish, and full flow

Post-session results for host, enhanced host controls (pause, skip, replay), player end screen, and UI polish.

---

## 1. Database: response_time column on player_answers

> **Relevant:** `supabase/migrations/..._time_based_scoring.sql` — `player_answers` table; `submit_answer` function.
> **Watch out:** `player_answers` rows are written by `submit_answer`. The function must record `created_at - question_opened_at` as `response_time_ms`. Use `extract(epoch from (now() - v_opened_at)) * 1000`.

Migration:
- Add `response_time_ms integer` nullable to `player_answers`.
- Update `submit_answer` to insert `response_time_ms` from the elapsed calculation.
- No other tables needed.

---

## 2. Frontend: host post-session results screen

> **Relevant:** `src/pages/Host.jsx` — `sessionState === 'finished'` branch currently shows bare "Game over.".
> **Watch out:** Requires fetching all `player_answers` + `players` + `questions` for the session. Build response distribution from `session_question_answers` mapping.

Update `Host.jsx` `finished` state to show:
- Final leaderboard: all players ordered by score, with current player's rank highlighted.
- Per-question breakdown table: question text (truncated), answer count, correct %, avg response time.
- "Host new session" button → navigate to `/host`.

Query plan:
- `players` for session, ordered by score.
- `player_answers` with `answers(is_correct)` for correctness stats.
- `session_question_answers` for answer text mapping.

---

## 3. Frontend: host enhanced controls

> **Relevant:** `src/pages/Host.jsx` — active session controls.
> **Watch out:** `sessions` table has no `paused` column. Implement pause as `question_open = false` + a `state = 'paused'` intermediate state, or a dedicated `is_paused boolean` column on `sessions`.

Add to active session UI:
- **Pause/Resume**: toggle question acceptance. Update `sessions` row. Players see "Paused" overlay.
- **Previous question**: re-open a past question (only if `current_question_index > 0`). Re-fetch slots for that question. Players can re-answer.
- **Replay question**: show the current question again (same slots, timer resets). Re-opens `question_open = true`.

State model options:
- Option A: `state: 'waiting' | 'active' | 'paused' | 'finished'`. Requires migration.
- Option B: Add `is_paused boolean default false` to `sessions`. `current_question_index` still advances linearly.

Option B is simpler — prefer it unless Option A is clearly better.

---

## 4. Frontend: player end-of-game screen

> **Relevant:** `src/pages/Play.jsx` — `sessionState === 'finished'` currently shows bare "Game over".
> **Watch out:** Players should see their final rank and score. The leaderboard data is already loaded by `loadFeedback`. The finished state should reuse the leaderboard data.

Update `Play.jsx` `finished` state:
- Fetch final leaderboard (players ordered by score).
- Show player's rank, score, and how many players total.
- "Play again?" prompt (no-op — player needs a new join code from host).
- Subscribe to `state = 'finished'` realtime event to trigger the end screen.

---

## 5. UI polish pass

> **Relevant:** All pages.
> **Watch out:** This is a catch-all for consistency issues. Focus on the most jarring ones.

Checklist:
- [ ] Host quiz list: ensure public/own sections don't double-render if a quiz is both public AND owned (deduplicate or merge).
- [ ] Play: question slot icons are large; verify they scale well on mobile.
- [ ] Host: question progress text uses `currentQuestionIndex + 1` — confirm it matches the actual question shown (accounting for replay/previous).
- [ ] All pages: no hardcoded strings that should be dynamic.
- [ ] Colors: ensure consistent use of slate-50 through slate-900 across all cards/buttons.

---

## 6. Push migration + lint + build

> **Run after each step above.**

- `nix shell nixpkgs#supabase-cli -c supabase db push` after DB migration.
- `nix shell nixpkgs#nodejs -c npm run lint` after each frontend change.
- `nix shell nixpkgs#nodejs -c npm run build` to verify production build.
- Manual test: host → play → finish → view results → host new session.
