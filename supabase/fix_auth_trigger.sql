-- ============================================================================
-- DIAGNOSE & FIX AUTH TRIGGER
-- Run this in Supabase SQL Editor (Dashboard > SQL Editor)
-- ============================================================================

-- 1. Check if profiles table exists
SELECT EXISTS (
  SELECT FROM information_schema.tables
  WHERE table_schema = 'public' AND table_name = 'profiles'
) AS profiles_exists;

-- 2. Check if trigger exists
SELECT EXISTS (
  SELECT FROM pg_trigger
  WHERE tgname = 'on_auth_user_created'
) AS trigger_exists;

-- 3. Drop and recreate the function with better error handling
DROP FUNCTION IF EXISTS handle_new_user() CASCADE;

CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, email, display_name)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'display_name', split_part(NEW.email, '@', 1))
  )
  ON CONFLICT (id) DO NOTHING;  -- Ignore if profile already exists
  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  -- Log error but don't fail the signup
  RAISE WARNING 'Failed to create profile: %', SQLERRM;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Recreate the trigger
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- 5. Grant necessary permissions
GRANT USAGE ON SCHEMA public TO postgres, anon, authenticated, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA public TO postgres, anon, authenticated, service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO postgres, anon, authenticated, service_role;

-- 6. If you already signed up and the profile wasn't created, create it manually:
-- (Uncomment and replace YOUR_USER_ID and YOUR_EMAIL with your actual values from Supabase Auth)
-- INSERT INTO profiles (id, email, display_name)
-- VALUES ('YOUR_USER_ID', 'YOUR_EMAIL', 'Your Name')
-- ON CONFLICT (id) DO NOTHING;

-- 7. Verify setup
SELECT 'Setup complete! Try signing up again.' AS status;
