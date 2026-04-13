# v0.7 — Quiz Creator UI

Build the quiz editor: create a new quiz, add/edit/delete questions, set answer options (2–4), mark correct answers, set time limits and point values, attach images. Still no auth — any visitor can create quizzes.

---

## Section 1 — Route and scaffold

> **Briefing:** No new tables needed. Add `/create` route, stub page, wire up redirect on save. Relevant files: `src/App.jsx`, new `src/pages/Create.jsx`.

- [ ] Add `/create` route to `src/App.jsx`
- [ ] Create `src/pages/Create.jsx` with state: `title`, `questions[]`
- [ ] Add save button (disabled until valid) and cancel/back button
- [ ] On successful save, navigate to `/host`
- [ ] On cancel, navigate to `/host`

---

## Section 2 — Question editor component

> **Briefing:** `QuestionEditor` is the core reusable piece. It takes an index and a question object, emits changes up via callback. Each question has: text, time_limit, points, image_url, answers[]. Each answer has: text, is_correct. Relevant file: new `src/components/QuestionEditor.jsx`.

- [ ] Create `src/components/QuestionEditor.jsx`
- [ ] Props: `index`, `question` object, `onChange`, `onDelete`
- [ ] Question text input
- [ ] Time limit input (integer, seconds, default 30)
- [ ] Points input (integer, default 1000)
- [ ] Image URL input (text, no upload — just a URL field)
- [ ] Answer options section: 2–4 rows, each with text input + correct toggle (radio for single-correct, checkbox for multi — use radio to keep it simple unless checked)
- [ ] "Add answer" button (disabled when at 4 answers)
- [ ] "Remove answer" button per row (disabled when at 2 answers)
- [ ] Delete question button (emits `onDelete`)
- [ ] Visual question number label (passed as `index + 1`)

---

## Section 3 — Quiz title and question list

> **Briefing:** `Create.jsx` assembles the full form. Quiz title at top, list of `QuestionEditor` components, "Add Question" button. All state lives in `Create.jsx`.

- [ ] Add quiz title input at top of `Create.jsx`
- [ ] Map `questions[]` state to `QuestionEditor` components with index
- [ ] Each `QuestionEditor` receives `onChange(question)` and `onDelete(index)`
- [ ] "Add Question" button appends a blank question (with 2 empty answers, both incorrect, time_limit=30, points=1000) to state
- [ ] Initial state: one empty question on mount
- [ ] Checkbox for "multiple correct answers" mode per question? — **Skip for v0.7; single-correct radio is fine per GOAL spec (multi-correct is possible, just UI doesn't need to toggle)**

---

## Section 4 — Save to Supabase

> **Briefing:** Validate, then insert quiz → questions → answers sequentially, collecting IDs. Show inline error on failure. Relevant: `src/lib/supabase.js`.

- [ ] Validate on save: title non-empty, at least 1 question, each question has non-empty text, at least 1 correct answer
- [ ] Show inline validation errors (red text below each invalid field)
- [ ] Insert `quizzes` row → get `quiz_id`
- [ ] Insert `questions` rows with `quiz_id` → collect `question_id`s by `order_index`
- [ ] Insert `answers` rows with correct `question_id` from mapping
- [ ] On DB error: set error state, do not navigate
- [ ] On success: navigate to `/host`
- [ ] Loading state on save button while pending

---

## Section 5 — Link from host page

> **Briefing:** Add a way to reach the quiz creator from the host page's quiz selection screen.

- [ ] Add "Create a new quiz" link/button on `src/pages/Host.jsx` below the quiz list (or above it)
- [ ] Link navigates to `/create`

---

## Section 6 — Commit and verify

- [ ] Run `npm run lint`
- [ ] Run `npm run build` (verify no build errors)
- [ ] Manual smoke test in browser: create quiz, add questions, save, see it in host page
