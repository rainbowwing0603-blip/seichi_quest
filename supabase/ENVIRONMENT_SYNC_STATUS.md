# Supabase environment sync status

Last checked: 2026-10-10

## Production status

- Production project `npirfaoxcarfuqjlwgav` is `ACTIVE_HEALTHY` in `ap-northeast-1`.
- PostGIS 3.3.7 is installed in the `gis` schema.
- All 25 non-extension tables in `public` have RLS enabled; none are missing RLS.
- There are 34 policies across `public` and `storage`.
- The five migrations reconstructed from the deployed production database on 2026-10-09 are recorded in production migration history.
- `20261010100000_reconcile_production_security` was already applied directly and its migration-history entry has now been recorded after verifying the migration's changes were present. Production history now contains 81 entries, matching the 81 source migration files on this branch.
- Key RPCs exist and the production nearby-content RPC returned 10 rows in a live read-only smoke test.
- The active app release policy is `latest_build=13`, `minimum_build=11`, `latest_version=1.0.0`; this matches the production release policy currently intended for the app.
- The `delete-account` Edge Function is active with JWT verification enabled. Its handler requires an authenticated user and deletes only that user's account.
- Storage bucket configuration is present for `event-card-images` and `content-media`.
- No production Auth users exist yet, so `private.admin_users` is empty. Do not copy a test-project Auth UUID into production. Once the intended admin signs in or registers in production, add that production user's UUID explicitly if admin content management is needed.
- The `event-card-images` bucket currently has no stored objects. The bucket and public-read policy are configured, but image assets must be uploaded separately if/when approved for production use.

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

- **Production database schema/security baseline and migration history are reconciled.**
- If the test project must exactly match production, contact Supabase Support to move test PostGIS from `public` to `gis`; then repair/apply test migration history and rerun the environment comparison.
- After a production user account exists, register the intended production admin UUID if the app's admin content-management features are to be used.
- Upload production-approved event-card and content-media assets when they are ready.
- Complete an end-to-end smoke test through the production app for sign-in, nearby content, stamp collection, story/rewarded-ad unlock, and image display. Database RPC and schema checks alone do not prove every mobile UI flow.
