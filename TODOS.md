# TODOS — v0.10 Robust joining + landing page redesign

Two goals: (1) players can join via a direct URL and rejoin transparently after a disconnect, and (2) the landing page gets a proper layout with auth-aware navigation.

---

## 1. AuthContext: expose signOut

> **Relevant:** `src/context/AuthContext.jsx` — currently exposes only `{ user, loading }`.
> **Watch out:** `signOut` must be stable (no re-creation on re-render) — define it outside the effect or wrap in `useCallback`. The logout button in Home.jsx will call this directly.

- [x] Add `async function signOut() { await supabase.auth.signOut() }` inside `AuthProvider`.
- [x] Add `signOut` to the `AuthContext.Provider` value object.

---

## 2. Switch to code-scoped localStorage format

The current `player_id` key in localStorage is a single flat value, shared across all sessions. Replace it with a per-code key so multiple sessions can coexist and rejoin state is unambiguous.

> **Relevant:** `src/pages/Home.jsx` (writes `player_id`), `src/pages/Play.jsx` (reads `player_id` in 4 places).
> **New format:** key = `` `player_${code}` ``, value = JSON `{ player_id, nickname }`.
> **Invariant:** the entry for a code is only ever cleared when that session reaches `finished` state — not on transient errors, not on reconnect failures. Play.jsx is the right place to do this cleanup since it watches session state via realtime.
> **Watch out:**
> - Play.jsx reads `localStorage.getItem('player_id')` at lines 103, 225, 244, and 315. All four must switch to the new key and parse the JSON value.
> - At line 103 (load effect), if no stored entry is found for this code, redirect to `/join/${code}` via `useNavigate` instead of showing an error. Same for a failed DB player lookup (lines 115–117) — redirect rather than error (it may be a transient failure; don't clear the entry).
> - In the realtime callback, when `newState === 'finished'`: call `localStorage.removeItem(`player_${code}`)` before setting session state. This is the only place entries are cleared.
> - Home.jsx (join-by-code path) currently writes `player_id` at line 40; update to write the new format.

Tasks for Play.jsx:
- [x] Import `useNavigate` in Play.jsx.
- [x] Replace all four `localStorage.getItem('player_id')` calls with parsed access: `JSON.parse(localStorage.getItem(`player_${code}`) ?? 'null')?.player_id`.
- [x] In the load effect (around line 103): if no stored entry for this code, call `navigate(`/join/${code}`, { replace: true })` and return.
- [x] In the load effect (lines 115–117): if player DB lookup fails/returns empty, call `navigate(`/join/${code}`, { replace: true })` and return (do not clear the stored entry).
- [x] In the realtime callback, when `newState === 'finished'`: call `localStorage.removeItem(`player_${code}`)` before updating React state.

Tasks for Home.jsx (join-by-code):
- [x] Replace `localStorage.setItem('player_id', player.id)` with `localStorage.setItem(`player_${code}`, JSON.stringify({ player_id: player.id, nickname }))`.

---

## 3. Join page: /join/:code

A dedicated join page reachable by URL (and later QR code). Handles both fresh joins and transparent rejoin after disconnect. Also handles the rejoin path when a stored entry exists (same logic applies here as in Home.jsx's join-by-code form).

> **Relevant:** New file `src/pages/Join.jsx`. Route added to `src/App.jsx`.
> **Watch out:**
> - Auto-rejoin: verify both that the player record still exists in `players` AND that the session is still active (`state in ['waiting', 'active']`). If either check fails, do NOT clear the stored entry — show the form with nickname pre-filled from the stored entry so the user can rejoin manually (which will create a new player record).
> - Exception: if the session is `finished`, this is the one case where we clear the entry (consistent with Play.jsx) and show a "session ended" error instead of a form.
> - If the session is not found at all (bad/expired code), show an error — do not offer a join form.
> - On successful submit (creating a new player), update the stored entry with the new `player_id`.
> - Show a brief loading state during the auto-rejoin check to avoid a flash of the form.

- [x] Add route `<Route path="/join/:code" element={<Join />} />` in `src/App.jsx`.
- [x] Import `Join` from `./pages/Join` in App.jsx.
- [x] Create `src/pages/Join.jsx`:
  - On mount: read and parse `localStorage.getItem(`player_${code}`)`.
  - **If entry found:**
    - Query `sessions` for the code to get `id` and `state`.
    - If session not found: show "Session not found" error.
    - If `state === 'finished'`: clear entry (`localStorage.removeItem`), show "Session has ended" error.
    - Else (active/waiting): query `players` for the stored `player_id`.
      - If player found: navigate to `/play/${code}` (replace history).
      - If player not found: leave entry intact, pre-fill nickname from stored entry, show form.
  - **If no entry found:**
    - Query `sessions` for the code to check it exists and is not finished.
    - If not found or finished: show appropriate error.
    - Else: show empty form.
  - Form: nickname input (pre-filled if available) + "Join" button.
  - [x] On submit: look up session by code → insert player → store/update `player_${code}` JSON → navigate to `/play/${code}`.

---

## 4. Home.jsx join-by-code: attempt rejoin before creating player

The join-by-code form on the landing page should apply the same rejoin logic — if the user types a code they've played before, reconnect them to their existing player record rather than creating a duplicate.

> **Relevant:** `src/pages/Home.jsx` — `handleSubmit`.
> **Watch out:** The rejoin check runs after the session lookup succeeds. Only skip player creation if a valid stored entry is found AND the player record still exists in DB. If the player record is gone (or session is finished), fall through to create a new player (and update the stored entry). Don't show an error for a missing player — just create a fresh one.

- [x] In `handleSubmit`, after confirming the session exists and is active:
  - Read `localStorage.getItem(`player_${code}`)` and parse.
  - If entry found: query `players` for the stored `player_id`.
    - If player found: update the stored entry (keep same `player_id`, update nickname if changed) → navigate to `/play/${code}` without inserting a new player row.
    - If player not found: fall through to insert a new player.
  - If no entry: proceed with insert as before.
- [x] After insert (new player path): store `player_${code}` JSON with new `player_id` and nickname (already handled in Section 2 task).

---

## 5. Landing page redesign (Home.jsx)

> **Relevant:** `src/pages/Home.jsx`, `src/context/AuthContext.jsx`.
> **Watch out:**
> - Import `useAuth` to get `{ user, loading, signOut }`.
> - While `loading` is true, render neither login nor logout/create buttons to avoid a flash.
> - "Host" button navigates to `/host` — no auth required.

- [x] Import `useAuth` and `useNavigate` in Home.jsx.
- [x] Call `useAuth()` to get `{ user, loading, signOut }`.
- [x] Replace the current layout with:
  - **Top bar**: right-aligned row pinned to top of page.
    - If `!loading && !user`: "Login" button → navigate to `/login`.
    - If `!loading && user`: "Create" button → navigate to `/create`, then "Logout" button → calls `signOut()`.
  - **Center content**: app title, "Host" button → navigate to `/host`.
  - **Join section** below center: "Join via code" heading + the existing join form (code + nickname inputs + Join button).
- [x] Remove the `bg-slate-800` card wrapper — let the join form sit inline.

---

## 6. Lint + build verification

> **Run after all sections above are complete.**

- [ ] `nix shell nixpkgs#nodejs -c npm run lint` — fix any new lint errors.
- [ ] `nix shell nixpkgs#nodejs -c npm run build` — verify production build succeeds.
- [ ] Manual smoke test:
  - Open `/join/ABCDEF` (known good code) with a stored entry → confirm auto-rejoin.
  - Open `/join/ABCDEF` with no stored entry → enter nickname → confirm navigation to play page.
  - Reload `/play/ABCDEF` mid-game → confirm transparent rejoin (no re-entry of nickname).
  - Game ends → confirm `player_${code}` entry is cleared from localStorage.
  - Open `/join/ABCDEF` after session finishes → confirm "session ended" error.
  - Test landing page with and without auth: correct buttons shown.
  - Join via code on home page with a previously-used code → confirm rejoin (no duplicate player row).
