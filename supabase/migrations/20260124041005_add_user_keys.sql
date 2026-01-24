-- ============================================================================
-- USER_KEYS TABLE FOR BACKUP CODES
-- Stores wrapped Master Keys for password and backup code recovery
-- ============================================================================

CREATE TABLE user_keys (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  key_type TEXT NOT NULL,              -- 'password' | 'backup_0' | 'backup_1' | ... 'backup_7'
  wrapped_key TEXT NOT NULL,           -- Master-Key encrypted with this key (AES-GCM)
  code_hash TEXT,                      -- SHA-256 hash of backup code (only for backup_* types)
  used_at TIMESTAMPTZ,                 -- NULL = not used yet (backup codes only)
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),

  CONSTRAINT valid_key_type CHECK (
    key_type = 'password' OR
    key_type ~ '^backup_[0-7]$'
  )
);

-- Indexes
CREATE INDEX idx_user_keys_user_id ON user_keys(user_id);
CREATE INDEX idx_user_keys_code_hash ON user_keys(code_hash) WHERE code_hash IS NOT NULL;
CREATE UNIQUE INDEX idx_user_keys_user_type ON user_keys(user_id, key_type);

-- Row Level Security
ALTER TABLE user_keys ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own keys" ON user_keys
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own keys" ON user_keys
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own keys" ON user_keys
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own keys" ON user_keys
  FOR DELETE USING (auth.uid() = user_id);

-- Timestamp trigger (reuse existing function if available)
CREATE OR REPLACE FUNCTION update_user_keys_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_user_keys_updated_at
  BEFORE UPDATE ON user_keys
  FOR EACH ROW EXECUTE FUNCTION update_user_keys_updated_at();

-- ============================================================================
-- RATE LIMITING TABLE FOR RECOVERY ATTEMPTS
-- ============================================================================

CREATE TABLE recovery_attempts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  ip_address INET,
  attempted_at TIMESTAMPTZ DEFAULT NOW(),
  success BOOLEAN DEFAULT FALSE
);

CREATE INDEX idx_recovery_attempts_user ON recovery_attempts(user_id, attempted_at DESC);

ALTER TABLE recovery_attempts ENABLE ROW LEVEL SECURITY;

-- Users can view own attempts
CREATE POLICY "Users can view own attempts" ON recovery_attempts
  FOR SELECT USING (auth.uid() = user_id);

-- Users can insert own attempts (for client-side logging)
CREATE POLICY "Users can insert own attempts" ON recovery_attempts
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

-- Function to count available (unused) backup codes for a user
CREATE OR REPLACE FUNCTION get_available_backup_codes_count(p_user_id UUID)
RETURNS INTEGER AS $$
BEGIN
  RETURN (
    SELECT COUNT(*)::INTEGER
    FROM user_keys
    WHERE user_id = p_user_id
    AND key_type LIKE 'backup_%'
    AND used_at IS NULL
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

-- Function to check rate limiting (max 5 attempts in 15 min)
CREATE OR REPLACE FUNCTION check_recovery_rate_limit(p_user_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
  recent_failures INTEGER;
BEGIN
  SELECT COUNT(*) INTO recent_failures
  FROM recovery_attempts
  WHERE user_id = p_user_id
  AND success = FALSE
  AND attempted_at > NOW() - INTERVAL '15 minutes';

  RETURN recent_failures < 5;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;
