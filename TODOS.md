# TODOS — v0.10 Navigation overhaul

Coherent navigation across all pages. The home page is the reference point — all other pages get a consistent top bar and explicit exit paths. No page should leave the user stranded.

---

## 1. Merge /library into HostLobby

Library is redundant — HostLobby already lists own quizzes. Absorb the missing features (delete, creation date) and retire /library.

> **Relevant:** `src/components/HostLobby.jsx` (add delete + date), `src/pages/Library.jsx` (delete file), `src/App.jsx` (redirect /library → /host, remove Library import), `src/pages/Login.jsx` (post-login redirect is currently `/library`).
> **Watch out:** HostLobby currently calls `supabase.auth.signOut()` directly — replace with `signOut` from AuthContext for consistency. The `confirm()` dialog for delete in Library is acceptable; reuse the same pattern.

- [ ] In HostLobby, add `signOut` from `useAuth()`.
- [ ] In HostLobby, add a `deleting` state and `handleDelete(quizId)` function (same logic as Library: `confirm()` → supabase delete → filter from state).
- [ ] In HostLobby, add a Delete button next to each own quiz row. Also show creation date (add `created_at` to the select query).
- [ ] In Login.jsx, change the post-login redirect (both password and magic link) from `/library` to `/host`.
- [ ] In App.jsx, replace the `/library` protected route with `<Route path="/library" element={<Navigate to="/host" replace />} />` and add `Navigate` to the react-router-dom import. Remove the `Library` import.
- [ ] Delete `src/pages/Library.jsx`.

---

## 2. HostLobby: consistent top bar

Replace the current ad-hoc header with the same top-bar pattern as Home: left = back, right = auth.

> **Relevant:** `src/components/HostLobby.jsx`.
> **Watch out:** The current header is inline inside the content column. Pull it to a full-width top bar, then keep the content column below it.

- [ ] Add a full-width top bar at the top of the page (outside the `max-w-md` column):
  - Left: `← Home` button → `navigate('/')`.
  - Right: if `!loading && user`: email (small, slate-400) + Logout button; if `!loading && !user`: Sign in button → `navigate('/login')`.
- [ ] Remove the old inline header (`flex items-center justify-between` row with "Host" title and auth links).
- [ ] Replace `supabase.auth.signOut()` call with `signOut()` from `useAuth()`.

---

## 3. HostSession: navigation at each game state

> **Relevant:** `src/components/HostSession.jsx`.
> **Watch out:** `quizId` is already in state — use it directly for "Host again". The `createSession` logic currently lives in HostLobby; duplicate it inline in HostSession (it's small). After "Host again" creates the session, navigate to `/host/${newId}` — but the component is already at `/host/:sessionId`, so `useNavigate` is needed. HostSession currently does not import `useNavigate`.

- [ ] Import `useNavigate` in HostSession.jsx.
- [ ] In waiting state: add a top bar with `← Back to quiz list` button → `navigate('/host')`. Keep it outside the card so it doesn't crowd the join code.
- [ ] Replace the finished state (`<p className="text-2xl font-bold">Game over.</p>`) with a proper end screen:
  - "Game over" heading.
  - "Back to quiz list" button → `navigate('/host')`.
  - "Host again" button → generates a new join code → inserts a new session with the same `quizId` → navigates to `/host/${newSessionId}`.
- [ ] Add a `hostAgain` async function (mirror of HostLobby's `createSession`) that generates a code, inserts the session, and navigates.

---

## 4. Play: end-of-game navigation

> **Relevant:** `src/pages/Play.jsx` — the `sessionState === 'finished'` block (around line 344).

- [ ] In the finished state block, add a "Back to home" button below the "Thanks for playing" text → `navigate('/')`.

---

## 5. Create/Edit: back button

> **Relevant:** `src/pages/Create.jsx` — check where the top of the return JSX is (look for the outermost `div`).
> **Watch out:** Create.jsx has a loading/error guard at the top (returns early). The back button only needs to be in the main render path (and optionally the error path).

- [ ] Add a full-width top bar at the top of the main render:
  - Left: `← Back` button → `navigate('/host')`.
  - Right: nothing (auth not relevant here; user is already authenticated).
- [ ] Optionally add the same back button to the `authError` early-return block so users aren't stuck.

---

## 6. Login: back link

> **Relevant:** `src/pages/Login.jsx`.
> **Watch out:** Login has no `useNavigate` yet — it does actually already import it. Just add a back link below or above the card.

- [ ] Add a `← Back to home` text link (or button) above or below the login card → `navigate('/')`.

---

## 7. Lint + build verification

> **Run after all sections above are complete.**

- [ ] `nix shell nixpkgs#nodejs -c npm run lint` — fix any new lint errors.
- [ ] `nix shell nixpkgs#nodejs -c npm run build` — verify production build succeeds.
- [ ] Manual smoke test:
  - Navigate to /host without auth → Sign in link present, ← Home works.
  - Navigate to /host with auth → Logout/email in top bar, delete a quiz, create a quiz.
  - Navigate to /library → redirects to /host.
  - Start a session (waiting state) → ← Back to quiz list present, click it.
  - Start + finish a session → end screen shows Game over + both buttons; Host again creates a new session.
  - Play through a game to the end → Back to home button appears.
  - Navigate to /create → ← Back button present, click it → lands at /host.
  - Navigate to /login → Back to home link present.
