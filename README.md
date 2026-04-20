# Groupquiz

A simple and clean real-time quiz platform. No accounts required to play, no artificial limits, no noise in the UI.

**Try it:** https://groupquiz.tobtobxx.net/

## How it works

- **Quiz creator** — needs an account; creates and manages quizzes with multiple-choice questions, optional images, per-question time limits and point values.
- **Host** — starts a live session from any public quiz; no account needed. Shares a 6-character join code with players. Advances questions manually, sees live response progress, and gets a full breakdown at the end.
- **Player** — joins with just a code and a nickname. No sign-up. Gets immediate feedback after each answer and sees a live leaderboard between questions.

Scoring is time-decayed and computed server-side. Consecutive correct answers earn a streak bonus.

## Quiz import / export

Quizzes can be exported as self-contained `.json` files (images are base64-embedded) and imported on any instance via the host library screen.

You can use this script [here](scripts/kahoot.com-export.js) to export your quizzes from kahoot.com.
Just go to https://create.kahoot.it/my-library/kahoots/all, open the developer console with F12, paste this script and press Enter. An "Export All Quizzes" button will appear.

## Technology stack

- **Frontend:** React 19, React Router v7, Tailwind CSS v4, Vite
- **Backend:** Supabase (PostgreSQL, Auth, Realtime, Storage, pg_cron)
- **No dynamic server** — the compiled static app talks directly to Supabase via the JS client.

## Self-hosting

You need a Supabase project and a static host (Netlify, GitHub Pages, Vercel, etc.).

1. Create a Supabase project.
2. Apply all migrations in `supabase/migrations/` in order (`supabase db push` if you have the CLI linked).
3. Copy `.env.example` to `.env` and fill in `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY`.
4. Build: `npm run build` (or `nix shell nixpkgs#nodejs -c npm run build`).
5. Deploy the `dist/` directory to any static host.

## Development

Prerequisites: [Nix](https://nixos.org/) and a Docker-compatible container runtime ([Docker Desktop](https://docs.docker.com/desktop/), [Podman](https://podman.io/), etc.).

If using **Podman**, export the socket path before running any Supabase CLI commands:
```sh
export DOCKER_HOST=unix:///run/user/1000/podman/podman.sock
```

### First-time setup

**1. Install Node dependencies:**
```sh
nix shell nixpkgs#nodejs -c npm install
```

**2. Start local Supabase** (pulls Docker images and applies all migrations):
```sh
nix run github:nixos/nixpkgs/nixpkgs-unstable#supabase-cli -- start
```
Studio is at http://localhost:54323. The command output includes a local anon key — you need it in the next step.

**3. Create `.env.local`** (gitignored) with the local credentials:
```
VITE_SUPABASE_URL=http://127.0.0.1:54321
VITE_SUPABASE_ANON_KEY=<anon key from step 2>
```

**4. Create `supabase/functions/.env`** (gitignored) with dev Stripe credentials — see `supabase/functions/.env.example` for the template.

**5. Run the frontend:**
```sh
nix shell nixpkgs#nodejs -c npm run dev
```

**6. (Optional) Serve Edge Functions locally:**
```sh
nix run github:nixos/nixpkgs/nixpkgs-unstable#supabase-cli -- functions serve --env-file supabase/functions/.env
```
A Stripe test webhook tunnel (e.g. `stripe listen --forward-to localhost:54321/functions/v1/stripe-webhook`) is needed to test the full subscription flow end-to-end.

### Daily workflow

```sh
# Start Supabase (if stopped; preserves DB data)
nix run github:nixos/nixpkgs/nixpkgs-unstable#supabase-cli -- start

# Run the frontend dev server
nix shell nixpkgs#nodejs -c npm run dev

# Reset the database (reruns all migrations + seed data)
nix run github:nixos/nixpkgs/nixpkgs-unstable#supabase-cli -- db reset
```

The seed data (`supabase/seed.sql`) provides a public "Sample Quiz" so Browse and the full play flow work without creating an account.
