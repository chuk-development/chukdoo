-- ============================================================================
-- FIX: RLS Security Policies
-- Date: 2026-01-24
-- Issues Fixed:
--   1. profiles table was readable by anonymous users (USING true)
--   2. teams table had infinite recursion in policy
-- ============================================================================

-- ============================================================================
-- FIX 1: Profiles - Require authentication for viewing
-- ============================================================================

DROP POLICY IF EXISTS "Users can view all profiles" ON profiles;
DROP POLICY IF EXISTS "Authenticated users can view profiles" ON profiles;

CREATE POLICY "Authenticated users can view profiles" ON profiles
  FOR SELECT
  USING (auth.uid() IS NOT NULL);

-- ============================================================================
-- FIX 2: Teams - Fix infinite recursion using SECURITY DEFINER functions
-- ============================================================================

-- Drop all team-related policies first
DROP POLICY IF EXISTS "Team select" ON teams;
DROP POLICY IF EXISTS "Team insert" ON teams;
DROP POLICY IF EXISTS "Team update" ON teams;
DROP POLICY IF EXISTS "Team delete" ON teams;
DROP POLICY IF EXISTS "Team members select" ON team_members;
DROP POLICY IF EXISTS "Team members insert" ON team_members;
DROP POLICY IF EXISTS "Team members delete" ON team_members;

-- Helper function to check team membership (bypasses RLS)
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

-- Helper function to check team ownership (bypasses RLS)
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

-- Teams policies
CREATE POLICY "Team select" ON teams FOR SELECT USING (
  owner_id = auth.uid() OR is_team_member(id, auth.uid())
);

CREATE POLICY "Team insert" ON teams FOR INSERT
  WITH CHECK (owner_id = auth.uid());

CREATE POLICY "Team update" ON teams FOR UPDATE
  USING (owner_id = auth.uid());

CREATE POLICY "Team delete" ON teams FOR DELETE
  USING (owner_id = auth.uid());

-- Team members policies
CREATE POLICY "Team members select" ON team_members FOR SELECT USING (
  user_id = auth.uid() OR is_team_owner(team_id, auth.uid())
);

CREATE POLICY "Team members insert" ON team_members FOR INSERT
  WITH CHECK (is_team_owner(team_id, auth.uid()));

CREATE POLICY "Team members delete" ON team_members FOR DELETE
  USING (is_team_owner(team_id, auth.uid()));
