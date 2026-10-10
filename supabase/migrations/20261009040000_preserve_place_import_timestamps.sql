-- Reconstructed from the deployed production database on 2026-10-10.
-- Preserve supplied timestamps on INSERT; refresh updated_at only on UPDATE.

CREATE OR REPLACE FUNCTION public.set_places_updated_at()
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
$function$;
