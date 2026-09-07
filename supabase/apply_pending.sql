-- ============================================================================
-- Chukdoo — everything the app needs on the server, in one idempotent script.
--
-- Paste this into the Supabase SQL editor (or run `supabase db push` instead).
-- Running it twice is safe: every object is guarded, so already applied parts
-- are skipped.
--
-- Covers the tables the app syncs but this project does not have yet:
-- calendars, calendar_events and habits. The notes table already exists and
-- is re-checked here (harmless). Todos and projects are left untouched.
-- ============================================================================

-- ── Calendars ───────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS calendars (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  encrypted_payload TEXT NOT NULL,
  color TEXT DEFAULT '#4285F4',
  is_default BOOLEAN DEFAULT FALSE,
  is_visible BOOLEAN DEFAULT TRUE,
  sort_order INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS calendar_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  calendar_id UUID REFERENCES calendars(id) ON DELETE SET NULL,
  encrypted_payload TEXT NOT NULL,
  start_time TIMESTAMPTZ NOT NULL,
  end_time TIMESTAMPTZ NOT NULL,
  is_all_day BOOLEAN DEFAULT FALSE,
  color TEXT,
  recurrence_rule TEXT,
  recurrence_id UUID REFERENCES calendar_events(id) ON DELETE CASCADE,
  original_start_time TIMESTAMPTZ,
  reminder_minutes INTEGER[] DEFAULT '{}',
  sort_order INTEGER DEFAULT 0,
  version INTEGER DEFAULT 1,
  encryption_context TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_calendars_user ON calendars(user_id);
CREATE INDEX IF NOT EXISTS idx_calendar_events_user ON calendar_events(user_id);
CREATE INDEX IF NOT EXISTS idx_calendar_events_calendar ON calendar_events(calendar_id);
CREATE INDEX IF NOT EXISTS idx_calendar_events_time_range
  ON calendar_events(start_time, end_time) WHERE recurrence_id IS NULL;
CREATE INDEX IF NOT EXISTS idx_calendar_events_recurrence
  ON calendar_events(recurrence_id) WHERE recurrence_id IS NOT NULL;

ALTER TABLE calendars ENABLE ROW LEVEL SECURITY;
ALTER TABLE calendar_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can manage own calendars" ON calendars;
CREATE POLICY "Users can manage own calendars" ON calendars
  FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can select own calendar events" ON calendar_events;
CREATE POLICY "Users can select own calendar events" ON calendar_events
  FOR SELECT USING (user_id = auth.uid());
DROP POLICY IF EXISTS "Users can insert own calendar events" ON calendar_events;
CREATE POLICY "Users can insert own calendar events" ON calendar_events
  FOR INSERT WITH CHECK (user_id = auth.uid());
DROP POLICY IF EXISTS "Users can update own calendar events" ON calendar_events;
CREATE POLICY "Users can update own calendar events" ON calendar_events
  FOR UPDATE USING (user_id = auth.uid());
DROP POLICY IF EXISTS "Users can delete own calendar events" ON calendar_events;
CREATE POLICY "Users can delete own calendar events" ON calendar_events
  FOR DELETE USING (user_id = auth.uid());

DROP TRIGGER IF EXISTS update_calendars_updated_at ON calendars;
CREATE TRIGGER update_calendars_updated_at
  BEFORE UPDATE ON calendars FOR EACH ROW EXECUTE FUNCTION update_updated_at();

DROP TRIGGER IF EXISTS update_calendar_events_updated_at ON calendar_events;
CREATE TRIGGER update_calendar_events_updated_at
  BEFORE UPDATE ON calendar_events FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ── Habits ──────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS habits (
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

DROP POLICY IF EXISTS "Users can manage own habits" ON habits;
CREATE POLICY "Users can manage own habits" ON habits
  FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

CREATE INDEX IF NOT EXISTS idx_habits_user_id ON habits(user_id);

DROP TRIGGER IF EXISTS update_habits_updated_at ON habits;
CREATE TRIGGER update_habits_updated_at
  BEFORE UPDATE ON habits FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ── Notes ───────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS notes (
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

DROP POLICY IF EXISTS "Users can manage own notes" ON notes;
CREATE POLICY "Users can manage own notes" ON notes
  FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

CREATE INDEX IF NOT EXISTS idx_notes_user_id ON notes(user_id);

DROP TRIGGER IF EXISTS update_notes_updated_at ON notes;
CREATE TRIGGER update_notes_updated_at
  BEFORE UPDATE ON notes FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ============================================================================
-- Note on todos/projects: this project stores them as an encrypted blob only
-- (id, user_id, encrypted_payload, updated_at) and the app writes exactly
-- those four columns. No status or is_completed column is needed, so this
-- script does not touch either table.
-- ============================================================================
