-- ============================================================================
-- CHUKDOO DATABASE SCHEMA
-- End-to-End Encrypted Todo Application
-- ============================================================================

-- ============================================================================
-- CORE TABLES
-- ============================================================================

-- User profiles (extends Supabase auth.users)
CREATE TABLE profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  display_name TEXT,
  email TEXT,
  avatar_url TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- PROJECTS
-- ============================================================================

CREATE TABLE projects (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  encrypted_name TEXT NOT NULL,        -- E2EE encrypted project name
  encrypted_description TEXT,          -- E2EE encrypted description
  color TEXT DEFAULT '#808080',        -- Hex color (not encrypted - UI only)
  icon TEXT DEFAULT 'folder',          -- Icon name (not encrypted - UI only)
  is_inbox BOOLEAN DEFAULT FALSE,      -- Is this the user's Inbox project?
  is_archived BOOLEAN DEFAULT FALSE,
  sort_order INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Project sharing and collaboration
CREATE TABLE project_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role TEXT NOT NULL DEFAULT 'member' CHECK (role IN ('owner', 'admin', 'member', 'viewer')),
  -- E2EE: Encrypted project key for this member (encrypted with member's public key)
  encrypted_project_key TEXT,
  invited_by UUID REFERENCES auth.users(id),
  accepted_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(project_id, user_id)
);

-- ============================================================================
-- TEAMS (for individual todo sharing)
-- ============================================================================

CREATE TABLE teams (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  encrypted_name TEXT NOT NULL,        -- E2EE encrypted team name
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE team_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  team_id UUID NOT NULL REFERENCES teams(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role TEXT NOT NULL DEFAULT 'member' CHECK (role IN ('owner', 'admin', 'member')),
  -- E2EE: Encrypted team key for this member
  encrypted_team_key TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(team_id, user_id)
);

-- ============================================================================
-- TODOS
-- ============================================================================

CREATE TABLE todos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  project_id UUID REFERENCES projects(id) ON DELETE SET NULL,

  -- E2EE encrypted payload containing: title, description, notes
  encrypted_payload TEXT NOT NULL,

  -- Non-encrypted metadata for queries (dates stored as ISO strings for indexing)
  priority INTEGER DEFAULT 4 CHECK (priority BETWEEN 1 AND 4),  -- 1=highest, 4=none
  due_date DATE,
  due_time TIME,

  -- Completion status
  is_completed BOOLEAN DEFAULT FALSE,
  completed_at TIMESTAMPTZ,

  -- Recurrence (stored as RRULE string, not encrypted for scheduling)
  recurrence_rule TEXT,

  -- Ordering
  sort_order INTEGER DEFAULT 0,

  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),

  -- For sharing: which encryption key was used
  -- NULL = user's personal key
  -- 'project:{project_id}' = project key
  -- 'team:{team_id}' = team key
  encryption_context TEXT
);

-- Todo assignments (for individual todo sharing)
CREATE TABLE todo_assignments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  todo_id UUID NOT NULL REFERENCES todos(id) ON DELETE CASCADE,
  assigned_to UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  assigned_by UUID NOT NULL REFERENCES auth.users(id),
  -- E2EE: Todo key encrypted with assignee's public key
  encrypted_todo_key TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(todo_id, assigned_to)
);

-- Todo labels/tags
CREATE TABLE labels (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  encrypted_name TEXT NOT NULL,        -- E2EE encrypted
  color TEXT DEFAULT '#808080',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE todo_labels (
  todo_id UUID NOT NULL REFERENCES todos(id) ON DELETE CASCADE,
  label_id UUID NOT NULL REFERENCES labels(id) ON DELETE CASCADE,
  PRIMARY KEY (todo_id, label_id)
);

-- Reminders
CREATE TABLE reminders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  todo_id UUID NOT NULL REFERENCES todos(id) ON DELETE CASCADE,
  remind_at TIMESTAMPTZ NOT NULL,
  is_sent BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- E2EE KEY EXCHANGE
-- ============================================================================

-- User public keys for key exchange (X25519)
CREATE TABLE user_public_keys (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  public_key TEXT NOT NULL,            -- Base64-encoded X25519 public key
  key_id TEXT NOT NULL,                -- Unique identifier for key rotation
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Share invitations (pending key exchange)
CREATE TABLE share_invitations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  type TEXT NOT NULL CHECK (type IN ('project', 'team', 'todo')),
  resource_id UUID NOT NULL,           -- project_id, team_id, or todo_id
  invited_by UUID NOT NULL REFERENCES auth.users(id),
  invitee_email TEXT NOT NULL,         -- Email of person being invited
  invitee_user_id UUID REFERENCES auth.users(id),  -- Resolved when they sign up
  role TEXT DEFAULT 'member',
  -- Encrypted resource key (will be set when invitee's public key is available)
  encrypted_resource_key TEXT,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'declined', 'expired')),
  expires_at TIMESTAMPTZ DEFAULT (NOW() + INTERVAL '7 days'),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- INDEXES
-- ============================================================================

CREATE INDEX idx_todos_user_id ON todos(user_id);
CREATE INDEX idx_todos_project_id ON todos(project_id);
CREATE INDEX idx_todos_due_date ON todos(due_date) WHERE NOT is_completed;
CREATE INDEX idx_todos_completed ON todos(is_completed, user_id);
CREATE INDEX idx_todos_updated ON todos(updated_at);

CREATE INDEX idx_projects_owner ON projects(owner_id);
CREATE INDEX idx_project_members_user ON project_members(user_id);
CREATE INDEX idx_team_members_user ON team_members(user_id);

CREATE INDEX idx_reminders_time ON reminders(remind_at) WHERE NOT is_sent;

-- ============================================================================
-- ROW LEVEL SECURITY
-- ============================================================================

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE projects ENABLE ROW LEVEL SECURITY;
ALTER TABLE project_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE teams ENABLE ROW LEVEL SECURITY;
ALTER TABLE team_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE todos ENABLE ROW LEVEL SECURITY;
ALTER TABLE todo_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE labels ENABLE ROW LEVEL SECURITY;
ALTER TABLE todo_labels ENABLE ROW LEVEL SECURITY;
ALTER TABLE reminders ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_public_keys ENABLE ROW LEVEL SECURITY;
ALTER TABLE share_invitations ENABLE ROW LEVEL SECURITY;

-- Profiles: authenticated users can view (for sharing), edit own
CREATE POLICY "Authenticated users can view profiles" ON profiles FOR SELECT
  USING (auth.uid() IS NOT NULL);
CREATE POLICY "Users can update own profile" ON profiles FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "Users can insert own profile" ON profiles FOR INSERT WITH CHECK (auth.uid() = id);

-- Projects: owner or member can access
CREATE POLICY "Project select" ON projects FOR SELECT USING (
  owner_id = auth.uid() OR
  id IN (SELECT project_id FROM project_members WHERE user_id = auth.uid())
);
CREATE POLICY "Project insert" ON projects FOR INSERT WITH CHECK (owner_id = auth.uid());
CREATE POLICY "Project update" ON projects FOR UPDATE USING (
  owner_id = auth.uid() OR
  id IN (SELECT project_id FROM project_members WHERE user_id = auth.uid() AND role IN ('owner', 'admin'))
);
CREATE POLICY "Project delete" ON projects FOR DELETE USING (owner_id = auth.uid());

-- Project members
CREATE POLICY "Project members select" ON project_members FOR SELECT USING (
  user_id = auth.uid() OR
  project_id IN (SELECT id FROM projects WHERE owner_id = auth.uid())
);
CREATE POLICY "Project members insert" ON project_members FOR INSERT WITH CHECK (
  project_id IN (SELECT id FROM projects WHERE owner_id = auth.uid()) OR
  project_id IN (SELECT project_id FROM project_members WHERE user_id = auth.uid() AND role IN ('owner', 'admin'))
);
CREATE POLICY "Project members update" ON project_members FOR UPDATE USING (
  user_id = auth.uid() OR
  project_id IN (SELECT id FROM projects WHERE owner_id = auth.uid())
);
CREATE POLICY "Project members delete" ON project_members FOR DELETE USING (
  project_id IN (SELECT id FROM projects WHERE owner_id = auth.uid())
);

-- Teams (uses SECURITY DEFINER helpers to avoid infinite recursion)
CREATE POLICY "Team select" ON teams FOR SELECT USING (
  owner_id = auth.uid() OR is_team_member(id, auth.uid())
);
CREATE POLICY "Team insert" ON teams FOR INSERT WITH CHECK (owner_id = auth.uid());
CREATE POLICY "Team update" ON teams FOR UPDATE USING (owner_id = auth.uid());
CREATE POLICY "Team delete" ON teams FOR DELETE USING (owner_id = auth.uid());

-- Team members (uses SECURITY DEFINER helpers to avoid infinite recursion)
CREATE POLICY "Team members select" ON team_members FOR SELECT USING (
  user_id = auth.uid() OR is_team_owner(team_id, auth.uid())
);
CREATE POLICY "Team members insert" ON team_members FOR INSERT WITH CHECK (
  is_team_owner(team_id, auth.uid())
);
CREATE POLICY "Team members delete" ON team_members FOR DELETE USING (
  is_team_owner(team_id, auth.uid())
);

-- Todos: complex policy for personal + shared access
CREATE POLICY "Todo select" ON todos FOR SELECT USING (
  user_id = auth.uid() OR
  project_id IN (SELECT project_id FROM project_members WHERE user_id = auth.uid()) OR
  id IN (SELECT todo_id FROM todo_assignments WHERE assigned_to = auth.uid())
);
CREATE POLICY "Todo insert" ON todos FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY "Todo update" ON todos FOR UPDATE USING (
  user_id = auth.uid() OR
  project_id IN (SELECT project_id FROM project_members WHERE user_id = auth.uid() AND role IN ('owner', 'admin', 'member'))
);
CREATE POLICY "Todo delete" ON todos FOR DELETE USING (user_id = auth.uid());

-- Todo assignments
CREATE POLICY "Assignment select" ON todo_assignments FOR SELECT USING (
  assigned_to = auth.uid() OR assigned_by = auth.uid()
);
CREATE POLICY "Assignment insert" ON todo_assignments FOR INSERT WITH CHECK (
  assigned_by = auth.uid()
);
CREATE POLICY "Assignment delete" ON todo_assignments FOR DELETE USING (
  assigned_by = auth.uid()
);

-- Labels: user owns their labels
CREATE POLICY "Labels" ON labels FOR ALL USING (user_id = auth.uid());

-- Todo labels: based on todo ownership
CREATE POLICY "Todo labels" ON todo_labels FOR ALL USING (
  todo_id IN (SELECT id FROM todos WHERE user_id = auth.uid())
);

-- Reminders: based on todo ownership
CREATE POLICY "Reminders" ON reminders FOR ALL USING (
  todo_id IN (SELECT id FROM todos WHERE user_id = auth.uid())
);

-- Public keys: anyone can read (for key exchange), only owner can write
CREATE POLICY "Public key read" ON user_public_keys FOR SELECT USING (true);
CREATE POLICY "Public key write" ON user_public_keys FOR ALL USING (auth.uid() = user_id);

-- Share invitations: inviter or invitee can access
CREATE POLICY "Invitation select" ON share_invitations FOR SELECT USING (
  invited_by = auth.uid() OR invitee_user_id = auth.uid()
);
CREATE POLICY "Invitation insert" ON share_invitations FOR INSERT WITH CHECK (invited_by = auth.uid());
CREATE POLICY "Invitation update" ON share_invitations FOR UPDATE USING (
  invited_by = auth.uid() OR invitee_user_id = auth.uid()
);

-- ============================================================================
-- FUNCTIONS
-- ============================================================================

-- Helper function to check team membership (SECURITY DEFINER bypasses RLS)
CREATE OR REPLACE FUNCTION is_team_member(p_team_id UUID, p_user_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM team_members
    WHERE team_id = p_team_id
    AND user_id = p_user_id
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

-- Helper function to check team ownership (SECURITY DEFINER bypasses RLS)
CREATE OR REPLACE FUNCTION is_team_owner(p_team_id UUID, p_user_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM teams
    WHERE id = p_team_id
    AND owner_id = p_user_id
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

-- Function to auto-create profile on signup
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO profiles (id, email, display_name)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'display_name', split_part(NEW.email, '@', 1))
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger for new user
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- Function to update timestamps
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Timestamp triggers
CREATE TRIGGER update_todos_updated_at
  BEFORE UPDATE ON todos
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_projects_updated_at
  BEFORE UPDATE ON projects
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_profiles_updated_at
  BEFORE UPDATE ON profiles
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_teams_updated_at
  BEFORE UPDATE ON teams
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();
