# Production schema cutover and security audit

Date: 2026-10-09
Branch: `audit/production-bootstrap-readiness-20261009`
Production project: `npirfaoxcarfuqjlwgav`
Closed-test project: `wxlvhpmolrtcwryaazfb`

## Current decision

The production database schema and curated master/reference data are now present and have passed the live structural/data integrity checks below. **The production app is not yet cleared for release.** The old `public.seichi` table is absent. No Auth users or user-specific history were copied.

The earlier preparation notes that described production as empty are superseded by this live-state section. Do not rerun `scripts/bootstrap-production-schema.ps1`: it is a one-time bootstrap for an empty schema and must refuse to run against the populated production database.

## Live database verification

| Check | Result |
|---|---:|
| Application tables / public RLS policies | 25 / 24 |
| Application tables without RLS | 0 |
| Retired `public.seichi` table | absent |
| Events / places / contents | 51 / 1,713 / 2,742 |
| Event-content mappings / content blocks | 2,721 / 336 |
| Achievements / event-achievement mappings | 18 / 18 |
| Geo regions / prefecture mappings | 57 / 141 |
| Collection series / place mappings / region mappings | 1 / 1,231 / 57 |
| Roadside-station registry | 1,234 |
| Places without geography | 0 |
| Orphan event-content mappings | 0 |
| Duplicate registry keys | 0 |
| Test-project URLs in exported app master data | 0 |
| User-specific rows copied | 0 |
| Announcement / production release-policy rows | 0 / 0 |

All 1,713 place geography values are populated. Event-content, content-block, achievement, geo-region, collection-series, and registry place relationships were checked for orphan rows. A PostGIS nearby-place query succeeded.

Five advisor `rls_enabled_no_policy` findings are intentional for server-only tables (`event_collection_resets`, `location_security_events`, `location_security_states`, `place_visits`, and `roadside_station_registry`): RLS is enabled and direct client grants are absent. App-owned SECURITY DEFINER functions must keep an empty or explicitly restricted search path and least-privilege EXECUTE grants; `supabase/security/production_rls_audit.sql` lists the live function grants.

## Schema and source changes staged in this PR

- Rebuilt a clean schema candidate with 25 application tables, explicit grants, RLS, and an event trigger that enables RLS on future public tables. Retired `public.seichi` and old client-admin mutation paths are not recreated.
- Added validated server-side RPCs for participation, current-event preference, profile writes, and atomic roadside-station registry replacement. User identity is derived from `auth.uid()`; event-state writes use database time and transaction-scoped per-user serialization.
- Updated Flutter call sites to use the RPCs rather than direct client writes for protected state.
- Disabled auto-exposure of newly created tables and the invalid seed configuration pointing at a missing `supabase/seed.sql`.
- Removed the registry importer’s fixed source key, required POST, made missing-secret behavior fail closed, and replaced multi-request destructive delete/reinsert with `replace_roadside_station_registry(jsonb)`. The RPC is granted only to `service_role`.
- Hardened account deletion method handling and client-facing errors.
- Exported 10,320 curated master/reference rows across 13 tables in 47 SQL files. Auth/user data, user histories, preferences, participation, favorites, location-security data, announcements, release-policy rows, and Storage object bytes are excluded.
- Added dry-run-first bootstrap/import/repair scripts, a read-only RLS audit, static CI guardrails, and a cutover runbook.

## Migration history and rollout gates

The live schema/data are present, but the Supabase CLI migration history has not yet been repaired/verified. A direct query found no `supabase_migrations.schema_migrations` relation, so do not assume `supabase migration list` is ready. Use a local checkout linked to the exact production project and follow `docs/production-cutover-runbook.md`; run the guarded history repair only after its live preflight passes, then run `supabase db push` and verify the resulting migration list. The schema bootstrap must not be rerun.

Still required before a production-configured app build:
1. Verify Auth anonymous sign-in in the production dashboard because the app creates anonymous sessions when no session exists.
2. Review Storage bucket/policies and any object migration separately. No Storage bytes were copied. The Jomo Karuta artwork permission remains unconfirmed; do not redistribute it until rights and hashes are reviewed.
3. Rotate the previously deployed closed-test roadside-import key and configure `ROADSIDESTATION_IMPORT_KEY` as a Supabase secret before deploying the reviewed function. Source edits do not rotate a deployed secret or erase old Git history.
4. Recover/review the missing `enrich-roadside-station-gps` and `reconcile-roadside-station-gps` function sources before deploying either.
5. Add a deliberate production `app_release_policies` row only after the intended production build/version/minimum build/store URL are decided. The table is intentionally empty now.
6. Finish GitHub Flutter and iOS CI runs, run functional smoke tests against production configuration, and only then prepare a production build. No Google Play track or app release has been changed by this work.

## Reproducibility and safety

- `supabase/baselines/closed_test_catalog_snapshot_20261009.sql` is an evidence snapshot of live test catalog definitions, not a replayable production migration.
- `supabase/baselines/production_schema_candidate_20261009.sql` is the reviewed clean schema candidate used by the guarded bootstrap.
- `supabase/seed/production_master_data/MANIFEST.md` documents row counts and execution order.
- Seed SQL files were individually syntax/constraint checked in rollback-only transactions against the closed-test schema. A production rehearsal validated the schema and first 250 place rows, including EWKT geography conversion. The live production counts and relationship checks above provide the post-load verification; do not rerun the import on production unless the guarded importer’s resume checks specifically indicate a partial import.
- No Auth users, user history, announcements, release-policy values, or Storage objects were copied. No production app release or store track was changed.
