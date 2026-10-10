-- Reconstructed from the deployed production database on 2026-10-10.
-- Preserve supplied timestamps on INSERT; refresh updated_at only on UPDATE.
-- PostGIS is installed in different schemas in the two existing projects, so
-- select the matching function body without relocating the extension.

DO $migration$
DECLARE
  v_postgis_schema text;
BEGIN
  SELECT n.nspname INTO v_postgis_schema
  FROM pg_extension e
  JOIN pg_namespace n ON n.oid = e.extnamespace
  WHERE e.extname = 'postgis';

  IF v_postgis_schema = 'gis' THEN
    EXECUTE $ddl$CREATE OR REPLACE FUNCTION public.set_places_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
BEGIN
  IF TG_OP = 'UPDATE' THEN
    NEW.updated_at = now();
  END IF;

  NEW.location =
    gis.st_setsrid(
      gis.st_makepoint(NEW.longitude, NEW.latitude),
      4326
    )::gis.geography;

  RETURN NEW;
END;
$function$;$ddl$;
  ELSIF v_postgis_schema = 'public' THEN
    EXECUTE $ddl$CREATE OR REPLACE FUNCTION public.set_places_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
BEGIN
  IF TG_OP = 'UPDATE' THEN
    NEW.updated_at = now();
  END IF;

  NEW.location =
    public.st_setsrid(
      public.st_makepoint(NEW.longitude, NEW.latitude),
      4326
    )::public.geography;

  RETURN NEW;
END;
$function$;$ddl$;
  ELSE
    RAISE EXCEPTION 'Unsupported PostGIS schema: %', v_postgis_schema;
  END IF;
END;
$migration$;
