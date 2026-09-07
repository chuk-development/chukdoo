-- Calendar containers (like projects for todos)
CREATE TABLE calendars (
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

-- Calendar events
CREATE TABLE calendar_events (
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

-- Indexes
CREATE INDEX idx_calendars_user ON calendars(user_id);
CREATE INDEX idx_calendar_events_user ON calendar_events(user_id);
CREATE INDEX idx_calendar_events_calendar ON calendar_events(calendar_id);
CREATE INDEX idx_calendar_events_time_range ON calendar_events(start_time, end_time) WHERE recurrence_id IS NULL;
CREATE INDEX idx_calendar_events_recurrence ON calendar_events(recurrence_id) WHERE recurrence_id IS NOT NULL;

-- RLS
ALTER TABLE calendars ENABLE ROW LEVEL SECURITY;
ALTER TABLE calendar_events ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage own calendars" ON calendars
  FOR ALL USING (user_id = auth.uid());

CREATE POLICY "Users can select own calendar events" ON calendar_events
  FOR SELECT USING (user_id = auth.uid());
CREATE POLICY "Users can insert own calendar events" ON calendar_events
  FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY "Users can update own calendar events" ON calendar_events
  FOR UPDATE USING (user_id = auth.uid());
CREATE POLICY "Users can delete own calendar events" ON calendar_events
  FOR DELETE USING (user_id = auth.uid());

-- Timestamp triggers (reuse existing function)
CREATE TRIGGER update_calendars_updated_at
  BEFORE UPDATE ON calendars FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_calendar_events_updated_at
  BEFORE UPDATE ON calendar_events FOR EACH ROW EXECUTE FUNCTION update_updated_at();
