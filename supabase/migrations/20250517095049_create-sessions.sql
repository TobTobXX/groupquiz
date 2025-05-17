-- Create session state enum type
CREATE TYPE session_state AS ENUM ('waiting', 'question', 'answer_reveal', 'scoreboard', 'completed');

-- Create sessions table
CREATE TABLE sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code TEXT NOT NULL UNIQUE, -- Join code for participants
  quiz_id UUID NOT NULL REFERENCES quizzes(id) ON DELETE CASCADE,
  host_id UUID NOT NULL REFERENCES auth.users(id), -- Quiz host/owner
  current_state session_state NOT NULL DEFAULT 'waiting',
  current_question_index INTEGER NOT NULL DEFAULT 0, -- Tracks progression through questions
  state_changed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(), -- When the current state was entered
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  ended_at TIMESTAMP WITH TIME ZONE -- NULL until session completed
);

-- Simple random code generation function
CREATE OR REPLACE FUNCTION generate_session_code()
RETURNS TEXT
LANGUAGE sql
AS $$
  SELECT array_to_string(array(
    SELECT substring('0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ' FROM floor(random() * 36 + 1)::int FOR 1)
    FROM generate_series(1, 6)
  ), '');
$$;

-- Trigger to set random code before insert if not provided
CREATE OR REPLACE FUNCTION set_session_code()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.code IS NULL OR NEW.code = '' THEN
    -- Keep trying until we get a unique code
    LOOP
      NEW.code := generate_session_code();
      EXIT WHEN NOT EXISTS (SELECT 1 FROM sessions WHERE code = NEW.code);
    END LOOP;
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER ensure_session_code
BEFORE INSERT ON sessions
FOR EACH ROW
EXECUTE FUNCTION set_session_code();

-- Row Level Security
ALTER TABLE sessions ENABLE ROW LEVEL SECURITY;

-- Host can do anything with their own sessions
CREATE POLICY "Hosts can manage their own sessions"
  ON sessions FOR ALL
  TO authenticated
  USING (host_id = auth.uid());

-- Anyone can view any active session
CREATE POLICY "Anyone can view active sessions"
  ON sessions FOR SELECT
  TO anon, authenticated
  USING (ended_at IS NULL);