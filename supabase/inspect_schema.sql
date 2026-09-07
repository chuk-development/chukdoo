-- ============================================================================
-- Read-only: what is actually in this project right now.
-- Run each block on its own (the SQL editor shows one result grid per run),
-- or run all four and page through the results.
-- ============================================================================

-- 1) Tables in the public schema
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public' AND table_type = 'BASE TABLE'
ORDER BY table_name;

-- 2) Every column of every public table
SELECT table_name,
       ordinal_position AS pos,
       column_name,
       data_type,
       is_nullable,
       column_default
FROM information_schema.columns
WHERE table_schema = 'public'
ORDER BY table_name, ordinal_position;

-- 3) Row level security: is it on, and which policies exist
SELECT c.relname AS table_name,
       c.relrowsecurity AS rls_enabled,
       p.policyname,
       p.cmd,
       p.qual AS using_expression,
       p.with_check AS with_check_expression
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
LEFT JOIN pg_policies p ON p.schemaname = n.nspname AND p.tablename = c.relname
WHERE n.nspname = 'public' AND c.relkind = 'r'
ORDER BY c.relname, p.policyname;

-- 4) Indexes and triggers
SELECT tablename, indexname, indexdef
FROM pg_indexes
WHERE schemaname = 'public'
ORDER BY tablename, indexname;

SELECT event_object_table AS table_name,
       trigger_name,
       action_timing,
       event_manipulation
FROM information_schema.triggers
WHERE trigger_schema = 'public'
ORDER BY event_object_table, trigger_name;

-- 5) Does the timestamp helper the migrations rely on exist?
SELECT proname
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE proname = 'update_updated_at';
