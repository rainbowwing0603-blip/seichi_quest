-- Read-only post-import verification. Run after schema and all numbered seed files.
WITH expected(table_name, expected_rows) AS (
  VALUES
    ('events', 51),
    ('places', 1713),
    ('contents', 2742),
    ('event_contents', 2721),
    ('content_blocks', 336),
    ('achievements', 18),
    ('event_achievements', 18),
    ('geo_regions', 57),
    ('geo_region_prefectures', 141),
    ('collection_series', 1),
    ('collection_series_places', 1231),
    ('collection_series_regions', 57),
    ('roadside_station_registry', 1234)
),
actual AS (
  SELECT 'events'::text table_name, count(*)::bigint actual_rows FROM public.events
  UNION ALL SELECT 'places', count(*) FROM public.places
  UNION ALL SELECT 'contents', count(*) FROM public.contents
  UNION ALL SELECT 'event_contents', count(*) FROM public.event_contents
  UNION ALL SELECT 'content_blocks', count(*) FROM public.content_blocks
  UNION ALL SELECT 'achievements', count(*) FROM public.achievements
  UNION ALL SELECT 'event_achievements', count(*) FROM public.event_achievements
  UNION ALL SELECT 'geo_regions', count(*) FROM public.geo_regions
  UNION ALL SELECT 'geo_region_prefectures', count(*) FROM public.geo_region_prefectures
  UNION ALL SELECT 'collection_series', count(*) FROM public.collection_series
  UNION ALL SELECT 'collection_series_places', count(*) FROM public.collection_series_places
  UNION ALL SELECT 'collection_series_regions', count(*) FROM public.collection_series_regions
  UNION ALL SELECT 'roadside_station_registry', count(*) FROM public.roadside_station_registry
)
SELECT e.table_name, e.expected_rows, a.actual_rows,
       (e.expected_rows = a.actual_rows) AS count_matches
FROM expected e JOIN actual a USING (table_name)
ORDER BY e.table_name;

-- These checks should each return zero.
SELECT 'places_without_geography' AS check_name, count(*)::bigint AS failures
FROM public.places WHERE location IS NULL
UNION ALL
SELECT 'event_contents_missing_event', count(*) FROM public.event_contents ec
WHERE NOT EXISTS (SELECT 1 FROM public.events e WHERE e.id = ec.event_id)
UNION ALL
SELECT 'event_contents_missing_content', count(*) FROM public.event_contents ec
WHERE NOT EXISTS (SELECT 1 FROM public.contents c WHERE c.id = ec.content_id)
UNION ALL
SELECT 'event_contents_missing_place', count(*) FROM public.event_contents ec
WHERE NOT EXISTS (SELECT 1 FROM public.places p WHERE p.id = ec.place_id)
UNION ALL
SELECT 'content_blocks_missing_content', count(*) FROM public.content_blocks b
WHERE NOT EXISTS (SELECT 1 FROM public.contents c WHERE c.id = b.content_id)
UNION ALL
SELECT 'event_achievements_missing_event', count(*) FROM public.event_achievements ea
WHERE NOT EXISTS (SELECT 1 FROM public.events e WHERE e.id = ea.event_id)
UNION ALL
SELECT 'event_achievements_missing_achievement', count(*) FROM public.event_achievements ea
WHERE NOT EXISTS (SELECT 1 FROM public.achievements a WHERE a.id = ea.achievement_id)
UNION ALL
SELECT 'geo_region_prefectures_missing_region', count(*) FROM public.geo_region_prefectures rp
WHERE NOT EXISTS (SELECT 1 FROM public.geo_regions r WHERE r.id = rp.region_id)
UNION ALL
SELECT 'collection_series_places_missing_series', count(*) FROM public.collection_series_places sp
WHERE NOT EXISTS (SELECT 1 FROM public.collection_series s WHERE s.id = sp.series_id)
UNION ALL
SELECT 'collection_series_places_missing_place', count(*) FROM public.collection_series_places sp
WHERE NOT EXISTS (SELECT 1 FROM public.places p WHERE p.id = sp.place_id)
UNION ALL
SELECT 'collection_series_regions_missing_series', count(*) FROM public.collection_series_regions sr
WHERE NOT EXISTS (SELECT 1 FROM public.collection_series s WHERE s.id = sr.series_id)
UNION ALL
SELECT 'collection_series_regions_missing_region', count(*) FROM public.collection_series_regions sr
WHERE NOT EXISTS (SELECT 1 FROM public.geo_regions r WHERE r.id = sr.region_id)
UNION ALL
SELECT 'roadside_registry_missing_place', count(*) FROM public.roadside_station_registry rr
WHERE rr.place_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.places p WHERE p.id = rr.place_id)
UNION ALL
SELECT 'closed_test_storage_urls_in_events', count(*) FROM public.events
WHERE coalesce(cover_image_url, '') LIKE '%wxlvhpmolrtcwryaazfb%';

-- RLS should be enabled for every app-owned table in exposed public schema.
SELECT c.relname AS table_name, c.relrowsecurity AS rls_enabled
FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
WHERE n.nspname='public' AND c.relkind IN ('r','p')
  AND c.relname <> 'spatial_ref_sys' AND NOT c.relispartition
  AND NOT c.relrowsecurity
ORDER BY c.relname;


-- Security and release inventory. These are observations, not destructive checks.
SELECT 'app_tables_without_rls' AS check_name, count(*)::bigint AS value
FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
WHERE n.nspname='public' AND c.relkind IN ('r','p')
  AND c.relname <> 'spatial_ref_sys' AND NOT c.relispartition AND NOT c.relrowsecurity
UNION ALL
SELECT 'app_security_definer_without_fixed_search_path', count(*)::bigint
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE n.nspname IN ('public','private') AND p.prosecdef AND p.prokind='f'
  AND NOT EXISTS (SELECT 1 FROM unnest(coalesce(p.proconfig, ARRAY[]::text[])) cfg WHERE cfg LIKE 'search_path=%')
UNION ALL
SELECT 'protected_table_direct_client_write_grants', count(*)::bigint
FROM information_schema.role_table_grants
WHERE table_schema='public'
  AND table_name IN ('profiles','user_event_preferences','user_event_participations')
  AND grantee IN ('anon','authenticated')
  AND privilege_type IN ('INSERT','UPDATE','DELETE')
UNION ALL
SELECT 'storage_buckets', count(*)::bigint FROM storage.buckets
UNION ALL
SELECT 'storage_objects', count(*)::bigint FROM storage.objects
UNION ALL
SELECT 'auth_users', count(*)::bigint FROM auth.users
UNION ALL
SELECT 'production_release_policy_rows', count(*)::bigint FROM public.app_release_policies;

-- Migration-history repair is intentionally a local Supabase CLI operation.
SELECT
  to_regclass('supabase_migrations.schema_migrations') IS NOT NULL AS migration_history_table_exists,
  (SELECT count(*) FROM public.app_release_policies WHERE platform='android' AND is_active) AS active_android_release_policies,
  (SELECT count(*) FROM public.app_release_policies WHERE platform='ios' AND is_active) AS active_ios_release_policies;
