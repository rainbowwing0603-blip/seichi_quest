-- Explicitly deny direct API-role access to operational tables used only by
-- privileged server-side RPCs. Existing RPCs retain owner/service_role access.
DO $migration$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='event_collection_resets' AND policyname='deny_api_roles_event_collection_resets') THEN
    CREATE POLICY deny_api_roles_event_collection_resets ON public.event_collection_resets
      FOR ALL TO anon, authenticated USING (false) WITH CHECK (false);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='location_security_events' AND policyname='deny_api_roles_location_security_events') THEN
    CREATE POLICY deny_api_roles_location_security_events ON public.location_security_events
      FOR ALL TO anon, authenticated USING (false) WITH CHECK (false);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='location_security_states' AND policyname='deny_api_roles_location_security_states') THEN
    CREATE POLICY deny_api_roles_location_security_states ON public.location_security_states
      FOR ALL TO anon, authenticated USING (false) WITH CHECK (false);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='roadside_station_registry' AND policyname='deny_api_roles_roadside_station_registry') THEN
    CREATE POLICY deny_api_roles_roadside_station_registry ON public.roadside_station_registry
      FOR ALL TO anon, authenticated USING (false) WITH CHECK (false);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='private' AND tablename='admin_users' AND policyname='deny_api_roles_admin_users') THEN
    CREATE POLICY deny_api_roles_admin_users ON private.admin_users
      FOR ALL TO anon, authenticated USING (false) WITH CHECK (false);
  END IF;
END
$migration$;
