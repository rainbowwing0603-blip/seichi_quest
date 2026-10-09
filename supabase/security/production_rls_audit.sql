-- Read-only security audit for the rebuilt production schema.
-- Run after applying the reviewed baseline, using a privileged SQL session.
-- This file reports findings; it intentionally does not change grants or policies.

-- 1) Every ordinary table in API-exposed schemas must have RLS enabled.
SELECT n.nspname AS schema_name, c.relname AS table_name, c.relrowsecurity AS rls_enabled,
       c.relforcerowsecurity AS force_rls
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE c.relkind IN ('r','p')
  AND n.nspname IN ('public','graphql_public')
  AND c.relname <> 'spatial_ref_sys'
  AND NOT c.relispartition
ORDER BY 1,2;

-- 2) Direct table privileges granted to client roles. Every row needs a documented reason.
SELECT table_schema, table_name, grantee, privilege_type
FROM information_schema.role_table_grants
WHERE table_schema IN ('public','private')
  AND grantee IN ('anon','authenticated','PUBLIC')
ORDER BY table_schema, table_name, grantee, privilege_type;

-- 3) Policies must be explicit about target roles, and UPDATE must constrain both old and new row.
SELECT schemaname, tablename, policyname, roles, cmd, qual, with_check,
       CASE WHEN cmd = 'UPDATE' AND (qual IS NULL OR with_check IS NULL)
            THEN 'FAIL: UPDATE needs USING and WITH CHECK'
            WHEN roles IS NULL OR cardinality(roles) = 0
            THEN 'REVIEW: no explicit target role'
            ELSE 'REVIEW'
       END AS review_status
FROM pg_policies
WHERE schemaname IN ('public','private')
ORDER BY schemaname, tablename, policyname;

-- 4) SECURITY DEFINER functions require manual review of body, search_path and EXECUTE grants.
SELECT n.nspname AS schema_name, p.proname AS function_name,
       pg_get_function_identity_arguments(p.oid) AS arguments,
       p.prosecdef AS security_definer,
       coalesce(array_to_string(p.proconfig, ', '), '') AS function_settings,
       has_function_privilege('anon', p.oid, 'EXECUTE') AS anon_can_execute,
       has_function_privilege('authenticated', p.oid, 'EXECUTE') AS authenticated_can_execute,
       has_function_privilege('service_role', p.oid, 'EXECUTE') AS service_role_can_execute
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname IN ('public','private','api')
  AND p.prokind = 'f'
  AND p.prosecdef
ORDER BY 1,2;

-- 5) Views in exposed schemas should be security_invoker unless an exception is reviewed.
SELECT schemaname, viewname, viewowner, definition
FROM pg_views
WHERE schemaname IN ('public','graphql_public')
ORDER BY schemaname, viewname;

-- 6) Flag client-accessible tables with no RLS as a concise fail list.
SELECT n.nspname AS schema_name, c.relname AS table_name
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE c.relkind IN ('r','p')
  AND n.nspname IN ('public','graphql_public')
  AND c.relname <> 'spatial_ref_sys'
  AND NOT c.relispartition
  AND NOT c.relrowsecurity
ORDER BY 1,2;


-- 7) Rewarded story preview depends on server time being callable by authenticated users only.
SELECT p.proname AS function_name,
       has_function_privilege('anon', p.oid, 'EXECUTE') AS anon_can_execute,
       has_function_privilege('authenticated', p.oid, 'EXECUTE') AS authenticated_can_execute,
       CASE
         WHEN NOT has_function_privilege('anon', p.oid, 'EXECUTE')
          AND has_function_privilege('authenticated', p.oid, 'EXECUTE')
         THEN 'PASS'
         ELSE 'FAIL: expected authenticated-only EXECUTE'
       END AS grant_status
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname = 'story_preview_server_time'
  AND pg_get_function_identity_arguments(p.oid) = '';
