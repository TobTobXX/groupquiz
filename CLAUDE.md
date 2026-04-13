# Claude Instructions

## Project overview

This is a self-hostable real-time quiz platform — a better Kahoot. Read the planning documents before doing any work:

- **[GOAL.md](GOAL.md)** — what we're building and for whom (player, host, quiz creator)
- **[TECHNOLOGIES.md](TECHNOLOGIES.md)** — stack decisions and why (React, Supabase, no server)
- **[STEPS.md](STEPS.md)** — nine incremental versions (v0.1–v0.9), each with a checklist
- **[TODOS.md](TODOS.md)** — detailed task list for the current version being worked on

Always read these files at the start of a session to orient yourself before touching any code.

## Current focus

Work through TODOS.md top to bottom. When a task is done, check it off in TODOS.md immediately. When all tasks in a section are done, check off the corresponding item in the STEPS.md checklist for the current version.

## Running tools

Most tools are not installed globally. Run them via Nix:

```
nix run nixpkgs#nodejs     -- ...   # node, npm, npx
nix run nixpkgs#supabase   -- ...   # supabase CLI
```

When a command would normally be `npm install`, use `nix run nixpkgs#nodejs -- npm install` (or wrap it in `nix shell nixpkgs#nodejs` for a multi-step workflow). Apply the same pattern for any other tool that may not be on PATH.

## Git discipline

Commit frequently — after every logical unit of work (a new file, a working feature, a schema change). Do not batch unrelated changes into one commit. Commit messages should be short and describe what changed, not just which files were touched.

Example cadence:
- Add Vite + React project scaffold → commit
- Add Tailwind → commit
- Add Supabase client → commit
- Add DB migration → commit
- Implement host page → commit
- Implement home page → commit
- etc.

## Environment

- Supabase credentials are in `.env` as `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY`. Never hardcode these.
- `.env` is gitignored — do not commit it.
- There is no dynamic server. The frontend talks directly to Supabase via the JS client.

## Key constraints

- No RLS policies until v0.8 — but do enable RLS on each table in the migration so adding policies later requires no schema change.
- No real-time until v0.4.
- No auth until v0.8.
- Do not add features beyond what the current version's TODOS.md specifies.
