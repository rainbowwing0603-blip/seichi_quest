-- Keep app-facing RPC signatures in public as SECURITY INVOKER wrappers.
-- Move privileged implementations to the non-API private schema so the public
-- API does not expose SECURITY DEFINER implementations directly.
ALTER FUNCTION public.ensure_event_participation(uuid) SET SCHEMA private;
ALTER FUNCTION public.get_event_recommendations(integer) SET SCHEMA private;
ALTER FUNCTION public.get_event_social_stats(uuid) SET SCHEMA private;
ALTER FUNCTION public.get_my_collection_history() SET SCHEMA private;
ALTER FUNCTION public.get_my_event_rank(uuid) SET SCHEMA private;
ALTER FUNCTION public.get_my_location_security_state() SET SCHEMA private;
ALTER FUNCTION public.get_public_ranking(uuid, integer) SET SCHEMA private;
ALTER FUNCTION public.leave_event_participation(uuid) SET SCHEMA private;
ALTER FUNCTION public.record_place_visit_and_collect(uuid, uuid, timestamptz, double precision, double precision, double precision, text, jsonb) SET SCHEMA private;
ALTER FUNCTION public.report_location_integrity_violation(text) SET SCHEMA private;
ALTER FUNCTION public.reset_event_collection_history(uuid) SET SCHEMA private;
ALTER FUNCTION public.save_my_profile(text, text, text) SET SCHEMA private;
ALTER FUNCTION public.save_my_profile(text, text, text, text) SET SCHEMA private;
ALTER FUNCTION public.set_current_event_preference(uuid) SET SCHEMA private;

GRANT USAGE ON SCHEMA private TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION private.ensure_event_participation(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION private.get_event_recommendations(integer) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION private.get_event_social_stats(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION private.get_my_collection_history() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION private.get_my_event_rank(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION private.get_my_location_security_state() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION private.get_public_ranking(uuid, integer) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION private.leave_event_participation(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION private.record_place_visit_and_collect(uuid, uuid, timestamptz, double precision, double precision, double precision, text, jsonb) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION private.report_location_integrity_violation(text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION private.reset_event_collection_history(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION private.save_my_profile(text, text, text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION private.save_my_profile(text, text, text, text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION private.set_current_event_preference(uuid) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.ensure_event_participation(p_event_id uuid)
RETURNS void LANGUAGE sql SECURITY INVOKER SET search_path = ''
AS $$ SELECT private.ensure_event_participation($1); $$;

CREATE OR REPLACE FUNCTION public.get_event_recommendations(p_limit integer DEFAULT 5)
RETURNS TABLE(event_id uuid, participant_count bigint, demographic_population bigint, participation_rate numeric, recommendation_basis text)
LANGUAGE sql STABLE SECURITY INVOKER SET search_path = ''
AS $$ SELECT * FROM private.get_event_recommendations($1); $$;

CREATE OR REPLACE FUNCTION public.get_event_social_stats(p_event_id uuid)
RETURNS TABLE(participant_count bigint, favorite_count bigint, is_favorited boolean)
LANGUAGE sql STABLE SECURITY INVOKER SET search_path = ''
AS $$ SELECT * FROM private.get_event_social_stats($1); $$;

CREATE OR REPLACE FUNCTION public.get_my_collection_history()
RETURNS TABLE(event_id uuid, event_name text, content_id uuid, card text, event_content_id uuid, place_id uuid, content_key text, collected_at timestamptz)
LANGUAGE sql SECURITY INVOKER SET search_path = ''
AS $$ SELECT * FROM private.get_my_collection_history(); $$;

CREATE OR REPLACE FUNCTION public.get_my_event_rank(p_event_id uuid)
RETURNS TABLE(rank bigint, collected_count bigint)
LANGUAGE sql SECURITY INVOKER SET search_path = ''
AS $$ SELECT * FROM private.get_my_event_rank($1); $$;

CREATE OR REPLACE FUNCTION public.get_my_location_security_state()
RETURNS TABLE(violation_count integer, cooldown_until timestamptz, cooldown_seconds integer)
LANGUAGE sql SECURITY INVOKER SET search_path = ''
AS $$ SELECT * FROM private.get_my_location_security_state(); $$;

CREATE OR REPLACE FUNCTION public.get_public_ranking(p_event_id uuid, p_limit integer DEFAULT 50)
RETURNS TABLE(rank bigint, display_name text, avatar_key text, collected_count bigint, participant_count bigint, is_me boolean)
LANGUAGE sql STABLE SECURITY INVOKER SET search_path = ''
AS $$ SELECT * FROM private.get_public_ranking($1, $2); $$;

CREATE OR REPLACE FUNCTION public.leave_event_participation(p_event_id uuid)
RETURNS void LANGUAGE sql SECURITY INVOKER SET search_path = ''
AS $$ SELECT private.leave_event_participation($1); $$;

CREATE OR REPLACE FUNCTION public.record_place_visit_and_collect(
  p_place_id uuid, p_client_visit_id uuid, p_visited_at timestamptz,
  p_latitude double precision, p_longitude double precision, p_accuracy_meters double precision,
  p_source text DEFAULT 'gps', p_metadata jsonb DEFAULT '{}'::jsonb
)
RETURNS TABLE(collection_history_id uuid, event_id uuid, event_name text, content_id uuid, event_content_id uuid, place_id uuid, card text, content_title text, collected_at timestamptz)
LANGUAGE sql SECURITY INVOKER SET search_path = ''
AS $$ SELECT * FROM private.record_place_visit_and_collect($1, $2, $3, $4, $5, $6, $7, $8); $$;

CREATE OR REPLACE FUNCTION public.report_location_integrity_violation(p_violation_type text)
RETURNS TABLE(violation_count integer, cooldown_until timestamptz, cooldown_seconds integer)
LANGUAGE sql SECURITY INVOKER SET search_path = ''
AS $$ SELECT * FROM private.report_location_integrity_violation($1); $$;

CREATE OR REPLACE FUNCTION public.reset_event_collection_history(p_event_id uuid)
RETURNS void LANGUAGE sql SECURITY INVOKER SET search_path = ''
AS $$ SELECT private.reset_event_collection_history($1); $$;

CREATE OR REPLACE FUNCTION public.save_my_profile(p_display_name text, p_age_group text, p_avatar_key text)
RETURNS void LANGUAGE sql SECURITY INVOKER SET search_path = ''
AS $$ SELECT private.save_my_profile($1, $2, $3); $$;

CREATE OR REPLACE FUNCTION public.save_my_profile(p_display_name text, p_age_group text, p_avatar_key text, p_gender text)
RETURNS void LANGUAGE sql SECURITY INVOKER SET search_path = ''
AS $$ SELECT private.save_my_profile($1, $2, $3, $4); $$;

CREATE OR REPLACE FUNCTION public.set_current_event_preference(p_event_id uuid)
RETURNS void LANGUAGE sql SECURITY INVOKER SET search_path = ''
AS $$ SELECT private.set_current_event_preference($1); $$;

REVOKE ALL ON FUNCTION public.ensure_event_participation(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.get_event_recommendations(integer) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.get_event_social_stats(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.get_my_collection_history() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.get_my_event_rank(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.get_my_location_security_state() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.get_public_ranking(uuid, integer) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.leave_event_participation(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.record_place_visit_and_collect(uuid, uuid, timestamptz, double precision, double precision, double precision, text, jsonb) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.report_location_integrity_violation(text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.reset_event_collection_history(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.save_my_profile(text, text, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.save_my_profile(text, text, text, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.set_current_event_preference(uuid) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.ensure_event_participation(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_event_recommendations(integer) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_event_social_stats(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_my_collection_history() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_my_event_rank(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_my_location_security_state() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_public_ranking(uuid, integer) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.leave_event_participation(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.record_place_visit_and_collect(uuid, uuid, timestamptz, double precision, double precision, double precision, text, jsonb) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.report_location_integrity_violation(text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.reset_event_collection_history(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.save_my_profile(text, text, text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.save_my_profile(text, text, text, text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.set_current_event_preference(uuid) TO authenticated, service_role;
