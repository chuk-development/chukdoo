-- Notes sync. Title and content are end-to-end encrypted like every other
-- entity; only ordering and presentation metadata stay in clear columns.
CREATE TABLE notes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  encrypted_payload TEXT NOT NULL,
  color TEXT,
  sort_order INTEGER DEFAULT 0,
  is_pinned BOOLEAN DEFAULT FALSE,
  version INTEGER DEFAULT 1,
  encryption_context TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE notes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage own notes"
  ON notes FOR ALL
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE INDEX idx_notes_user_id ON notes(user_id);

CREATE TRIGGER update_notes_updated_at
  BEFORE UPDATE ON notes
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();
