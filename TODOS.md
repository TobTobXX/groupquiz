# TODOs — v0.4: Real-time session sync

---

## 1. Enable realtime on the `sessions` table

Supabase Realtime must be enabled at the database level before any client subscription will receive events. This is a one-time project configuration step.

> **Files:** `supabase/migrations/`. **Watch out:** The Supabase CLI cannot toggle realtime settings — this must be done via the Supabase dashboard (Database → Replication → enable `sessions` table) or by writing a raw SQL migration that calls `ALTER PUBLICATION supabase_realtime ADD TABLE sessions`. **User action required:** Either enable in dashboard or confirm I should use the SQL migration approach.

- [ ] Enable realtime on the `sessions` table (dashboard or migration SQL)

## 2. Host page — realtime subscription

Replace the `useEffect`-only data flow with a Supabase Realtime channel subscription on the `sessions` row. When the DB changes, React state updates from the realtime payload — no refetch needed. This also addresses the v0.4 technical debt item about surviving page refreshes (session ID is already in URL params; the subscription re-derives state from the DB row on connect).

> **Files:** `src/pages/Host.jsx`. **Watch out:** The current `startGame`, `nextQuestion`, and `endGame` functions already call `.update()` on the sessions table — the realtime subscription will mirror those changes back to the same client, so set state only from the payload (not by duplicating the `setSessionState`/`setCurrentQuestionIndex` calls already in those functions). The subscription should start after `sessionId` is known (inside `useEffect`, guarded by a `if (!sessionId) return`). Remember to return a cleanup function that unsubscribes on unmount.

- [ ] Import `useEffect` and `useState` at the top (already imported — confirm).
- [ ] After `sessionId` is set in `createSession`, subscribe to a realtime channel named `host-session-{sessionId}` filtered to the `sessions` table.
- [ ] In the subscription's `on('UPDATE')` handler, destructure `state` and `current_question_index` from the payload and call `setSessionState` / `setCurrentQuestionIndex` from the payload values (not the local state setters in the button handlers).
- [ ] Return a cleanup function from the `useEffect` that calls `channel.unsubscribe()`.
- [ ] Remove the redundant local state updates from `startGame`, `nextQuestion`, and `endGame` (they are now handled by the realtime subscription).

## 3. Play page — realtime subscription

Mirror the same pattern on the Play page. Subscribe to the same `sessions` row filtered by `join_code`. Update `sessionState` and `currentQuestionIndex` from the payload, and when `state` becomes `active` load the questions (unless already loaded).

> **Files:** `src/pages/Play.jsx`. **Watch out:** The existing `useEffect` fetches session data once on mount. The realtime subscription should live in a separate `useEffect` (or merged into the existing one with proper ordering). When `state` transitions from `'waiting'` to `'active'`, the subscription should trigger the question fetch — guard with `if (sessionState !== 'active' && newState === 'active')` to avoid double-fetching. The subscription should also update `currentQuestionIndex` from the payload so advancing questions works without a page reload. When `state` becomes `'finished'`, the game-over screen will display automatically. Return an unsubscribe cleanup function.

- [ ] After the initial session load succeeds, subscribe to a realtime channel named `player-session-{code}` filtered to the `sessions` table.
- [ ] In the subscription's `on('UPDATE')` handler, update `sessionState` from the payload.
- [ ] When `state` transitions to `'active'` (was not active, now is), load the questions from the database if not already loaded.
- [ ] When `state` transitions to `'active'` and `current_question_index` changes, update `currentQuestionIndex` from the payload (derive `question` from the updated index — the existing `question` derivation at the top of the component will recompute automatically since `currentQuestionIndex` is in its dependency chain).
- [ ] When `state` transitions to `'finished'`, update `sessionState` (game-over renders automatically from the existing conditional).
- [ ] Return a cleanup function that unsubscribes on unmount.

## 4. Smoke test

Open the app in two browser windows (host + player) and walk through the full realtime flow.

> **Files:** none to edit. **User action:** Run `nix run nixpkgs#nodejs -- npm run dev` and manually test in the browser. **Watch out:** Tailwind v4 with `@tailwindcss/vite` does JIT class scanning on hot reload — no separate build step needed.

- [ ] Host creates a session and sees the join code.
- [ ] Player opens `/play/{code}` in a second tab, enters a nickname, lands on the waiting screen.
- [ ] Host clicks "Start game" — player screen transitions to the first question without any page reload.
- [ ] Host clicks "Next question" — player screen advances to the next question without any page reload.
- [ ] Host clicks "End game" — player screen shows the game-over screen without any page reload.
- [ ] Refresh the host page — it reconnects to the existing session and shows the correct current state.
