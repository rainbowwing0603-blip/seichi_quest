#!/usr/bin/env python3
"""Lightweight static guardrails for Supabase source configuration."""
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
checks = []

def require(label: str, condition: bool) -> None:
    checks.append((label, condition))

config = (ROOT / "supabase/config.toml").read_text(encoding="utf-8")
importer = (ROOT / "supabase/functions/import-roadside-station-registry/index.ts").read_text(encoding="utf-8")
delete_account = (ROOT / "supabase/functions/delete-account/index.ts").read_text(encoding="utf-8")
schema_target = ROOT / "docs/production-schema-target.md"
audit_sql = ROOT / "supabase/security/production_rls_audit.sql"
participation_migration = ROOT / "supabase/migrations/20261009010000_secure_event_participation_rpc.sql"
candidate_baseline = ROOT / "supabase/baselines/production_schema_candidate_20261009.sql"
event_service = (ROOT / "lib/services/event_service.dart").read_text(encoding="utf-8")
event_explore = (ROOT / "lib/widgets/event_explore_page.dart").read_text(encoding="utf-8")
migration = participation_migration.read_text(encoding="utf-8")
candidate = candidate_baseline.read_text(encoding="utf-8")

require("new tables are not auto-exposed", "auto_expose_new_tables = false" in config)
require("missing seed.sql is not configured", '[db.seed]\n# Disabled until a curated seed file is checked in; the current ./seed.sql is missing.\nenabled = false\nsql_paths = []' in config)
require("registry key comes from environment", 'Deno.env.get("ROADSIDESTATION_IMPORT_KEY")' in importer)
require("old fixed importer key absent from function source", "sq-roadside-20260925-fixed-source-import-v1" not in importer)
require("registry importer fails closed if secret is missing", "if (!IMPORT_KEY)" in importer and "status: 503" in importer)
require("registry importer restricts method", 'req.method !== "POST"' in importer)
require("registry errors do not return stack to clients", "stack:(e as any)?.stack" not in importer and 'error: "registry import failed"' in importer)
require("account deletion restricts method", 'req.method !== "POST"' in delete_account)
require("account deletion hides low-level auth details", "auth_message:" not in delete_account and "delete_message:" not in delete_account)
require("production schema target exists", schema_target.is_file())
require("read-only RLS audit SQL exists", audit_sql.is_file())
require("production bootstrap candidate exists", candidate_baseline.is_file())
require("production candidate does not recreate retired seichi", "CREATE TABLE public.seichi " not in candidate)
require("production candidate has no direct client-admin mutation policies", "content_blocks_admin_insert" not in candidate and "events_admin_update_theme" not in candidate)
require("event service uses participation RPC", "ensure_event_participation" in event_service and ".from('user_event_participations').insert" not in event_service)
require("event explore uses leave RPC", "leave_event_participation" in event_explore and ".from('user_event_participations')\n          .update" not in event_explore)
require("participation RPC pins search_path", "SECURITY DEFINER\nSET search_path = ''" in migration)
require("participation writes are revoked from client roles", "REVOKE INSERT, UPDATE, DELETE ON TABLE public.user_event_participations FROM anon, authenticated" in migration)
require("both participation RPCs are in the production candidate", "public.ensure_event_participation" in candidate and "public.leave_event_participation" in candidate)
require("future public tables default to least privilege", "ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public" in candidate and "REVOKE ALL PRIVILEGES ON TABLES FROM anon, authenticated, PUBLIC" in candidate)

failed = [label for label, ok in checks if not ok]
for label, ok in checks:
    print(f'{"PASS" if ok else "FAIL"}: {label}')
print(f"\n{len(checks) - len(failed)}/{len(checks)} checks passed")
if failed:
    sys.exit(1)
