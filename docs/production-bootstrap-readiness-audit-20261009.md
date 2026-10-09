# Production bootstrap readiness: dependency and safety audit

Date: 2026-10-09
Branch audited: `feature/android-next-release` at `f33a91107b8449de7a832b3969f739619bd16b9f`
Scope: read-only inspection of GitHub source and the test/production Supabase projects. No database, Storage, Auth, Edge Function, or release settings were changed.

## Executive decision

**Production remains blocked.** The new production project is healthy but empty; that is expected and does not establish application readiness. Do not replay the existing migration directory directly, deploy the current maintenance functions unchanged, or point an app build at production yet.

## Current project comparison

| Area | Closed-test project | Production project |
|---|---|---|
| Database | Existing app schema and data | No app tables and no recorded migrations |
| Edge Functions | 5 active functions | None |
| PostGIS | Installed and used by spatial RPCs | Not installed; only available in the extension catalog |
| Security/performance advisors | Existing findings need per-item review | No findings returned, but an empty schema makes this a weak readiness signal |
| Auth | Client calls anonymous sign-in when no session exists | Anonymous sign-in setting still needs direct confirmation |
| Storage | 45 objects in `event-card-images` reported by prior audit; object contents/URLs need verification | No verified bucket/object deployment yet |

Production project ref: `npirfaoxcarfuqjlwgav`. Closed-test project ref: `wxlvhpmolrtcwryaazfb`.

## Bootstrap blockers

1. The current migration directory is not a clean-room bootstrap. Early migrations assume existing tables, and some support tables have no clear creation migration in the branch: `geo_regions`, `geo_region_prefectures`, `roadside_station_registry`, `collection_series`, `collection_series_places`, `collection_series_regions`, `location_security_states`, `location_security_events`, and `private.admin_users`.
2. `supabase/config.toml` enables `supabase/seed.sql`, but that file is absent. The Jomo Karuta URL migrations update the retired `public.seichi` table and refer to test-project Storage URLs, so they must not be replayed as a fresh production seed.
3. Test migration history contains three older CodeMagic bridge versions not present in the repository. Recover the original SQL or document their final-state effect; do not fabricate historical migration contents.
4. The 2026-09-23 local backup described in `docs/specification/13_disaster_recovery.md` is promising but is not yet a verified current restore source: it predates later schema changes, has no full restore rehearsal, and excludes dashboard secrets. If that backup is available on the user's PC, validate it before choosing a fresh live schema dump.
5. PostGIS must be installed in production before spatial types/functions and location RPCs are applied. Review extension schema/search-path assumptions and grants as part of the baseline, rather than installing it opportunistically after tables/functions.

## App-to-database RPC contracts verified against the closed-test database

The client source calls the following RPCs, and the named functions were found in the closed-test database:

- `get_event_contents_by_region(p_event_id uuid, p_region_code text)`
- `get_event_contents_by_ids(p_event_id uuid, p_event_content_ids uuid[])`
- `get_event_contents_page(p_event_id uuid, p_offset integer, p_limit integer, p_collection_state text)`
- `get_event_contents_in_bounds(p_event_id uuid, p_south double precision, p_west double precision, p_north double precision, p_east double precision, p_limit integer)`
- `get_event_contents_nearby(p_event_id uuid, p_latitude double precision, p_longitude double precision, p_radius_meters double precision, p_limit integer)`
- `get_my_collection_history()`
- `reset_event_collection_history(p_event_id uuid)`
- `record_place_visit_and_collect(p_place_id uuid, p_client_visit_id uuid, p_visited_at timestamptz, p_latitude double precision, p_longitude double precision, p_accuracy_meters double precision, p_source text, p_metadata jsonb)`
- `get_event_regional_map_progress(p_event_id uuid)`
- `get_my_location_security_state()`
- `report_location_integrity_violation(p_violation_type text)`
- `get_event_progress_summary(p_event_id uuid)`

These contracts are a smoke-test checklist, not proof that their migration files form a complete baseline. The collection RPCs use server-side identity/time and security-definer protections; preserve their exact signatures, grants, search-path settings, and constraints in the approved baseline.

## Edge Function deployment gates

The test project has five active functions:

- `delete-account` v5: source uses user-authenticated context despite `verify_jwt=false`; re-review the actual authentication path before changing settings.
- `import-roadside-station-registry` v11: source contains a fixed maintenance credential and deletes/reinserts the live registry in batches. Do not deploy this source to production unchanged. Move the credential to a Supabase secret, validate into staging, then use an atomic/safe replacement strategy and avoid returning internal error details.
- `enrich-roadside-station-gps` v15: active in test but source is missing from this branch; do not deploy until source is recovered and secret handling is reviewed.
- `reconcile-roadside-station-gps` v1: active in test, `verify_jwt=false`, source missing from branch and contains a fixed maintenance-key pattern. Do not deploy until recovered, moved to managed secrets, and access is restricted.
- `verify-roadside-station-gsi` v2: source exists in the branch, but it is currently a minimal health response, not evidence that the entire GSI verification workflow is production-ready.

Do not copy credentials from source into documentation, logs, commits, or chat.

## Data migration policy

Candidate master/reference data, after validation: `events`, `places`, `contents`, `event_contents`, `content_blocks`, `achievements`, `event_achievements`, `geo_regions`, `geo_region_prefectures`, `collection_series`, `collection_series_places`, `collection_series_regions`, `roadside_station_registry`, carefully reviewed `announcements`, and an intentionally set `app_release_policies` row.

Exclude user-specific data by default: Auth users, `profiles`, `collection_history`, `place_visits`, `user_event_preferences`, `user_event_participations`, `user_event_favorites`, `announcement_reads`, `location_security_states`, `location_security_events`, and `private.admin_users`. Confirm whether internal reset/security tables should start empty rather than copying test state.

The test project has 1,713 `places`, 2,742 `contents`, 2,721 `event_contents`, 336 `content_blocks`, and 1,234 roadside registry rows according to the audit. These are validation references only, not instructions to blindly copy all rows. Recheck counts and relationships immediately before any export.

## Storage and image safety

- The 44 Jomo Karuta card-image references must be mapped to approved destination objects; changing URLs alone does not upload bytes.
- Some existing Storage objects may contain placeholder/test imagery. Inspect and hash the actual objects before migration.
- Flutter-local `assets/...` paths are not Storage object paths; preserve those references and confirm the assets are bundled in the app.
- Confirm rights/permission before replacing or redistributing official card artwork.
- Rebuild destination URLs using the production project's bucket and object paths only after the object copy has been verified.

## Ordered implementation plan

1. Obtain and validate the most current schema backup/snapshot; compare it with the branch and the live test schema.
2. Produce a clean, reproducible baseline covering tables, columns, constraints, indexes, triggers, functions, RLS policies, grants, extensions, buckets, and Storage policies.
3. Resolve missing support-table DDL and the three missing migration-history entries without replaying obsolete `seichi` assumptions.
4. Separate schema from master-data export; stage and validate master data and foreign-key relationships.
5. Harden/recover Edge Function sources and manage secrets outside source code.
6. Apply the approved baseline and master data to production only after explicit go-ahead; copy verified Storage objects.
7. Compare schema signatures, row counts, key relationships, grants/RLS, function signatures, and Storage object hashes. Run the security advisor after schema deployment.
8. Verify anonymous sign-in and perform functional smoke tests for event listing, content pages/map queries, stamp collection, collection history, regional progress, story preview, announcements, version policy, and location-integrity reporting.
9. Only then prepare a production-configured build. Keep the existing closed-test workflow explicitly set to `APP_ENV=closed_test`; do not change the current test app's backend.

## Estimated remaining hands-on time

These are planning estimates, not promises:

- If the 2026-09-23 backup can be found, is readable, and can be reconciled to the current schema: approximately **2–4 hours** of active work after the user is back at the PC, followed by **30–60 minutes** of functional validation.
- If a fresh schema snapshot/export is required and all needed credentials are available: approximately **4–7 hours** of active work, plus **1–2 hours** for smoke tests and fixes.
- If the snapshot/export route is blocked, function sources cannot be recovered, or schema drift is substantial: allow **a further half-day or more**.

The largest uncertainty is not writing SQL; it is proving that the baseline exactly matches the current test schema and that production data/assets/functions are safe to deploy. Keep production untouched until those checks pass.


## Additional RLS baseline notes

A read-only policy inventory on the closed-test project confirms RLS is enabled on the application tables. The baseline must preserve policies rather than just recreating tables:

- User-owned policies exist for profiles, collection history, place visits, event preferences/participations/favorites, and announcement reads.
- Published/active read policies exist for events, contents, event contents, content blocks, achievements, geo regions/prefectures, and collection-series reference tables.
- `app_release_policies` has an active-policy read for `anon` and `authenticated`; events also has an explicit anon active-read policy.
- `private.admin_users`, `event_collection_resets`, `location_security_events`, `location_security_states`, and `roadside_station_registry` have RLS enabled but no ordinary table policies. Do not add broad client policies to clear advisor messages; verify their intended service-role/function-only access and grants.
- `spatial_ref_sys` is extension-owned and RLS-disabled. Do not blindly alter it to silence the advisor; confirm the PostGIS deployment pattern and function/table grants after the extension is installed.
- Several admin update/insert/delete policies use the authenticated role but must be checked alongside their `is_admin()` predicates and function grants. The existence of a policy alone is not proof of least privilege.

The production project's current empty-schema advisor result is not comparable to these test findings. Re-run advisors only after the approved schema and policies are installed.


## Catalog-derived schema snapshot captured remotely

A read-only catalog extraction from the live closed-test database was committed on this audit branch as `supabase/baselines/closed_test_catalog_snapshot_20261009.sql`.

Captured counts:
- 26 application tables (excluding extension-owned `public.spatial_ref_sys`)
- 95 table constraints
- 76 indexes
- 39 RLS policies
- 4 non-internal triggers
- 28 non-extension-owned function definitions (application functions, including security-definer functions)
- 383 table privilege inventory entries
- Installed extensions include PostGIS 3.3.7 in `public`, pgcrypto/uuid-ossp/http/pg_stat_statements in `extensions`, and Supabase Vault in `vault`.

The snapshot now includes all 28 non-extension-owned functions in the public/private schemas, rather than only a hand-selected RPC list. This makes a current live catalog snapshot available without waiting for the PC. It is deliberately marked **not a drop-in executable migration**: extension installation/order, function dependencies, function EXECUTE grants, sequence privileges, ownership, role grants, Storage buckets/policies, Auth settings, and extension-owned PostGIS views still need a separate verified pass. All 28 non-extension-owned public/private functions are present in the snapshot; PostGIS-owned functions and views are intentionally excluded. In particular, the target production project must not receive this file blindly. The next step is to compare the snapshot against repository migrations, fill any omissions, then create a reviewed idempotent production baseline and validation script.
