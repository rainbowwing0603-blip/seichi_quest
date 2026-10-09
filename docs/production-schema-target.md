# Production schema target and live verification

Checked: 2026-10-09
Production project: `npirfaoxcarfuqjlwgav`
Closed-test source: `wxlvhpmolrtcwryaazfb`

## Design decisions

The production database is built from a clean, explicit baseline rather than replaying the historical migration directory against an empty database. The retired `public.seichi` table and its old coupling are not recreated. Current collection uses the generic event/content/place model.

Security defaults:
- RLS is enabled on every application table, and a database event trigger enables RLS on future public tables.
- Public API grants are explicit and least-privilege; new tables/functions are not auto-exposed by the local Supabase config.
- User-owned rows are filtered by `auth.uid()`; client writes to `user_event_participations`, `user_event_preferences`, and `profiles` are routed through server-validated RPCs.
- RPCs derive the actor from the authenticated session, validate active event/state transitions, use database timestamps, pin SECURITY DEFINER search paths, and revoke direct table mutation grants where appropriate.
- Participation activation, participation leave, and current-event preference changes serialize per-user state changes with a transaction-scoped advisory lock.
- The roadside-station registry importer stages and validates the full 1,234-row snapshot, performs an atomic replacement, preserves matching place links and local enrichment, and grants RPC execution only to `service_role`.
- No test Auth users, profiles, collection history, visits, preferences, participation, favorites, announcement reads, location-security state, reset ledgers, admin membership, announcements, or test release-policy values are copied.

## Live production schema and data

The bootstrap and curated master-data import have been applied to production. **Do not rerun** `scripts/bootstrap-production-schema.ps1 -Apply` or re-import the seed on the populated project.

| Validation | Live result |
|---|---:|
| Application tables / public RLS policies | 25 / 24 |
| Application tables without RLS | 0 |
| Retired `public.seichi` | absent |
| Events | 51 |
| Places / places without geography | 1,713 / 0 |
| Contents / event-content mappings | 2,742 / 2,721 |
| Content blocks | 336 |
| Achievements / event-achievement mappings | 18 / 18 |
| Geo regions / prefecture mappings | 57 / 141 |
| Collection series / place mappings / region mappings | 1 / 1,231 / 57 |
| Roadside-station registry | 1,234 |
| Orphan event-content mappings | 0 |
| Duplicate registry keys | 0 |
| Closed-test project URLs in exported app master data | 0 |
| User-specific rows copied | 0 |
| Announcements / production release-policy rows | 0 / 0 |

The PostGIS nearby-place query succeeded. All 2,721 event-content mappings join to valid events, contents, and places. The read-only function audit confirms app-owned SECURITY DEFINER functions have fixed search paths and expected EXECUTE grants.

## RLS advisor findings

The five `rls_enabled_no_policy` findings are intentional server-only tables: `event_collection_resets`, `location_security_events`, `location_security_states`, `place_visits`, and `roadside_station_registry`. RLS is enabled and direct client table grants are absent.

The SECURITY DEFINER advisor findings represent callable RPCs, not automatically vulnerabilities. Each function must keep a fixed search path and validate user identity/arguments. `get_public_ranking` is intentionally callable anonymously to support public rankings; the remaining user-facing RPCs are restricted to `authenticated`, while the atomic registry replacement is restricted to `service_role`. Re-run the advisor after any RPC or grant change.

The performance advisor currently reports 31 unused indexes. This is a newly initialized production database, so the advisor has little workload history. Do not drop indexes solely from this initial unused-index report; compare each index against foreign keys, uniqueness constraints, query plans, and real workload before any removal.

## Curated data export

`supabase/seed/production_master_data/MANIFEST.md` lists all 10,320 master/reference rows across 13 tables and the numbered SQL files. `VERIFY.sql` is a read-only verification query, not a seed file. Both bootstrap and import scripts now select only numbered `NNN_*.sql` data files and exclude `VERIFY.sql`.

The event seed nulls the one cover URL that pointed at the closed-test Supabase project. Local Flutter `assets/...` paths remain local references; no Storage bytes were copied. The Jomo Karuta official artwork permission is still unconfirmed, so do not copy or redistribute Storage objects until object hashes, MIME types, bucket policies, and rights are reviewed.

## Migration history: remaining maintenance step

The live schema and data exist, but `supabase migration list` currently returns an empty production migration history. A direct catalog query also found no `supabase_migrations.schema_migrations` relation. Do not assume the CLI history is initialized.

From a local checkout with the Supabase CLI installed:
1. Link to the exact production ref `npirfaoxcarfuqjlwgav`.
2. Set `SUPABASE_DB_URL` only in the current PowerShell session to the direct production database URI.
3. Run `scripts/repair-production-migration-history.ps1` in dry-run mode and review the legacy versions it proposes to mark applied.
4. If and only if its live preflight says `READY`, run the script with `-Apply` and the required typed confirmation. It marks repository migrations older than `20261009010000` as represented by the clean baseline.
5. Run `supabase db push` to apply/record the four post-baseline migrations: participation RPC, preference RPC, profile-write RPC, and atomic registry replacement.
6. Verify `supabase migration list`, re-run the read-only RLS audit, and run the data-count/FK/spatial checks. Never rerun the one-time schema bootstrap.

This local CLI operation cannot be completed by the current database connector. Do not manually create or edit migration-history rows through ad hoc SQL.

## Remaining production release gates

- Confirm production Auth anonymous sign-in in the dashboard. The Flutter app creates an anonymous session when no session exists; local `supabase/config.toml` does not prove the hosted setting.
- Review Storage bucket policies and assets. No Storage objects were copied.
- Rotate the previously deployed closed-test roadside-import secret and set `ROADSIDESTATION_IMPORT_KEY` as a Supabase secret before deploying the reviewed importer. Source changes do not rotate a deployed secret or erase old Git history.
- Recover/review `enrich-roadside-station-gps` and `reconcile-roadside-station-gps` function source before deploying either.
- Confirm the production `delete-account` function is compatible with the reviewed source and verify the authenticated deletion path/cascade behavior before release.
- Insert a deliberate production `app_release_policies` row only after the production build code/version, minimum supported build, store URL, and update message are decided. The table is intentionally empty now.
- Wait for Flutter and iOS CI checks, perform production-configured smoke tests, and only then prepare a production build. No Google Play track or app release was changed by this cutover.

## Reproducible artifacts

- `supabase/baselines/closed_test_catalog_snapshot_20261009.sql`: evidence-only live test catalog snapshot, not a replayable baseline.
- `supabase/baselines/production_schema_candidate_20261009.sql`: clean production schema candidate.
- `supabase/seed/production_master_data/`: curated data export and manifest.
- `supabase/security/production_rls_audit.sql`: read-only live function/grant audit.
- `scripts/bootstrap-production-schema.ps1`: guarded one-time bootstrap, dry-run by default.
- `scripts/import-production-master-data.ps1`: guarded seed importer, dry-run by default.
- `scripts/repair-production-migration-history.ps1`: guarded local CLI migration-history reconciliation.
