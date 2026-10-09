# Production schema cutover and security audit

**Live status update: 2026-10-10.** The migration-history repair and five post-baseline migrations are now complete; all 80 local and remote migration versions match. The section below titled “Migration history and rollout gates” reflects the current state. The production app is not yet cleared for release.

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

### Live status as of 2026-10-10

- The guarded repair marked the 75 historical migration versions as applied after the production preflight and exact confirmation. It did not replay the historical SQL files.
- The five reviewed post-baseline migrations were then applied successfully: participation RPC, preference RPC, profile-write RPC, atomic roadside-station registry replacement, and place timestamp preservation.
- `supabase migration list --linked` now shows all 80 local and remote versions matching.
- Read-only checks after the push confirmed 25 public application tables, 24 public RLS policies, zero public application tables without RLS, and no direct client INSERT/UPDATE/DELETE/TRUNCATE grants on the restricted user/activity tables reviewed.
- Master-data counts remain consistent: 51 events, 1,713 places, 2,742 contents, and 2,721 event-content mappings. All 1,713 places have non-null `updated_at`, latitude/longitude, and geography `location`.
- The source CI workflows for Flutter, iOS, Edge Functions, specification gate, and Supabase security source checks passed for the reviewed audit commit before this documentation refresh.

### Remaining release gates

1. **Auth:** verify anonymous sign-in in the production Supabase Dashboard. This setting cannot be proven from database grants or the local `config.toml`.
2. **Storage and artwork:** production currently has zero Storage buckets and zero objects. Review intended bucket policies and asset rights separately; official Jomo Karuta artwork permission is not confirmed.
3. **Maintenance Edge Functions:** only `delete-account` is deployed in production (active version 2, `verify_jwt=true`). Do not deploy roadside-station importer/GPS maintenance functions until independently generated V2 secrets are configured, their fail-closed and dry-run behavior is verified, and deployment/operation is explicitly approved.
4. **Account deletion:** exercise the authenticated delete/cascade flow with a disposable test account before production release. Do not use a real user account as the test.
5. **Release policy:** `app_release_policies` intentionally has zero rows at the pre-release stage. Add a reviewed row only after the actual production binary version/build and public store listing URL are confirmed. Do not copy closed-test values.
6. **Production app:** build with `APP_ENV=production` and the production Supabase URL/publishable key; smoke-test the app, then separately review the Play Console track and uploaded AAB. No production app release has been performed by the database cutover.

The production app is **not yet cleared for release**. Do not rerun the one-time bootstrap, re-import the master data, or replay the five applied migrations.

## Reproducibility and safety

- `supabase/baselines/closed_test_catalog_snapshot_20261009.sql` is an evidence snapshot of live test catalog definitions, not a replayable production migration.
- `supabase/baselines/production_schema_candidate_20261009.sql` is the reviewed clean schema candidate used by the guarded bootstrap.
- `supabase/seed/production_master_data/MANIFEST.md` documents row counts and execution order.
- Seed SQL files were individually syntax/constraint checked in rollback-only transactions against the closed-test schema. A production rehearsal validated the schema and first 250 place rows, including EWKT geography conversion. The live production counts and relationship checks above provide the post-load verification; do not rerun the import on production unless the guarded importer’s resume checks specifically indicate a partial import.
- No Auth users, user history, announcements, release-policy values, or Storage objects were copied. No production app release or store track was changed.


## Incremental reconciliation in three-table batches

To avoid large tool requests stopping mid-run, the live production data was checked in batches of at most three tables. All 13 master/reference tables have the expected row counts; all relationship checks passed with zero orphan references. Row hashes match for every table except expected/representation-specific differences: the single test-project event cover URL is intentionally nulled; place geography is compared by coordinates/distance rather than raw serialization; and `content_blocks.metadata` is structurally equal JSONB even though a raw text hash differs. All non-metadata content-block fields match.

All 1,713 `places.updated_at` values had been overwritten by the insert trigger during the initial import. They have now been restored from the closed-test master data; the source and production timestamp hashes match. No Auth users or user-specific records were imported. The production schema bootstrap was not rerun; an attempted rehearsal correctly stopped at the existing `achievements` table before changing anything.
