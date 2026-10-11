-- The production baseline revokes EXECUTE from all app-owned functions
-- before re-granting only the reviewed client RPC surface. The historical
-- story_preview_server_time migration was marked as applied during cutover,
-- so this explicit grant is required to preserve its intended authenticated
-- access in the live production schema.
REVOKE ALL ON FUNCTION public.story_preview_server_time()
FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.story_preview_server_time()
TO authenticated;
