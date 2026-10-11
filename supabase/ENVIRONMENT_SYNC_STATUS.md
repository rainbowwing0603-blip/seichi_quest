# Supabase environment sync status

Last checked: 2026-10-11

## Production status

- Production project `npirfaoxcarfuqjlwgav` is `ACTIVE_HEALTHY` in `ap-northeast-1`.
- PostGIS 3.3.7 is installed in the `gis` schema.
- All 25 non-extension tables in `public` have RLS enabled; none are missing RLS.
- There are 34 policies across `public` and `storage`.
- The five migrations reconstructed from the deployed production database on 2026-10-09 are recorded in production migration history.
- `20261010100000_reconcile_production_security` and the subsequent security/profile changes are reflected in production. On 2026-10-11, seven missing migration-history entries were reconciled only after checking the live schema, RPC definitions, and grants. Three historical compatibility versions were restored as no-op compatibility marker files in source. Production migration history and this branch now both contain 94 versions/files.
- Key RPCs exist and the production nearby-content RPC returned 10 rows in a live read-only smoke test.
- The active app release policy is `latest_build=13`, `minimum_build=11`, `latest_version=1.0.0`; this matches the production release policy currently intended for the app.
- The `delete-account` Edge Function is active with JWT verification enabled. Its handler requires an authenticated user and deletes only that user's account.
- Storage bucket configuration is present for `event-card-images` and `content-media`.
- No production Auth users exist yet, so `private.admin_users` is empty. Do not copy a test-project Auth UUID into production. Once the intended admin signs in or registers in production, add that production user's UUID explicitly if admin content management is needed.
- The `event-card-images` bucket currently has no stored objects. The bucket and public-read policy are configured, but image assets must be uploaded separately if/when approved for production use.

## Migration history reconciliation (2026-10-11)

- Verified the live profile gender column/index, four-argument profile RPC, recommendation implementation in `private`, story-preview server-time RPC grant, and current ranking/admin policy state before reconciling history. The older `20261005231529_story_preview_server_time` version was also recorded as applied after confirming its resulting function and grants are already present.
- Recorded already-reflected migration versions as applied in `supabase_migrations.schema_migrations`; no historical SQL was replayed against production.
- Added no-op compatibility marker files for production-only historical versions `20261010232928` and `20261010234108`. The canonical, effective migrations for clean installs remain `20261011090000` and `20261011093000` respectively.
- Live recheck on 2026-10-11 confirms **94 migration files in `main` and 94 versions applied in production**, with no missing or production-only version IDs. Recheck this parity before any future production migration push.

## Changes applied

- Reconstructed and committed five migrations from 2026-10-09:
  - `20261009010000_secure_event_participation_rpc.sql`
  - `20261009020000_secure_event_preference_rpc.sql`
  - `20261009031000_secure_profile_write_rpc.sql`
  - `20261009032000_atomic_roadside_station_registry_replace.sql`
  - `20261009040000_preserve_place_import_timestamps.sql`
- Added `20261010100000_reconcile_production_security.sql` to reconcile live schema drift.
- Aligned public application RLS policies and function ACLs, including RPC-only writes for profiles, event participations, and event preferences. Explicit authenticated grants required by source migrations are retained.
- Ensured `private.admin_users` and `private.is_admin()` exist; direct client access to the admin table is revoked.
- Ensured Storage bucket configuration exists for `event-card-images` and `content-media`.
- Removed the unused test-only `http` extension. No current database object or source function depended on it.
- User-owned data was not copied or deleted by the reconciliation migration.

## Known environment-specific differences

### PostGIS schema

- Production has PostGIS 3.3.7 in schema `gis`.
- Test has PostGIS 3.3.7 in schema `public`.
- PostGIS is not relocatable in its current state. The migration selects schema-appropriate function definitions so both environments remain functional, but extension-owned metadata objects and their grants are not identical.
- **Do not run `DROP EXTENSION postgis CASCADE` manually.** Supabase Support must perform the supported relocation procedure for the test project if exact extension-schema parity is required.

### Data and Storage objects

- Static reference data digests match for `places`, `contents`, `event_contents`, `roadside_station_registry`, `geo_regions`, `geo_region_prefectures`, and collection-series tables.
- The test project's Jomo Karuta cover URL points at test Storage, while production has no stored event-card image objects. The test-only `テストクエスト` is inactive in production.
- `collection_history` contains 17 rows in test and 0 in production. Do not copy this user-owned data between projects.
- Test Storage contains 45 objects in `event-card-images`; production currently contains 0. File bytes are not copied by SQL migrations. Upload approved production assets separately.
- Test has one row in `private.admin_users`, but production has no Auth users yet. Auth user UUIDs are project-specific; do not copy the test UUID.

## Remaining work

- **Production database schema/security baseline and migration history are reconciled (94 source files / 94 production versions as of 2026-10-11).**
- If the test project must exactly match production, contact Supabase Support to move test PostGIS from `public` to `gis`; then repair/apply test migration history and rerun the environment comparison.
- After a production user account exists, register the intended production admin UUID if the app's admin content-management features are to be used.
- Upload production-approved event-card and content-media assets when they are ready.
- Complete an end-to-end smoke test through the production app for sign-in, nearby content, stamp collection, story/rewarded-ad unlock, and image display. Database RPC and schema checks alone do not prove every mobile UI flow.


## Live production audit follow-up (2026-10-11)

Read-only verification against project `npirfaoxcarfuqjlwgav`:

- Project status is `ACTIVE_HEALTHY`; Postgres 17.11.
- All 94 migration versions in the production database match the 94 migration files in `main`; no missing or extra versions.
- All 25 public tables have RLS enabled; no public table with RLS disabled was found.
- Ranking RPC `public.get_public_ranking(uuid, integer)` is `SECURITY INVOKER`; effective EXECUTE is denied to `anon` and allowed to `authenticated` and `service_role`.
- The checked app-facing RPC wrappers are `SECURITY INVOKER`, with `anon` execution denied. Remaining public `SECURITY DEFINER` routines are internal trigger/helper functions or the server-only roadside-registry replacement; effective EXECUTE is denied to `anon` and `authenticated` and retained for `service_role` where required.
- `private` schema USAGE is denied to `anon`; internal operational tables have explicit deny policies for API roles. Live admin write policies use the `is_anonymous` JWT claim plus `private.is_admin()`, both wrapped in scalar subqueries.
- Security Advisor currently reports the `auth_allow_anonymous_sign_ins` warning for user-owned or published-read policies. This app intentionally uses Supabase anonymous sign-in; these users have the `authenticated` Postgres role. Do not remove these policies wholesale. Permanent-admin-only mutations are separately guarded against anonymous sessions. Review future policy changes against this intended access model.
- Performance Advisor currently reports four `auth_rls_initplan` warnings for the content-block admin policies and event theme update policy. The live policy expressions already wrap `auth.jwt()` and `private.is_admin()` in scalar subqueries as recommended by Supabase. Do not add duplicate migrations based on the warning alone; next step is to verify whether the advisor result is stale or a real plan issue with measured EXPLAIN/ANALYZE in a safe environment.
- Performance Advisor also reports 14 unused indexes. Do not drop them based on a fresh/low-traffic production project's short usage window; reassess after representative workload and query-statistics history.
- The active production Android release policy remains `latest_build=13`, `minimum_build=11`, `latest_version=1.0.0`. This is the production app's policy and is intentionally not copied from the closed-test build number 20.
- Production has no Auth users yet. The admin allowlist remains unpopulated until the intended permanent production user exists; do not copy a test-project UUID. Production-approved event-card assets also remain absent from Storage, so image display requires an explicit asset upload before that part of end-to-end validation can pass.
- No production database mutation was made during this audit.
