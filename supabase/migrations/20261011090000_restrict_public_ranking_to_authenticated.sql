-- Restrict the public ranking RPC to signed-in app sessions.
-- Supabase anonymous-auth users use the authenticated database role, so this
-- preserves the app's anonymous sign-in flow while preventing direct anon RPC calls.
REVOKE ALL ON FUNCTION public.get_public_ranking(uuid, integer) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.get_public_ranking(uuid, integer) FROM anon;
GRANT EXECUTE ON FUNCTION public.get_public_ranking(uuid, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_public_ranking(uuid, integer) TO service_role;
