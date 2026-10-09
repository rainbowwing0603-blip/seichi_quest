-- Replace the roadside-station registry atomically after validating a complete official snapshot.
-- Service-role only. The caller must provide the full current authoritative set.
CREATE OR REPLACE FUNCTION public.replace_roadside_station_registry(p_rows jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_stage_count integer;
  v_upsert_count integer;
  v_deleted_count integer;
  v_final_count integer;
BEGIN
  IF jsonb_typeof(p_rows) IS DISTINCT FROM 'array'
     OR jsonb_array_length(p_rows) <> 1234 THEN
    RAISE EXCEPTION 'Registry payload must contain exactly 1234 rows.'
      USING ERRCODE = '22023';
  END IF;

  CREATE TEMP TABLE IF NOT EXISTS roadside_station_registry_import_stage (
    official_name text NOT NULL,
    prefecture text NOT NULL,
    municipality text,
    registration_round integer,
    official_source_url text,
    source_checked_at timestamp with time zone,
    status text NOT NULL CHECK (status IN ('registered', 'opening_pending')),
    metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
    PRIMARY KEY (prefecture, official_name)
  ) ON COMMIT DROP;

  TRUNCATE TABLE pg_temp.roadside_station_registry_import_stage;

  INSERT INTO pg_temp.roadside_station_registry_import_stage (
    official_name,
    prefecture,
    municipality,
    registration_round,
    official_source_url,
    source_checked_at,
    status,
    metadata
  )
  SELECT
    row_data.official_name,
    row_data.prefecture,
    row_data.municipality,
    row_data.registration_round,
    row_data.official_source_url,
    row_data.source_checked_at,
    row_data.status,
    COALESCE(row_data.metadata, '{}'::jsonb)
  FROM jsonb_to_recordset(p_rows) AS row_data(
    official_name text,
    prefecture text,
    municipality text,
    registration_round integer,
    official_source_url text,
    source_checked_at timestamp with time zone,
    status text,
    metadata jsonb
  );

  GET DIAGNOSTICS v_stage_count = ROW_COUNT;
  IF v_stage_count <> 1234 THEN
    RAISE EXCEPTION 'Registry staging row count mismatch: expected 1234, got %.', v_stage_count
      USING ERRCODE = '22023';
  END IF;

  INSERT INTO public.roadside_station_registry AS current_registry (
    official_name,
    prefecture,
    municipality,
    registration_round,
    official_source_url,
    source_checked_at,
    status,
    metadata
  )
  SELECT
    staged.official_name,
    staged.prefecture,
    staged.municipality,
    staged.registration_round,
    staged.official_source_url,
    staged.source_checked_at,
    staged.status,
    staged.metadata
  FROM pg_temp.roadside_station_registry_import_stage AS staged
  ON CONFLICT (prefecture, official_name) DO UPDATE
  SET
    municipality = EXCLUDED.municipality,
    registration_round = EXCLUDED.registration_round,
    official_source_url = EXCLUDED.official_source_url,
    source_checked_at = EXCLUDED.source_checked_at,
    status = CASE
      WHEN EXCLUDED.status = 'opening_pending' THEN 'opening_pending'
      WHEN current_registry.status IN ('open', 'closed', 'deregistered') THEN current_registry.status
      ELSE EXCLUDED.status
    END,
    metadata = EXCLUDED.metadata
      || (current_registry.metadata - ARRAY[
        'source',
        'registry_source',
        'registration_text',
        'registration_date_text'
      ]::text[]),
    updated_at = pg_catalog.clock_timestamp();

  GET DIAGNOSTICS v_upsert_count = ROW_COUNT;

  DELETE FROM public.roadside_station_registry AS existing
  WHERE NOT EXISTS (
    SELECT 1
    FROM pg_temp.roadside_station_registry_import_stage AS staged
    WHERE staged.prefecture = existing.prefecture
      AND staged.official_name = existing.official_name
  );
  GET DIAGNOSTICS v_deleted_count = ROW_COUNT;

  SELECT count(*)::integer INTO v_final_count
  FROM public.roadside_station_registry;

  IF v_final_count <> 1234 THEN
    RAISE EXCEPTION 'Registry replacement final count mismatch: expected 1234, got %.', v_final_count
      USING ERRCODE = '23514';
  END IF;

  RETURN pg_catalog.jsonb_build_object(
    'ok', true,
    'staged', v_stage_count,
    'upserted', v_upsert_count,
    'deleted', v_deleted_count,
    'total', v_final_count
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.replace_roadside_station_registry(jsonb) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.replace_roadside_station_registry(jsonb) TO service_role;

COMMENT ON FUNCTION public.replace_roadside_station_registry(jsonb) IS
  'Validates and atomically replaces the official roadside-station registry; callable only by service_role.';
