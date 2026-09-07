CREATE TABLE habits (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  encrypted_payload TEXT NOT NULL,
  color TEXT NOT NULL DEFAULT '#00BFA5',
  frequency TEXT NOT NULL DEFAULT 'daily',
  completions JSONB DEFAULT '[]'::jsonb,
  streak INTEGER DEFAULT 0,
  sort_order INTEGER DEFAULT 0,
  version INTEGER DEFAULT 1,
  encryption_context TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE habits ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage own habits"
  ON habits FOR ALL
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE INDEX idx_habits_user_id ON habits(user_id);

CREATE TRIGGER update_habits_updated_at
  BEFORE UPDATE ON habits
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();
