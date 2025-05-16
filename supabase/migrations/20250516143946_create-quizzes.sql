-- Create enum for quiz visibility
CREATE TYPE quiz_visibility AS ENUM ('private', 'unlisted', 'public');

-- Create quizzes table
CREATE TABLE quizzes (
	id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
	owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
	title TEXT NOT NULL,
	visibility quiz_visibility NOT NULL DEFAULT 'private',
	created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
	updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create questions table
CREATE TABLE questions (
	id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
	quiz_id UUID NOT NULL REFERENCES quizzes(id) ON DELETE CASCADE,
	question_text TEXT NOT NULL,
	answers JSONB NOT NULL,
	max_time INTEGER NOT NULL DEFAULT 30, -- time in seconds
	points INTEGER NOT NULL DEFAULT 1000
);

-- Add Row Level Security (RLS) policies
ALTER TABLE quizzes ENABLE ROW LEVEL SECURITY;
ALTER TABLE questions ENABLE ROW LEVEL SECURITY;

-- Quizzes policies
CREATE POLICY "Users can view non-private or own quizzes" ON quizzes
	FOR SELECT USING (
		visibility != 'private' OR
		owner_id = auth.uid()
	);

CREATE POLICY "Users can insert quizzes" ON quizzes
	FOR INSERT WITH CHECK (auth.uid() = owner_id);

CREATE POLICY "Users can update their quizzes" ON quizzes
	FOR UPDATE USING (auth.uid() = owner_id)
	WITH CHECK (auth.uid() = owner_id);

CREATE POLICY "Users can delete their quizzes" ON quizzes
	FOR DELETE USING (auth.uid() = owner_id);

-- Questions policies
CREATE POLICY "Users can view non-private or own questions" ON questions
	FOR SELECT USING (EXISTS (
		SELECT 1 FROM public.quizzes
		WHERE quizzes.id = questions.quiz_id
		AND (quizzes.visibility != 'private' OR quizzes.owner_id = auth.uid())
	));

CREATE POLICY "Users can insert questions" ON questions
	FOR INSERT WITH CHECK (EXISTS (
		SELECT 1 FROM public.quizzes
		WHERE quizzes.id = quiz_id AND quizzes.owner_id = auth.uid()
	));

CREATE POLICY "Users can update their questions" ON questions
	FOR UPDATE USING (EXISTS (
		SELECT 1 FROM public.quizzes
		WHERE quizzes.id = quiz_id AND quizzes.owner_id = auth.uid()
		))
	WITH CHECK (EXISTS (
		SELECT 1 FROM public.quizzes
		WHERE quizzes.id = quiz_id AND quizzes.owner_id = auth.uid()
	));

CREATE POLICY "Users can delete their questions" ON questions
	FOR DELETE USING (EXISTS (
		SELECT 1 FROM public.quizzes
		WHERE quizzes.id = quiz_id AND quizzes.owner_id = auth.uid()
	));

-- Create triggers for updating updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
	NEW.updated_at = NOW();
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_quizzes_updated_at
BEFORE UPDATE ON quizzes
FOR EACH ROW EXECUTE FUNCTION update_updated_at();
