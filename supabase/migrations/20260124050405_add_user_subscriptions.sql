-- ============================================================================
-- USER_SUBSCRIPTIONS TABLE
-- Stores subscription status synced from RevenueCat webhooks
-- SECURITY: Only Edge Functions (service_role) can write, clients can only read
-- ============================================================================

CREATE TABLE user_subscriptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  revenuecat_app_user_id TEXT,                 -- RevenueCat's app_user_id for verification
  tier TEXT NOT NULL DEFAULT 'free',           -- 'free' | 'pro'
  is_active BOOLEAN NOT NULL DEFAULT FALSE,
  expires_at TIMESTAMPTZ,                      -- NULL for lifetime or free
  product_identifier TEXT,                     -- RevenueCat product ID
  entitlement_id TEXT,                         -- RevenueCat entitlement identifier
  original_purchase_date TIMESTAMPTZ,          -- When subscription was first purchased
  last_webhook_at TIMESTAMPTZ,                 -- Last webhook received timestamp
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),

  CONSTRAINT valid_tier CHECK (tier IN ('free', 'pro'))
);

-- Only one subscription record per user
CREATE UNIQUE INDEX idx_user_subscriptions_user_id ON user_subscriptions(user_id);
-- Index for RevenueCat app_user_id lookups (webhooks use this)
CREATE INDEX idx_user_subscriptions_rc_user ON user_subscriptions(revenuecat_app_user_id);

-- Row Level Security
ALTER TABLE user_subscriptions ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- SECURITY POLICIES
-- Clients can ONLY read their own subscription
-- NO INSERT/UPDATE from client - only service_role (Edge Functions) can write
-- ============================================================================

-- Users can read their own subscription
CREATE POLICY "Users can view own subscription" ON user_subscriptions
  FOR SELECT USING (auth.uid() = user_id);

-- NOTE: No INSERT/UPDATE policies for anon/authenticated roles
-- Edge Functions use service_role which bypasses RLS

-- Timestamp trigger
CREATE OR REPLACE FUNCTION update_user_subscriptions_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_user_subscriptions_updated_at
  BEFORE UPDATE ON user_subscriptions
  FOR EACH ROW EXECUTE FUNCTION update_user_subscriptions_updated_at();

-- ============================================================================
-- WEBHOOK EVENT LOG (for audit trail and debugging)
-- ============================================================================

CREATE TABLE subscription_webhook_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  revenuecat_app_user_id TEXT NOT NULL,
  event_type TEXT NOT NULL,                    -- e.g., 'INITIAL_PURCHASE', 'RENEWAL', 'CANCELLATION'
  product_id TEXT,
  entitlement_id TEXT,
  expiration_at TIMESTAMPTZ,
  environment TEXT,                            -- 'SANDBOX' | 'PRODUCTION'
  raw_payload JSONB,                           -- Full webhook payload for debugging
  processed_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_webhook_events_user ON subscription_webhook_events(revenuecat_app_user_id);
CREATE INDEX idx_webhook_events_time ON subscription_webhook_events(processed_at DESC);

-- No RLS needed - only service_role writes, and we don't expose this to clients
