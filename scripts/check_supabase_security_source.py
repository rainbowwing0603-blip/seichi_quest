#!/usr/bin/env python3
"""Lightweight static guardrails for Supabase source configuration."""
from pathlib import Path
import sys
import re

ROOT = Path(__file__).resolve().parents[1]
checks = []

def require(label: str, condition: bool) -> None:
    checks.append((label, condition))

config = (ROOT / "supabase/config.toml").read_text(encoding="utf-8")
importer = (ROOT / "supabase/functions/import-roadside-station-registry/index.ts").read_text(encoding="utf-8")
gps_enrich = (ROOT / "supabase/functions/enrich-roadside-station-gps/index.ts").read_text(encoding="utf-8")
gps_reconcile = (ROOT / "supabase/functions/reconcile-roadside-station-gps/index.ts").read_text(encoding="utf-8")
delete_account = (ROOT / "supabase/functions/delete-account/index.ts").read_text(encoding="utf-8")
schema_target = ROOT / "docs/production-schema-target.md"
audit_sql = ROOT / "supabase/security/production_rls_audit.sql"
participation_migration = ROOT / "supabase/migrations/20261009010000_secure_event_participation_rpc.sql"
preference_migration = ROOT / "supabase/migrations/20261009020000_secure_event_preference_rpc.sql"
profile_migration = ROOT / "supabase/migrations/20261009031000_secure_profile_write_rpc.sql"
registry_migration = ROOT / "supabase/migrations/20261009032000_atomic_roadside_station_registry_replace.sql"
candidate_baseline = ROOT / "supabase/baselines/production_schema_candidate_20261009.sql"
production_import = ROOT / "scripts/import-production-master-data.ps1"
bootstrap_script = ROOT / "scripts/bootstrap-production-schema.ps1"
repair_script = ROOT / "scripts/repair-production-migration-history.ps1"
cutover_runbook = ROOT / "docs/production-cutover-runbook.md"
release_policy_runbook = ROOT / "supabase/seed/PRODUCTION_RELEASE_POLICY.md"
event_service = (ROOT / "lib/services/event_service.dart").read_text(encoding="utf-8")
event_explore = (ROOT / "lib/widgets/event_explore_page.dart").read_text(encoding="utf-8")
profile_page = (ROOT / "lib/widgets/profile_page.dart").read_text(encoding="utf-8")
migration = participation_migration.read_text(encoding="utf-8")
preference = preference_migration.read_text(encoding="utf-8")
profile = profile_migration.read_text(encoding="utf-8")
registry = registry_migration.read_text(encoding="utf-8")
candidate = candidate_baseline.read_text(encoding="utf-8")
repair_script_content = repair_script.read_text(encoding="utf-8")

require("new tables are not auto-exposed", "auto_expose_new_tables = false" in config)
require("missing seed.sql is not configured", '[db.seed]\n# Disabled until a curated seed file is checked in; the current ./seed.sql is missing.\nenabled = false\nsql_paths = []' in config)
require("registry key comes from environment", 'Deno.env.get("ROADSIDESTATION_IMPORT_KEY")' in importer)
require("registry importer does not hardcode a key literal", not re.search(r'''const\s+IMPORT_KEY\s*=\s*["']''', importer))
require("supplemental registry keys use the same null separator", r'const k=x.prefecture+"\0"+x.official_name;' in importer and r'om.set(r.prefecture+"\0"+r.official_name,r)' in importer)
require("registry importer fails closed if secret is missing", "if (!IMPORT_KEY)" in importer and "status: 503" in importer)
require("registry importer restricts method", 'req.method !== "POST"' in importer)
require("registry importer delegates replacement to atomic RPC", 'sb.rpc(\n    "replace_roadside_station_registry"' in importer and "DELETE FROM public.roadside_station_registry" not in importer)
require("GPS enrichment key comes from environment", 'Deno.env.get("ROADSIDESTATION_GPS_ENRICH_KEY")' in gps_enrich and "sq-roadside-gps-enrich-20260925-v1" not in gps_enrich)
require("GPS reconciliation key comes from environment", 'Deno.env.get("ROADSIDESTATION_GPS_RECONCILE_KEY")' in gps_reconcile and "sq-roadside-gps-reconcile-20260925-v1" not in gps_reconcile)
require("GPS maintenance functions require POST and fail closed without secrets", all('req.method!=="POST"' in source and "maintenance function is not configured" in source and 'req.headers.get("x-import-key")!==KEY' in source for source in (gps_enrich,gps_reconcile)))
require("GPS maintenance functions validate coordinate bounds", all("Math.abs(lat)<=90" in source and "Math.abs(lon)<=180" in source for source in (gps_enrich,gps_reconcile)))
require("GPS maintenance defaults to dry-run", all("payload?.apply!==true" in source and "dry_run:dryRun" in source for source in (gps_enrich,gps_reconcile)))
require("GPS reconciliation preserves existing metadata", "...(t.metadata??{})" in gps_reconcile)
require("registry importer uses atomic replacement RPC", 'replace_roadside_station_registry' in importer and '.from("roadside_station_registry").delete()' not in importer);
require("atomic registry RPC pins search_path and uses SECURITY DEFINER", "SECURITY DEFINER\nSET search_path = ''" in (ROOT / "supabase/migrations/20261009032000_atomic_roadside_station_registry_replace.sql").read_text(encoding="utf-8"));
require("atomic registry RPC is not executable by anon/authenticated", "REVOKE ALL ON FUNCTION public.replace_roadside_station_registry(jsonb) FROM PUBLIC, anon, authenticated" in (ROOT / "supabase/migrations/20261009032000_atomic_roadside_station_registry_replace.sql").read_text(encoding="utf-8"));
require("production baseline includes atomic registry RPC", "public.replace_roadside_station_registry" in candidate);
require("migration repair requires atomic registry RPC and service-role-only grant", "to_regprocedure('public.replace_roadside_station_registry(jsonb)') IS NOT NULL" in repair_script_content and "has_function_privilege('service_role', 'public.replace_roadside_station_registry(jsonb)', 'EXECUTE')" in repair_script_content);
require("migration repair refuses when user-specific rows exist", "(SELECT count(*) FROM public.profiles) = 0" in repair_script_content and "(SELECT count(*) FROM public.collection_history) = 0" in repair_script_content and "(SELECT count(*) FROM public.location_security_events) = 0" in repair_script_content and "(SELECT count(*) FROM public.user_event_favorites) = 0" in repair_script_content);

require("registry errors do not return stack to clients", "stack:(e as any)?.stack" not in importer and 'error: "registry import failed"' in importer)
require("account deletion restricts method", 'req.method !== "POST"' in delete_account)
require("account deletion hides low-level auth details", "auth_message:" not in delete_account and "delete_message:" not in delete_account)
require("production schema target exists", schema_target.is_file())
require("read-only RLS audit SQL exists", audit_sql.is_file())
require("production bootstrap candidate exists", candidate_baseline.is_file())
require("production master-data import runner exists", production_import.is_file())
require("production import defaults to dry run", "if (-not $Apply)" in production_import.read_text(encoding="utf-8"))
require("production import checks exact project ref before writes", "dbUrl -notmatch [regex]::Escape($ExpectedProjectRef)" in production_import.read_text(encoding="utf-8"))
require("production import makes each SQL file transactional", "--single-transaction" in production_import.read_text(encoding="utf-8"))
require("production import verifies source row counts", "all 13 master-table counts match" in production_import.read_text(encoding="utf-8"))
require("production bootstrap is guarded and dry-run by default", bootstrap_script.is_file() and "[switch]$Apply" in bootstrap_script.read_text(encoding="utf-8") and "Type APPLY" in bootstrap_script.read_text(encoding="utf-8"))
require("migration history repair checks completed bootstrap first", repair_script.is_file() and "NOT_READY" in repair_script.read_text(encoding="utf-8") and "Type REPAIR" in repair_script.read_text(encoding="utf-8"))
require("migration history repair includes legacy 8-digit versions", r"\d{8,14}" in repair_script.read_text(encoding="utf-8"))
require("cutover runbook blocks legacy migration replay", cutover_runbook.is_file() and "Do **not** run `supabase db push`" in cutover_runbook.read_text(encoding="utf-8"))
require("production candidate does not recreate retired seichi", "CREATE TABLE public.seichi " not in candidate)
require("production candidate has no direct client-admin mutation policies", "content_blocks_admin_insert" not in candidate and "events_admin_update_theme" not in candidate)
require("PostGIS is installed outside the exposed public schema", "CREATE EXTENSION IF NOT EXISTS postgis WITH SCHEMA gis" in candidate and "public.spatial_ref_sys" not in candidate)
require("anon cannot use the PostGIS schema", "GRANT USAGE ON SCHEMA gis TO authenticated, service_role" in candidate and "GRANT USAGE ON SCHEMA gis TO anon" not in candidate)
require("event service uses participation RPC", "ensure_event_participation" in event_service and ".from('user_event_participations').insert" not in event_service)
require("event explore uses leave RPC", "leave_event_participation" in event_explore and ".from('user_event_participations')\n          .update" not in event_explore)
require("profile page uses profile RPC", "save_my_profile" in profile_page and ".from('profiles').upsert" not in profile_page)
require("participation RPC pins search_path", "SECURITY DEFINER\nSET search_path = ''" in migration)
require("participation writes are revoked from client roles", "REVOKE INSERT, UPDATE, DELETE ON TABLE public.user_event_participations FROM anon, authenticated" in migration)
require("preference RPC pins search_path", "SECURITY DEFINER\nSET search_path = ''" in preference)
require("preference writes are revoked from client roles", "REVOKE INSERT, UPDATE, DELETE ON TABLE public.user_event_preferences FROM anon, authenticated" in preference)
require("event service uses preference RPC", "set_current_event_preference" in event_service and ".from('user_event_preferences').upsert" not in event_service)
require("profile RPC pins search_path", "SECURITY DEFINER\nSET search_path = ''" in profile)
require("profile RPC allowlists age groups", all(x in profile for x in ("'10代以下'", "'20代'", "'回答しない'")))
require("profile RPC allowlists avatar keys", all(x in profile for x in ("'adventurer'", "'mountain'", "'shrine'", "'camera'", "'train'", "'star'")))
require("profile writes are revoked from client roles", "REVOKE INSERT, UPDATE, DELETE ON TABLE public.profiles FROM anon, authenticated" in profile)
require("registry RPC has one least-privilege grant pair", registry.count("REVOKE ALL ON FUNCTION public.replace_roadside_station_registry(jsonb)") == 1 and registry.count("GRANT EXECUTE ON FUNCTION public.replace_roadside_station_registry(jsonb) TO service_role") == 1)
require("profile RPC is in candidate with no direct write grant", "public.save_my_profile" in candidate and "GRANT INSERT (id, display_name" not in candidate and "GRANT UPDATE (display_name" not in candidate)
require("both participation RPCs are in candidate", "public.ensure_event_participation" in candidate and "public.leave_event_participation" in candidate)
require("preference RPC is in candidate", "public.set_current_event_preference" in candidate)
require("future public tables default to least privilege", "ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public" in candidate and "REVOKE ALL PRIVILEGES ON TABLES FROM anon, authenticated, PUBLIC" in candidate)

seed_dir = ROOT / "supabase/seed/production_master_data"
require("production release-policy runbook exists", release_policy_runbook.is_file() and "../PRODUCTION_RELEASE_POLICY.md" in (seed_dir / "README.md").read_text(encoding="utf-8"))
require("master-data manifest exists", (seed_dir / "MANIFEST.md").is_file())
require("post-import verifier exists", (seed_dir / "VERIFY.sql").is_file())
seed_sql = "\n".join(p.read_text(encoding="utf-8") for p in seed_dir.glob("*.sql") if p.name != "VERIFY.sql")
require("master-data export excludes user histories and profiles", all(f"INSERT INTO public.{table}" not in seed_sql for table in ("profiles", "collection_history", "place_visits", "announcement_reads", "user_event_preferences", "user_event_participations", "user_event_favorites", "location_security_events", "location_security_states")))

failed = [label for label, ok in checks if not ok]
for label, ok in checks:
    print(f'{"PASS" if ok else "FAIL"}: {label}')
print(f"\n{len(checks) - len(failed)}/{len(checks)} checks passed")
if failed:
    sys.exit(1)
