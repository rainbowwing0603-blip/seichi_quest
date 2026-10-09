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


## User decision: rebuild cleanly, do not blindly inherit legacy tables or RLS

The requested target is a clean modern schema, not a byte-for-byte clone of historical structure. The catalog snapshot is a source of evidence, not an authority to replay every object. In particular, do not recreate retired `public.seichi`, legacy-only columns/FKs, temporary CodeMagic bridge objects, or policies simply because they exist in historical migrations.

### Target data model principles

- Use the generic event/content model: `events`, `places`, `contents`, `event_contents`, `content_blocks`; retain collection-series/region reference tables only where current app features need them.
- Keep location visit/collection writes behind carefully validated server-side RPCs. The client must not be able to forge user IDs, timestamps, cooldown results, or integrity outcomes.
- Keep user-owned data keyed by `auth.uid()`; clients may only read/write their own rows. For UPDATE policies, pair `USING` and `WITH CHECK` and prevent changing ownership columns.
- Keep admin-only mutations out of ordinary client grants wherever possible. Prefer a trusted server/Edge Function path with managed secrets; if a DB admin predicate remains necessary, keep it in a non-exposed schema, validate its trusted claim source, pin `search_path`, and restrict function EXECUTE grants.
- Enable RLS on every client-reachable table. Use explicit table grants and explicit policies together; RLS does not substitute for GRANT. Default-deny tables with no client use should have no anon/authenticated grants and no client policies.
- Use explicit anonymous/public read access only for fields and operations needed before sign-in. For private/user tables, never equate the Postgres role `authenticated` with a non-anonymous person because this app uses Supabase anonymous sign-in.
- Keep service-only/internal tables (registry staging, security event/state, reset bookkeeping, admin membership) inaccessible to anon/authenticated. Use server-side operations and narrow functions instead.
- Views exposed to the Data API must use `security_invoker = true` on PostgreSQL 15+ unless there is a documented, reviewed reason otherwise. Security-definer functions must be minimal, pinned to a safe search path, explicitly granted only to intended roles, and tested with anonymous and cross-user requests.
- Storage: make only intended public read buckets public. Upload/update/delete must use narrow object-path policies and never rely on a broad authenticated-role grant. Keep secrets out of SQL, Git, client builds, and logs.

### Initial access-policy matrix to implement and test

| Data group | Anonymous / signed-out | Signed-in app session (including anonymous auth) | Server/admin |
|---|---|---|---|
| Published events and active content | Read only if the app genuinely needs pre-login browsing; otherwise require app session | Read active/published rows only | Managed updates |
| Places and event-content mapping | Read active rows only | Read active rows only | Managed updates |
| Public achievements/region/series reference data | Read only required active/public rows | Same | Managed updates |
| Profiles | No direct read of other users; own row only after auth | Own row only; immutable identity key | Account lifecycle server path |
| Collection history/place visits | No access until a valid user session exists | Own rows read-only; insert through validated RPC; no direct update/delete unless product requirements justify it | Validated RPC/service path |
| Preferences/favorites/participations | No access before user session | Own rows only, with owner immutable | Narrow admin/server exceptions only |
| Announcement reads | No access before user session | Own rows only | Managed operations |
| Release policy | Read only minimum fields required by client | Same | Server/admin updates |
| Roadside station import registry, GPS security state/events, reset ledger, admin table | No access | No direct table access | Service role / narrowly granted function |
| Storage | Public read only for approved public assets | Upload only if a feature needs it, under user-owned paths | Managed migration and maintenance |

This is a starting policy design, not yet executable SQL. The final policy set must be reconciled with actual Flutter query paths, anonymous sign-in behavior, server RPC grants, and cross-user negative tests before deployment.

### RLS issues explicitly not to inherit

- Do not copy the existing policy set wholesale. Some public reference tables currently have `authenticated`-only reads, while the event table has a separate `anon` read. Decide intended pre-login behavior per table and make it consistent.
- Existing admin policies call `private.is_admin()`; review its identity source and EXECUTE grants before retaining. A policy that invokes a helper is not safe merely because the helper lives in `private`.
- Do not grant broad table CRUD to `authenticated` and expect RLS alone to make it safe. Separate GRANTs and RLS predicates are both required.
- Do not grant direct INSERT on collection history/visits if the RPC is meant to enforce cooldown and location integrity.
- Do not use user-editable `user_metadata` as an admin claim source. If JWT claims are used, authorization claims must be trusted server-managed app metadata and the stale-token behavior must be considered.
- Do not make extension-owned `spatial_ref_sys` RLS changes as a blanket advisor cleanup. Review the PostGIS extension's supported installation model and actual access surface.
- Supabase's new-project Data API exposure defaults are changing: newly created public tables may not be API-accessible without explicit grants, with enforcement on existing projects scheduled for 2026-10-30. Encode the required grants explicitly rather than relying on project defaults.

### Required security tests before production approval

1. Anonymous requests cannot read user tables, internal registry/security tables, unpublished content, or admin membership.
2. Anonymous-auth users cannot read another user's profiles, visits, preferences, participation, favorites, or history.
3. Direct REST inserts/updates cannot bypass the collection RPC, cooldown, owner identity, or trusted timestamp rules.
4. User A cannot mutate User B's row by changing `user_id` or `id`.
5. Non-admin authenticated users cannot mutate master content or invoke admin maintenance functions.
6. Intended app queries still work under the exact role/grants that production will use.
7. Every security-definer function has a reviewed body, fixed search path, explicit EXECUTE grants, and a tested negative-access case.
8. Storage object policies reject cross-user writes and path traversal, while approved public assets remain readable.
9. Run Supabase security advisors after the new schema is applied; resolve real issues, document justified extension-owned findings, and verify with SQL-level privilege/policy tests.


## Source-side hardening staged on the audit branch

- `supabase/config.toml`: set `auto_expose_new_tables = false` so future public tables do not silently gain Data API access. Disabled the configured seed step because `supabase/seed.sql` was absent; curated master-data seeding will be added separately.
- `supabase/functions/import-roadside-station-registry/index.ts`: removed the fixed import-key literal; reads `ROADSIDESTATION_IMPORT_KEY` from the Edge Function environment, rejects methods other than POST, and no longer returns stack/detail internals in client error bodies.
- `supabase/functions/delete-account/index.ts`: restricts the handler to POST (plus OPTIONS preflight) and no longer returns underlying Auth/delete error details to the caller.
- Added `docs/production-schema-target.md` and `supabase/security/production_rls_audit.sql` to describe the clean model and provide read-only privilege/RLS review queries.

These are source changes staged for review, not deployed runtime changes. The registry importer is still explicitly blocked from production: its delete-and-reinsert sequence is not atomic, and it needs a staging/transactional replacement, secret provisioning, and negative authorization tests. Do not deploy it as-is. The account-deletion function also still needs end-to-end verification against the app's actual call path and cascade/retention behavior.
