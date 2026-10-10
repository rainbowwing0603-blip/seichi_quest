-- Re-apply the reviewed client RPC grant after the production security
-- reconciliation migration, which intentionally revokes app-owned function
-- privileges before granting the approved surface.
-- Idempotent: keeps access limited to authenticated clients.
REVOKE ALL ON FUNCTION public.story_preview_server_time()
FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.story_preview_server_time()
TO authenticated;
