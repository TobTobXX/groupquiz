# TODOS — v0.11 Lobby redesign

Redesign the host lobby (waiting room) to be clear, functional, and polished. Primary goal: make it dead easy for players to join. Secondary goal: show who has joined. No tacky background images.

The lobby lives in two files:
- `src/components/HostSession.jsx` — the session shell; passes `joinCode` and `playerCount` as props to `HostLobby`
- `src/components/HostLobby.jsx` — the actual lobby UI (currently just a player count + start button)

---

## 1. Install a QR code library

The QR code must be generated client-side (no external API calls, this is a self-hosted app).

> **Relevant:** `package.json`. The library `qrcode.react` renders a QR code as SVG or canvas from a string value. It is lightweight and has no dependencies.
> **Watch out:** Run install via Nix (`nix shell nixpkgs#nodejs -c npm install qrcode.react`). Commit `package.json` and `package-lock.json` together.

- [x] Install `qrcode.react` via `nix shell nixpkgs#nodejs -c npm install qrcode.react`.
- [x] Verify it appears in `package.json` dependencies.

---

## 2. Expose player nicknames from HostSession to HostLobby

Currently, HostSession only tracks `playerCount` (an integer). The lobby redesign needs the list of nicknames that have joined so far.

> **Relevant:** `src/components/HostSession.jsx` — the `players` realtime subscription (lines ~102–109) and the initial player count fetch (lines ~63–69).
> **Watch out:** The realtime INSERT callback currently only increments a counter. It needs to also capture the `nickname` field from the inserted row (`payload.new.nickname`). The initial load currently uses `{ count: 'exact', head: true }` — change it to a full `select('id, nickname')` to seed the nickname list on mount. Keep `playerCount` in sync by deriving it from `players.length` instead of maintaining a separate counter.

- [x] In `HostSession.jsx`, replace the `playerCount` state with a `players` state (array of `{ id, nickname }`).
- [x] Change the initial player fetch from `select('id', { count: 'exact', head: true })` to `select('id, nickname').eq('session_id', data.id).order('joined_at')` and seed `players` from the result.
- [x] Update the realtime INSERT callback to push `{ id: payload.new.id, nickname: payload.new.nickname }` onto the `players` array.
- [x] Derive `playerCount` as `players.length` wherever it was used (start button label, HostLobby prop). Remove the standalone `playerCount` state.
- [x] Pass `players` as a new prop to `HostLobby` (array of `{ id, nickname }`).

---

## 3. Redesign the lobby layout in HostSession

The current lobby is a small centered card. The new layout uses the full screen and separates join instructions (prominent, top) from the player list (secondary, bottom).

> **Relevant:** `src/components/HostSession.jsx` — the `waiting` block (lines ~279–307) wraps `HostLobby` inside a `max-w-sm` card. The join code and HostLobby are both inside this card.
> **Watch out:** The join code display currently lives in `HostSession`, not in `HostLobby`. The redesign moves it into `HostLobby` — so `joinCode` must be passed as a prop. Also pass the full URL string (e.g. `${window.location.origin}/join/${joinCode}`) so HostLobby can render it without reconstructing it.

- [x] Add `joinCode` and `joinUrl` as props to `HostLobby` (pass them from `HostSession`).
- [x] In `HostSession`, when `sessionState === 'waiting'`, replace the current centered `max-w-sm` card with a full-screen layout that renders just `<HostLobby ...all props... />` (the layout structure moves into HostLobby itself).
- [x] Keep the "← Back to library" top bar outside of `HostLobby` (it belongs to `HostSession`).

---

## 4. Implement the new HostLobby UI

Full redesign of the lobby component. Layout goal: join instructions dominate the screen; player list is below but clearly visible.

> **Relevant:** `src/components/HostLobby.jsx` — currently ~27 lines. This section replaces it entirely.
> **Watch out:**
> - The QR code value must be the full join URL (`https://…/join/CODE`), not just the code.
> - Clicking the join code copies it to clipboard (`navigator.clipboard.writeText`). Show brief visual feedback (e.g. change text to "Copied!" for 1.5 s then revert).
> - The clickable URL below the QR code should be an `<a>` tag with `href={joinUrl}` and `target="_blank"` so hosts can also share it directly.
> - The player list should show up to ~20 nicknames in a wrapping flex row (pill/badge style). If there are more, show "+N more". Keep this area compact — it should not crowd the join instructions.
> - Use `QRCodeSVG` from `qrcode.react` (the SVG variant is preferred over canvas for crisp scaling).

Layout structure (top to bottom):
1. **Join instructions block** — large, centered, takes up ~60% of the viewport height:
   - Heading: "Join at" in muted text, then the app URL (domain only, not the full path) in bold white
   - The 6-character join code in very large text (e.g. `text-8xl font-bold tracking-widest`), styled as clickable (cursor-pointer, hover effect). On click: copy code to clipboard + show feedback.
   - QR code (medium size, ~160–200 px) centred below the code
   - Clickable URL (`/join/CODE`) as a small anchor link below the QR code
2. **Controls row** — shuffle checkbox + Start button, same as today
3. **Player list** — "N player(s) joined" count + nickname pills in a wrapping row; muted/secondary styling

- [x] Replace the entire body of `HostLobby.jsx` with the new layout described above.
- [x] Import `QRCodeSVG` from `qrcode.react`.
- [x] Add a `copied` state (boolean); on join code click: `navigator.clipboard.writeText(joinCode)`, set `copied = true`, reset after 1500 ms with `setTimeout`.
- [x] Render the join code as a clickable element — show "Copied!" briefly when `copied` is true.
- [x] Render `<QRCodeSVG value={joinUrl} size={180} />` with a white background (`bgColor="#ffffff"`) so it's scannable on a dark screen.
- [x] Render `<a href={joinUrl} target="_blank" rel="noreferrer">` with the short URL text below the QR code.
- [x] Render the `players` array as pills. If `players.length > 20`, show the first 20 and append a "+N more" badge.
- [x] Keep the shuffle checkbox and Start button as today (same logic, same props).

---

## 5. Lint + build verification

> **Run after all sections above are complete.**

- [x] `nix shell nixpkgs#nodejs -c npm run lint` — fix any new lint errors.
- [x] `nix shell nixpkgs#nodejs -c npm run build` — verify production build succeeds.
- [ ] Manual smoke test:
  - Start a session → lobby screen appears with large join code, QR code, and URL link.
  - Click the join code → "Copied!" appears briefly, then reverts; clipboard contains just the code.
  - Click the URL link → opens `/join/CODE` in a new tab.
  - Scan the QR code (or open the URL) → Join page loads correctly.
  - Join with two different nicknames → pills appear in the player list.
  - Start the game → transitions to active-question view normally.

---

## 6. Fix GitHub Pages SPA routing

This is a client-side React SPA. Direct navigation to routes like `/login`, `/host`, `/join/CODE`, etc., will 404 on GitHub Pages because only `index.html` exists. GitHub Pages tries to serve `login.html`, `host.html`, etc., which don't exist.

> **Relevant:** Vite build output (only `index.html` is generated), `vite.config.js`, and GitHub Pages configuration.
> **Watch out:** GitHub Pages serves static files and doesn't have server-side routing. For SPAs, all non-file requests must fall back to `index.html` so React Router can handle them client-side. Fix requires either a `404.html` rewrite or Vite's `base` path configuration combined with GitHub Pages settings.

Paths without static HTML files (all client-side routes):
- `/login`
- `/host` (and `/host/:sessionId`)
- `/join/:code` (any join code)
- `/play/:code` (any play code)
- `/create`
- `/edit/:quizId` (any quiz ID)
- `/library` (redirects to `/host`)

Fix options:
1. Add a `404.html` that redirects to `index.html` with hash-based routing
2. Use Vite's SPA fallback in `vite.config.js` + GitHub Pages custom 404 page
3. Change to hash-based routing (`/#/host`, `/#/login`) — requires minimal changes but less clean URLs

- [x] Choose a fix strategy and implement it (404.html fallback to index.html)
- [x] Test that direct navigation to `/login`, `/host`, `/join/ABC`, etc., works on GitHub Pages
- [x] Test that links within the app (React Router navigation) still work correctly
