# TODOS — v0.11 Results, polish, and full flow

Post-session results screen for the host: final leaderboard, per-question response distribution, average response time, and % correct. Host controls are complete: pause, back, replay. Auto-close when the timer expires. The full flow works end-to-end. UI is polished across all screens.

---

## 1. Schema migration: store response time per answer

`player_answers` currently stores `points_earned` but not how long the player took to answer. Average response time on the results screen requires this. The `submit_answer` RPC already computes `v_elapsed` (seconds) — it just doesn't store it. Add a column and persist it.

> **Relevant:** `supabase/migrations/20260417000000_split_screen.sql` (most recent `submit_answer` definition). New migration file must have a later timestamp.
> **Watch out:**
> - Column type: `integer` (milliseconds, rounded), nullable (null = question had no time limit).
> - In the RPC, `v_elapsed` is in seconds (numeric). Store as `round(v_elapsed * 1000)::integer` when `v_time_limit is not null and v_time_limit > 0`; else store `null`.
> - Run `nix run nixpkgs#supabase-cli -- db push` after writing the migration to apply it to the remote DB.
> - The migration must also add an open RLS policy on `player_answers` for the new column (the existing policy is `for all using (true)` which already covers it — no policy change needed).

- [x] Create `supabase/migrations/20260418000000_response_time.sql`.
- [x] `ALTER TABLE player_answers ADD COLUMN response_time_ms integer;` (nullable, no default).
- [x] Rewrite `submit_answer` in the migration: after computing `v_elapsed`, also compute `v_response_time_ms := case when v_time_limit is not null and v_time_limit > 0 then round(v_elapsed * 1000)::integer else null end;` and include it in the `INSERT INTO player_answers` row.
- [x] Run `nix run nixpkgs#supabase-cli -- db push` to apply the migration.
- [x] Commit the migration file.

---

## 2. Create `HostResults` component

A new full-width component shown when the session is finished. Two sections: (a) final leaderboard, (b) per-question accordion or list showing response distribution, % correct, and average response time.

> **Relevant:** `src/components/HostSession.jsx` (finished block, lines 345–363), `src/lib/slots.js` (SLOT_COLOR_HEX, SLOT_ICONS), `src/components/SlotIcon.jsx`.
> **Data to fetch on mount:**
> 1. Players sorted by score descending: `supabase.from('players').select('id, nickname, score').eq('session_id', sessionId).order('score', { ascending: false })`.
> 2. Questions for the quiz: `supabase.from('questions').select('id, question_text, time_limit, points, order_index').eq('quiz_id', quizId).order('order_index')`.
> 3. All answers for those questions: `supabase.from('answers').select('id, question_id, answer_text, is_correct').in('question_id', questionIds)`.
> 4. Slot assignments for this session: `supabase.from('session_question_answers').select('question_id, slot_index, answer_id, color, icon').eq('session_id', sessionId)`.
> 5. All player answers for this session: `supabase.from('player_answers').select('question_id, answer_id, response_time_ms').in('player_id', playerIds)` (playerIds come from the players fetch in step 1).
> **Watch out:**
> - The `playerIds` for step 5 come from step 1's result, so fetch steps 1–2 in parallel, then steps 3–5 sequentially after the question IDs and player IDs are known. (Or do all sequentially — this is a results screen, not a real-time view.)
> - For the response distribution, group `player_answers` by `(question_id, answer_id)` then join to `session_question_answers` to map `answer_id → slot_index`. Count per slot, then render a bar for each slot.
> - Average response time: `mean(response_time_ms)` across all `player_answers` for that question where `response_time_ms is not null`. Display as `"X.Xs"` rounded to 1 decimal.
> - % correct: `(# of player_answers for this question where the chosen answer is_correct) / (total # of player_answers for this question) * 100`. Join via `answers.is_correct`.
> - Slots may be 2, 3, or 4 per question (based on the question's answer count). Only render bars for slots that exist.
> - If no players answered a question (all skipped), avoid division-by-zero and show "–" for % correct and avg time.

- [x] Create `src/components/HostResults.jsx`. Props: `sessionId`, `quizId`, `players` (array of `{ id, nickname, score }` already known to HostSession).
- [x] On mount, fetch all five datasets described above. Store in local state: `leaderboard`, `questions`, `answersByQuestionId` (map), `slotsByQuestionId` (map), `playerAnswersByQuestionId` (map). Show a loading spinner while fetching.
- [x] Render the **final leaderboard** section: numbered list of players sorted by score, highlight top 3 with gold/silver/bronze styling. Show each player's nickname and score.
- [x] Render the **per-question breakdown** section: for each question in order, show:
  - Question number and question text.
  - % correct (integer, e.g. "67% correct") and avg response time (e.g. "Avg 4.2s"), side by side.
  - Response distribution: for each slot that exists, a horizontal bar proportional to the count of players who chose that slot. Use the slot's color (`SLOT_COLOR_HEX[slot.color]`) and render `<SlotIcon>` + count + (tick if correct). Bar width: percentage of total answers.
- [x] At the bottom, render the two action buttons that currently live in HostSession's finished block: "Back to library" (navigate to `/host`) and "Host again" (call `onHostAgain`). Remove these from HostSession's finished block.

---

## 3. Wire `HostResults` into `HostSession`

Replace the minimal "Game over" card in `HostSession`'s `sessionState === 'finished'` block with `<HostResults>`.

> **Relevant:** `src/components/HostSession.jsx` lines 345–363 (the finished block), `hostAgain()` function (lines 277–287).
> **Watch out:** `HostResults` needs `sessionId`, `quizId`, and the current `players` array — all of which are already in `HostSession` state. The `hostAgain` callback should remain in `HostSession` (it navigates and knows `quizId`); pass it as `onHostAgain` prop to `HostResults`.

- [x] Import `HostResults` in `HostSession.jsx`.
- [x] Replace the finished `<div>` block with `<HostResults sessionId={sessionId} quizId={quizId} players={players} onHostAgain={hostAgain} />`.
- [x] Verify the back-to-library nav bar still appears when the session is finished (it currently only renders in `waiting` state — consider rendering it in all non-active states, or let HostResults handle its own nav).

---

## 4. Fix "Host again"

When the host clicks "Host again", `hostAgain()` creates a new session and navigates to `/host?sessionId=<new-id>`. But `Host.jsx` renders `<HostSession sessionId={sessionId} />` and React does not remount the component when only the search param changes — so the new session's `useEffect([], [])` never runs and the old state persists.

> **Relevant:** `src/pages/Host.jsx` (line 8), `src/components/HostSession.jsx` `useEffect` on mount.
> **Fix:** Add `key={sessionId}` to the `<HostSession>` in `Host.jsx`. React treats components with different `key` values as entirely different instances, forcing a clean remount when the sessionId changes.

- [x] In `Host.jsx`, change `<HostSession sessionId={sessionId} />` to `<HostSession key={sessionId} sessionId={sessionId} />`.
- [x] Manually verify: start a session, finish a game, click "Host again" → lobby appears fresh with the new join code, not the old state.

---

## 5. Host controls: pause, back, replay

Extend the active-question view with three new controls. All three live in `HostSession` (logic) and `HostActiveQuestion` (UI).

> **Relevant:** `src/components/HostSession.jsx` (functions `nextQuestion`, `closeQuestion`; state `isPaused`), `src/components/HostActiveQuestion.jsx` (button row, lines 90–111).
> **Watch out:**
> - **Pause** is client-side only — it stops the host's countdown timer but does NOT write to the DB. Players don't see a timer, so there is no server-side concept of pause needed. Implement as `isPaused` boolean in `HostSession` state. Pass it to `HostActiveQuestion` (display "Resume" vs "Pause") and use it in the timer `useEffect` to skip ticking.
> - **Back** mirrors `nextQuestion()` exactly but with `next = currentQuestionIndex - 1`. Call `assign_answer_slots` for the previous question — the RPC deletes existing assignments before re-inserting, so this is safe. The back button must be disabled when `currentQuestionIndex === 0`.
> - **Replay** re-opens the current question: call `assign_answer_slots` for the current question ID (same shuffle setting), then update the session with `{ question_open: true, current_question_slots: slots }`. This resets the timer on the host. Players who already answered this question cannot answer again (unique constraint), but they'll see the question screen again. Replay is only available when `!questionOpen` (i.e. the question has already been closed).
> - When the host navigates back or replays, reset `answerCount` to 0 and reset `isPaused` to `false`.

- [x] Add `isPaused` state (boolean, default `false`) to `HostSession`.
- [x] In the timer `useEffect` (`setInterval` callback), skip decrement when `isPaused` is true: `setTimeRemaining((t) => { if (isPaused) return t; ... })`. Also add `isPaused` to the effect's dependency array.
- [x] Add `togglePause` handler: `setIsPaused((p) => !p)`. Reset `isPaused` to `false` whenever `currentQuestionIndex` or `questionOpen` changes (add a `useEffect` that calls `setIsPaused(false)` on those deps).
- [x] Add `previousQuestion()` async function: same as `nextQuestion()` but decrement. After slots are assigned and the session update succeeds, also call `setAnswerCount(0)` and `setIsPaused(false)`.
- [x] Add `replayQuestion()` async function: call `assign_answer_slots` with the current question's ID, then update the session `{ question_open: true, current_question_slots: slots }`. Call `setAnswerCount(0)` and `setIsPaused(false)` on success.
- [x] Pass `isPaused`, `onPause` (togglePause), `onBack` (previousQuestion), `onReplay` (replayQuestion) to `HostActiveQuestion`.
- [x] In `HostActiveQuestion`, add a **Pause/Resume** button in the controls row: show "Pause" when `!isPaused`, "Resume" when `isPaused`. Disable when `!questionOpen`.
- [x] Add a **← Back** button: disabled when `currentQuestionIndex === 0` or `loadingSlots`. Place it to the left of the existing controls.
- [x] Add a **Replay** button: disabled when `questionOpen` (only available after the question has closed) or `loadingSlots`. Clicking it calls `onReplay`.

---

## 6. Auto-close when the timer expires

Currently the countdown reaches 0 and stops — but the question remains open until the host manually clicks "Finish". The question should close automatically when time runs out.

> **Relevant:** `src/components/HostSession.jsx`, the timer `useEffect` (lines 182–197). The `closeQuestion()` async function (lines 260–267).
> **Watch out:**
> - The `setInterval` callback runs every second. When `t <= 0`, it currently clears the interval and returns 0. Add a call to `closeQuestion()` at that same point.
> - Do not call `closeQuestion()` inside the `setTimeRemaining` updater function — call it as a side effect alongside it. Specifically: capture whether `t` has reached 0 outside the updater and call `closeQuestion()` after `setTimeRemaining`.
> - The `questionOpen` check inside `closeQuestion` (`if (!questionOpen) return`) is a safeguard but reads stale closure state. Use a ref (`questionOpenRef`) that stays in sync to guard against double-close. If `questionOpenRef.current` is already false, skip the call.
> - Only auto-close when the session is `active` and the question has a time limit. Questions with `time_limit === null` should not auto-close (the interval is never started for them since the existing timer logic returns early when `question.time_limit ?? 30` — actually it defaults to 30 even for null; check this).

- [x] Add `questionOpenRef = useRef(questionOpen)` and keep it in sync with a `useEffect`: `useEffect(() => { questionOpenRef.current = questionOpen }, [questionOpen])`.
- [x] In the timer `useEffect`'s `setInterval` callback: when `t <= 0`, after clearing the interval, call `closeQuestion()` only if `questionOpenRef.current === true`.
- [x] Verify: start a question with a 5-second time limit → question auto-closes after 5 seconds without host intervention.

---

## 7. Player finished screen: show final leaderboard

Currently the player's "game over" screen shows only a text message and a "Back to home" button. Show the final leaderboard so players can see how they ranked.

> **Relevant:** `src/pages/Play.jsx`, the `sessionState === 'finished'` block (lines 354–365). The `leaderboard` state is already populated when `loadFeedback` runs, but may be stale or empty if the session finishes without the player seeing a feedback screen.
> **Watch out:** When the session transitions to `finished` via realtime, `loadFeedback` is NOT called — only a state set to `'finished'` happens. So `leaderboard` may be empty at that point. Fetch the leaderboard explicitly when `sessionState` becomes `'finished'`: in the realtime callback, after setting `setSessionState('finished')`, call a separate async fetch of players sorted by score.
> - Use a `useEffect` that watches `sessionState` — when it becomes `'finished'`, fetch the leaderboard if it isn't already populated.
> - Pass `playerId` to the finished block so the player's row can be highlighted.

- [x] In `Play.jsx`, add a `useEffect` that triggers when `sessionState === 'finished'` and `sessionId` is known: fetch `players` sorted by score descending, set `leaderboard` from the result.
- [x] In the `sessionState === 'finished'` render block, replace the current text-only display with:
  - "Game over" heading.
  - "Thanks for playing, **{nickname}**!" subtext.
  - A scrollable leaderboard list (same style as `FeedbackView`): numbered, highlight the current player's row in indigo, show nickname + score.
  - "Back to home" button below the list.

---

## 8. Lint + build verification

> **Run after all sections above are complete.**

- [x] `nix shell nixpkgs#nodejs -c npm run lint` — fix any new lint errors.
- [x] `nix shell nixpkgs#nodejs -c npm run build` — verify production build succeeds.
- [x] Manual smoke test:
  - Start a session with ≥2 players; run through all questions.
  - Timer auto-closes the question when it reaches 0.
  - Host clicks Pause → countdown freezes; Resume → countdown resumes.
  - Host clicks ← Back → previous question appears for all players; Back button disabled on Q1.
  - Host closes a question then clicks Replay → question reopens for players (existing answers preserved — players who answered cannot answer again).
  - Host clicks End → results screen appears with leaderboard and per-question breakdown.
  - Each question's breakdown shows correct slot bar(s) ticked, answer counts, % correct, avg response time.
  - "Host again" → fresh lobby with a new join code (no stale state from prior game).
  - Player "game over" screen shows the final leaderboard with their row highlighted.
