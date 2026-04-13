# Technologies

## Architecture

There is no dynamic server. The app consists of two parts:

- **Supabase** — the entire backend: database, auth, real-time, and server-side logic.
- **Static host** — serves the compiled React app (HTML/CSS/JS). Any static host works (Vercel, Netlify, GitHub Pages, etc.).

All authorization is enforced via Postgres Row Level Security (RLS) policies. Business logic that must be tamper-proof (e.g. score calculation) runs inside the database as Postgres functions, invoked by the client but executed server-side within Supabase.

## Backend: Supabase

- **PostgreSQL** — primary data store for quizzes, questions, sessions, answers, and scores.
- **Row Level Security (RLS)** — enforces who can read and write what, directly at the database level.
- **Supabase Auth** — handles quiz creator accounts. Players do not need an account.
- **Supabase Realtime** — WebSocket-based pub/sub over Postgres changes. Used for syncing session state across host and all players in real time.
- **Postgres Functions** — used for logic that must run server-side, most importantly score calculation on answer submission.

## Frontend: React

- **React** — UI framework. Supabase Realtime subscriptions integrate naturally with React state via `useEffect`.
- **Supabase JS client** — communicates with Supabase directly from the browser (REST for data, WebSockets for Realtime).
- **Vite** — build tool and dev server.
- **Tailwind CSS** — utility-first styling, no custom CSS infrastructure needed.
