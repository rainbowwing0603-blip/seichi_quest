# Supabase environment sync status

Last checked: 2026-10-10

## Changes applied

- Reconstructed and committed the five production migrations from 2026-10-09:
  - `20261009010000_secure_event_participation_rpc.sql`
  - `20261009020000_secure_event_preference_rpc.sql`
  - `20261009031000_secure_profile_write_rpc.sql`
  - `20261009032000_atomic_roadside_station_registry_replace.sql`
  - `20261009040000_preserve_place_import_timestamps.sql`
- Added `20261010100000_reconcile_production_security.sql` to reconcile the live drift.
- Applied the SQL directly to both existing projects. These direct SQL executions do **not** add migration-history rows; use `supabase db push` after pulling this branch to reconcile the histories.
- Public application tables: 25 non-extension tables, all with RLS enabled in both projects.
- Public + Storage RLS policies: 34 in each project, with matching definitions.
- Application function ACLs now match, including RPC-only writes for profiles, event participations, and event preferences. Authenticated grants explicitly required by source migrations are retained.
- Storage bucket configuration is now present in both projects:
  - `event-card-images`
  - `content-media`
- Added `private.admin_users` and `private.is_admin()` to both projects. The table remains RLS-enabled and is not directly writable by client roles.
- Removed the unused test-only `http` extension. No current database object or source function depended on it.

## Known environment-specific differences

### PostGIS schema

- Production has PostGIS 3.3.7 in schema `gis`.
- Test has PostGIS 3.3.7 in schema `public`.
- PostGIS is not relocatable in its current state. The migration selects schema-appropriate function definitions so both environments remain functional, but extension-owned metadata objects and their grants are not identical.
- **Do not run `DROP EXTENSION postgis CASCADE` manually.** Supabase's documented route for moving a non-relocatable PostGIS extension is to contact Supabase Support and have them perform the supported relocation procedure. The desired test target is schema `gis`, matching production.
- After Support completes the relocation, run `supabase db push` again so the schema-aware reconciliation migration installs the `gis)-qualified function bodies.

### Data and Storage objects

- Static reference data digests match for `places`, `contents`, `event_contents`, `roadside_station_registry`, `geo_regions`, `geo_region_prefectures`, and the collection-series tables.
- The `events` rows have intentional/environment-specific differences: the test project's Jomo Karuta cover URL points at test Storage, and `テストクエスト` is active only in test.
- `collection_history` contains 17 rows in test and 0 in production. Do not copy this user-owned data between projects.
- Test Storage contains 45 objects in `event-card-images`; production Storage currently contains no objects. The bucket configuration is aligned, but file bytes are not copied by SQL migrations. Copy or re-upload assets separately if production needs them.
- `private.admin_users` has one row in test and none in production. Auth user UUIDs are project-specific; do not copy the test UUID. Add the intended production admin only after signing in to production and identifying that project's user UUID.

## Migration history still to reconcile

- GitHub branch now contains 81 SQL migration files.
- Production migration history currently contains 80 entries; the new `20261010100000` migration was applied directly but is not yet recorded in migration history.
- Test migration history currently contains 78 entries. The five 2026-10-09 migrations were applied directly but are not yet recorded in history. Test also retains three older Codemagic bridge history entries that are absent from the source tree because the bridge was retired.
- Once the PostGIS support step is complete, pull this branch and run `supabase db push` against test first, then production. The migrations are written to be repeatable; this records the missing history entries and re-applies the reconciliation in the correct PostGIS schema.
