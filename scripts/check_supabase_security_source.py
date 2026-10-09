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
require("participation RPC pins search_path", "SECURITY DEFINER\nSET search_path = \"\"" in participation_migration.read_text(encoding="utf-8"))
require("participation writes are revoked from client roles", "REVOKE INSERT, UPDATE, DELETE ON TABLE public.user_event_participations FROM anon, authenticated" in participation_migration.read_text(encoding="utf-8"))

failed = [label for label, ok in checks if not ok]
for label, ok in checks:
    print(f'{"PASS" if ok else "FAIL"}: {label}')
print(f"\n{len(checks) - len(failed)}/{len(checks)} checks passed")
if failed:
    sys.exit(1)
