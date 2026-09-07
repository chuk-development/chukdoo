-- ============================================================================
-- Complete schema of the public schema as ONE text result.
-- Read-only. Run this single statement and copy the whole "schema" cell.
-- ============================================================================
WITH cols AS (
  SELECT c.table_name,
         string_agg(
           '  ' || c.column_name || ' ' || c.data_type
             || CASE WHEN c.character_maximum_length IS NOT NULL
                     THEN '(' || c.character_maximum_length || ')' ELSE '' END
             || CASE WHEN c.is_nullable = 'NO' THEN ' NOT NULL' ELSE '' END
             || COALESCE(' DEFAULT ' || c.column_default, ''),
           E'\n' ORDER BY c.ordinal_position
         ) AS body
  FROM information_schema.columns c
  WHERE c.table_schema = 'public'
  GROUP BY c.table_name
),
cons AS (
  SELECT rel.relname AS table_name,
         string_agg('  ' || con.conname || ': ' || pg_get_constraintdef(con.oid),
                    E'\n' ORDER BY con.conname) AS body
  FROM pg_constraint con
  JOIN pg_class rel ON rel.oid = con.conrelid
  JOIN pg_namespace ns ON ns.oid = rel.relnamespace
  WHERE ns.nspname = 'public'
  GROUP BY rel.relname
),
idx AS (
  SELECT tablename AS table_name,
         string_agg('  ' || indexdef, E'\n' ORDER BY indexname) AS body
  FROM pg_indexes WHERE schemaname = 'public'
  GROUP BY tablename
),
pol AS (
  SELECT tablename AS table_name,
         string_agg('  ' || policyname || ' [' || cmd || ']'
                    || ' USING ' || COALESCE(qual, '-')
                    || ' WITH CHECK ' || COALESCE(with_check, '-'),
                    E'\n' ORDER BY policyname) AS body
  FROM pg_policies WHERE schemaname = 'public'
  GROUP BY tablename
),
trg AS (
  SELECT c.relname AS table_name,
         string_agg('  ' || t.tgname || ': ' || pg_get_triggerdef(t.oid),
                    E'\n' ORDER BY t.tgname) AS body
  FROM pg_trigger t
  JOIN pg_class c ON c.oid = t.tgrelid
  JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'public' AND NOT t.tgisinternal
  GROUP BY c.relname
),
tabs AS (
  SELECT c.relname AS table_name, c.relrowsecurity AS rls
  FROM pg_class c
  JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'public' AND c.relkind = 'r'
)
SELECT string_agg(
         '=== TABLE ' || t.table_name || '  (RLS ' ||
         CASE WHEN t.rls THEN 'ON' ELSE 'OFF' END || ') ===' || E'\n'
         || 'COLUMNS:' || E'\n' || COALESCE(cols.body, '  -') || E'\n'
         || 'CONSTRAINTS:' || E'\n' || COALESCE(cons.body, '  -') || E'\n'
         || 'INDEXES:' || E'\n' || COALESCE(idx.body, '  -') || E'\n'
         || 'POLICIES:' || E'\n' || COALESCE(pol.body, '  -') || E'\n'
         || 'TRIGGERS:' || E'\n' || COALESCE(trg.body, '  -'),
         E'\n\n' ORDER BY t.table_name
       ) AS schema
FROM tabs t
LEFT JOIN cols ON cols.table_name = t.table_name
LEFT JOIN cons ON cons.table_name = t.table_name
LEFT JOIN idx  ON idx.table_name  = t.table_name
LEFT JOIN pol  ON pol.table_name  = t.table_name
LEFT JOIN trg  ON trg.table_name  = t.table_name;
