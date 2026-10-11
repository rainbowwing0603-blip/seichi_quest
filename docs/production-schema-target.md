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

The performance advisor currently reports 16 unused indexes. This is a newly initialized production database, so the advisor has little workload history. Do not drop indexes solely from this initial unused-index report; compare each index against foreign keys, uniqueness constraints, query plans, and real workload before any removal.

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
5. Run `supabase db push` to apply/record the five post-baseline migrations: participation RPC, preference RPC, profile-write RPC, atomic registry replacement, and place timestamp preservation.
6. Verify `supabase migration list`, re-run the read-only RLS audit, and run the data-count/FK/spatial checks. Never rerun the one-time schema bootstrap.

This local CLI operation cannot be completed by the current database connector. Do not manually create or edit migration-history rows through ad hoc SQL.

## Remaining production release gates

- Confirm production Auth anonymous sign-in in the dashboard. The Flutter app creates an anonymous session when no session exists; local `supabase/config.toml` does not prove the hosted setting.
- Review Storage bucket policies and assets. No Storage objects were copied.
- Rotate the previously deployed closed-test roadside-import secret and set `ROADSIDESTATION_IMPORT_KEY` as a Supabase secret before deploying the reviewed importer. Source changes do not rotate a deployed secret or erase old Git history.
- The deployed closed-test source for `enrich-roadside-station-gps` and `reconcile-roadside-station-gps` has been recovered into Git and hardened: fixed keys removed, separate environment secrets required, POST-only handling, coordinate bounds validation, and safer metadata preservation. Neither is deployed to production; set/rotate secrets and run the new Deno CI checks before any deployment.
- Production `delete-account` Edge Function v2 is deployed with gateway JWT verification enabled, POST/OPTIONS CORS methods, and the reviewed source from `supabase/functions/delete-account/`. Before release, verify the authenticated deletion path and database/Auth cascade behavior with a disposable test user; no production user exists to test against.
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


The production Supabase security advisor reports five `rls_enabled_no_policy` INFO findings for server-only tables with no direct client grants, one anonymous SECURITY DEFINER warning for `get_public_ranking` (intentionally public ranking), and authenticated SECURITY DEFINER warnings for the reviewed RPC API. The live privilege matrix confirms that anon cannot read profiles/history/places or call the registry replacement RPC, authenticated cannot directly write profile/history/participation/preference tables, and only `service_role` can call `replace_roadside_station_registry`. Keep the fixed `search_path` and explicit grants as release gates.


## Live production revalidation (2026-10-09, after CI fixes)

Re-queried the live production project read-only after the source-check repair. Results:

- 25 public application tables, all with RLS; 24 public policies.
- 13/13 curated master-data table counts match the manifest (10,320 total rows).
- All 1,713 places have geography; 0 duplicate \`(prefecture, official_name)\` registry keys.
- 0 cross-table orphan rows in the verifier checks and 0 closed-test project URLs in event/content image fields.
- All user-specific tables remain empty, including profiles, visits, collection history, event preferences/participation/favorites, announcement reads, location-security state/events, and reset ledger. \`announcements\` and \`app_release_policies\` also remain empty by design.
- 0 app-owned SECURITY DEFINER functions without a fixed search path; 0 unexpected anon-executable app functions; no direct client INSERT/UPDATE grants on participation, preferences, or profiles. The four user-facing state/profile RPCs are executable by authenticated.
- PostGIS is installed in the non-exposed \`gis\` schema; \`public.seichi\` is absent.
- Supabase migration history is still uninitialized: \`supabase_migrations.schema_migrations\` does not exist and the Supabase migration listing is empty. Do not run \`supabase db push\` until the guarded history-repair step is completed from the reviewed repository checkout.

The security-source CI failure was traced to two concrete type-check setup issues, not application behavior: Deno was not auto-installing the importer's npm dependencies, and standalone type-checking lacked the Supabase runtime's \`EdgeRuntime.waitUntil\` declaration. The workflow now uses \`deno check --node-modules-dir=auto\`; the two maintenance functions declare the provided runtime type. The latest Supabase Security Source Check completed successfully.


## Advisor review and migration-history edge case

The production Supabase advisors were reviewed after the live cutover:

- **RLS enabled with no policy (5 tables): intentional default-deny.** \`event_collection_resets\`, \`location_security_events\`, \`location_security_states\`, \`place_visits\`, and \`roadside_station_registry\` have no direct \`anon\`/\`authenticated\` table privileges for SELECT or mutation. Access is through narrowly scoped RPCs or service-role maintenance only.
- **SECURITY DEFINER callable by anon:** only \`get_public_ranking\`, intentionally public. It returns chosen display name/avatar key and event ranking counts, not account IDs or location data. It has a pinned empty search path and caps results at 100.
- **SECURITY DEFINER callable by authenticated (12 advisor findings):** reviewed as intended RPC endpoints. All have a fixed empty search path and derive user-specific access from \`auth.uid()\`; the registry replacement RPC is service-role-only. The only anon-executable app function is the public-ranking endpoint.
- **Unused-index advisor (16 findings):** the production project has only just been bootstrapped and has no meaningful production query history yet. Indexes are retained until workload statistics exist; do not drop them based on zero usage immediately after cutover.

A catalog-driven check examined all **34 foreign-key constraints** from public application tables to public/Auth tables and found **0 violations**. The migration-history repair script was also corrected to include both historical 8-digit migration filenames as well as the newer 14-digit versions; otherwise those two legacy versions could have been omitted from the repair list and replayed by \`supabase db push\`.


## Additional live production checks (2026-10-09)

A rollback-only smoke test inserted two synthetic anonymous Auth users inside a transaction, then exercised `save_my_profile`, `set_current_event_preference`, and `ensure_event_participation` as the authenticated role. The user could read their own profile/preference, could not read the other synthetic user's profile, and could not directly UPDATE `profiles`, `user_event_preferences`, or `user_event_participations`. Attempting to leave the currently selected event was rejected with the expected validation error. The entire transaction was rolled back; a separate post-check confirmed **0 Auth users, 0 profiles, 0 participation rows, and 0 preference rows** remain.

The refreshed read-only `supabase/seed/production_master_data/VERIFY.sql` completed without SQL errors. Live inventory reports 0 app tables without RLS, 0 app-owned SECURITY DEFINER functions without a fixed search path, and 0 direct client write grants on the three RPC-protected tables. Production Storage currently has **0 buckets and 0 objects**, and both Android/iOS release-policy row counts are 0. These are intentional pre-release gates, not evidence that Storage-backed artwork or store-update enforcement is ready.

The remaining hosted setting that cannot be verified through the available project/database API is **Auth anonymous sign-in**. Confirm it in the Supabase Dashboard before releasing the Flutter build, because the app creates an anonymous session when no session exists.


A second rollback-only production smoke test exercised the client-facing read RPCs under the authenticated role against the seeded Jomo Karuta event. Results: `get_event_contents_page` returned 20 rows, `get_event_contents_nearby` returned 20 rows for a Gunma coordinate, `get_event_geo_scopes` returned 3 rows, and progress, regional-map-progress, and social-stats RPCs each returned their expected summary row. The synthetic Auth user and profile were rolled back; a post-check again confirmed zero Auth users, profiles, and preferences.


The main stamp-collection write path was also exercised in a rollback-only production transaction. A synthetic anonymous user called `record_place_visit_and_collect` at the exact coordinates of an active Jomo Karuta place; it returned one collection result and created one visit plus one collection-history row inside the transaction. The test then rolled back, and a privileged post-check confirmed that Auth users, visits, and collection history are all still zero. Direct client SELECT on `place_visits` remains intentionally denied; verification of those rows was done only after resetting the role.


The production `delete-account` Edge Function is active at version 2 with gateway JWT verification enabled. Its deployed `index.ts` was compared byte-for-byte (after trimming surrounding whitespace) with the reviewed GitHub source and matched exactly. The Deno CI workflow now type-checks the registry importer, GPS enrichment, GPS reconciliation, and account deletion functions; run 7 passed all four checks.


## Atomic registry replacement regression check (2026-10-09)

Executed the production registry replacement RPC as `service_role` inside an explicit rollback-only transaction using the current 1,234-row registry as the payload. The RPC completed successfully; post-call checks confirmed 1,234 total rows, 1,231 place links, 1,231 verified coordinate candidates, 33 operationally-open rows, and 3 opening-pending rows. The transaction was rolled back, so the live registry was not changed. This validates the RPC's payload contract and its preservation of place/GPS/status fields without requiring a destructive import.


## Supabase Advisor findings reviewed (2026-10-09)

The production Security Advisor reports five `rls_enabled_no_policy` informational findings. These are intentional deny-by-default tables, not missing client access rules:

- `place_visits`, `location_security_states`, and `location_security_events` are server-managed through narrowly scoped RPCs; client roles have no direct table grants.
- `event_collection_resets` is an internal reset ledger and has no direct client grants.
- `roadside_station_registry` is maintenance data; its full replacement path is the service-role-only `replace_roadside_station_registry(jsonb)` RPC.

The Advisor also reports the public `get_public_ranking(uuid, integer)` SECURITY DEFINER function. This is the sole app-owned function executable by `anon`; it is intentional for public rankings, has a fixed empty `search_path`, limits results to at most 100, and returns only display name, avatar key, ranking/counts, and the caller-relative `is_me` flag. The other client-callable SECURITY DEFINER functions are authenticated-only RPCs used for user-scoped reads or validated writes. Live inventory confirms every app-owned SECURITY DEFINER function has a fixed `search_path`, and no unexpected anonymous EXECUTE grants exist.

Performance Advisor unused-index notices are expected at this point because the new production project has only just been seeded and has no meaningful production query history. Do not remove indexes on that basis; reassess after representative traffic and query-plan evidence exist.


### SQL syntax/constraint rehearsal update (2026-10-09)

The remaining master-data SQL files have now each been executed individually inside a rollback-only transaction against the closed-test schema. The following groups returned successfully with no SQL error: all 11 content batches, all 11 event-content batches, achievements/regions/series, content blocks and event mappings, all 5 collection-series/place batches, collection-series/region mappings, and all 5 roadside-station-registry batches. Earlier, all seven place batches and the event seed were also syntax-tested. These individual tests prove SQL parses and can execute in the existing schema, but **do not replace an empty-production full-order rehearsal** because the closed-test DB already contains the target rows and `ON CONFLICT DO NOTHING` can skip existing records.


## Production read-only revalidation (2026-10-09, after seed SQL checks)

A fresh read-only audit against production returned the expected counts for all 13 curated master-data tables (10,320 rows total), **34 foreign-key constraints with 0 orphan rows**, 25 application tables with RLS enabled, and 24 public policies. Across the exported master data there are 0 references to the closed-test Supabase project URL. App-owned `SECURITY DEFINER` functions have 0 missing fixed search paths; no unexpected anon-executable app definer functions were found. Auth users, profiles, place visits, collection history, event preferences and participation remain empty. The guarded migration-history repair script's exact read-only preflight returned `READY`; the migration history table itself is still absent, so the CLI repair step remains outstanding.

The invalid-payload negative test for `replace_roadside_station_registry('[]'::jsonb)` correctly raised the expected validation exception before writes; the registry remained at 1,234 rows. All curated seed SQL files have also passed individual rollback-only syntax/constraint execution checks. These checks did not mutate production data.


The profile-write RPC was also retested on the closed-test schema inside a rollback-only transaction after aligning the display-name limit to the table's 30-character constraint. A 31-character name was rejected with the intended validation error; a 30-character name with an allowed age-group/avatar pair was accepted inside the transaction. Authenticated still has no direct profile UPDATE privilege and can execute the RPC. No profile change persisted.


## Master-data integrity check (closed-test source, read-only)

A fresh read-only integrity query against the live source DB returned:

- 51 events, 1,713 places, 2,742 contents, 2,721 event-content mappings, 336 content blocks, and 1,234 roadside-station registry rows.
- 0 places missing geography; 0 latitude/longitude values outside valid ranges.
- 0 duplicate non-null `contents.content_key` groups.
- 0 orphan rows for event-content → event/content/place, content-block → content, event-achievement → event/achievement, collection-series-place → series/place, collection-series-region → series/region, geo-region-prefecture → region, or registry → place.

The individual 47 seed SQL files were also executed in rollback-only transactions for SQL parse/execution checks. Because they use `ON CONFLICT DO NOTHING` and were checked against a DB that already contains the source records, this is **not** a clean-database full-import rehearsal. A complete all-rows import into an empty schema still needs one end-to-end transactional rehearsal before production approval.


A further rollback-only negative test confirmed `leave_event_participation` rejects attempts to leave the currently selected event with the intended validation error, preserves the current preference, and does so while direct authenticated UPDATE privileges on both event participation and preference tables remain revoked.


Profile RPC negative tests also rejected an unsupported age group and an unsupported avatar key with the expected validation errors. Both tests were rollback-only; the closed-test profile data was not changed.


Production geospatial smoke tests passed against real master data: `get_event_contents_nearby` returned the expected colocated record at 0 m distance, and `get_event_contents_in_bounds` returned the record inside the requested coordinate box. All 1,713 places have non-null coordinates; PostGIS 3.3.7 is installed in the `gis` schema.


Geospatial verification also returned 1,713/1,713 places as non-empty `ST_Point` geography values with SRID 4326; 0 latitude/longitude versus geography mismatches; 0 invalid registry candidate coordinate pairs; and 1,231 registry-to-place links. This reduces risk in the EWKT seed conversion, but does not replace a full empty-schema import rehearsal.


Asset-path reconciliation: the 88 distinct `assets/...` paths referenced by `contents.image_url` and `content_blocks.media_path` were compared with the Flutter repository tree on `feature/android-next-release`. **0 missing paths** were found. These are bundled app assets and do not need to be copied to Supabase Storage.


Production release gate inventory is currently empty by design: 0 Storage buckets, 0 Storage objects, 0 Auth users, and 0 rows in `app_release_policies` (no active Android/iOS release policy). This is appropriate for the isolated schema/data bootstrap, but the app must not be treated as release-ready until the actual media-storage requirement, artwork rights, anonymous sign-in setting, and release-policy values are explicitly resolved.


## 2026-10-09 incremental validation update

To avoid oversized requests, seed SQL execution checks were run one file at a time inside explicit rollback-only transactions. The event, place, content, achievement, region, collection-series, event-content, content-block, event-achievement, prefecture mapping, collection-series-place/region, and roadside-registry seed files returned successful SQL execution; no rows were persisted by these checks. This is syntax/constraint coverage against an already-populated schema, not a clean empty-database import rehearsal.

Read-only live production integrity checks were then run in small table groups:
- Events 51, places 1,713, contents 2,742; 0 closed-test project URLs in these three tables and 0 places missing geography.
- Event-content mappings 2,721, content blocks 336, achievements 18, event-achievement mappings 18; 0 orphan event/content/place/block/achievement relationships.
- Geo regions 57, prefecture mappings 141, collection series 1; 0 orphan region mappings, duplicate region codes, or duplicate region/prefecture pairs.
- Collection-series place mappings 1,231, region mappings 57, roadside-station registry 1,234; 0 orphan series/place/region/registry-place relationships, duplicate (prefecture, official_name) keys, or invalid registry status values.

Deployed Edge Function source was compared byte-for-byte with the GitHub branch: production delete-account v2 and closed-test import-roadside-station-registry v12, enrich-roadside-station-gps v16, reconcile-roadside-station-gps v2, and verify-roadside-station-gsi v2 all matched their checked-in index.ts. Gateway JWT verification is enabled on all four closed-test maintenance functions and production delete-account.

The production Supabase migration history is still empty. The guarded PowerShell repair script requires the production-linked local checkout, Supabase CLI, psql, and SUPABASE_DB_URL; do not substitute manual SQL inserts into migration history. That CLI dry-run/repair sequence remains a separate cutover gate.


## Incremental post-load reconciliation (3 tables per batch, 2026-10-09)

The live data was checked in small batches instead of one large multi-table request:

1. `events`, `places`, `contents`: counts and normalized row hashes match the closed-test source, excluding the intentionally nulled closed-test cover URL and the derived geography representation. All 1,713 geography values are populated and 0 exceed a 1 m distance from their latitude/longitude coordinates.
2. `event_contents`, `content_blocks`, `achievements`: counts match; all event/content/place references resolve. Event-content and achievement hashes match exactly. Content-block non-metadata fields match; all 336 `metadata` values are structurally equal after canonical JSON comparison.
3. `event_achievements`, `geo_regions`, `geo_region_prefectures`: source counts and hashes match; no orphan event/achievement/region references.
4. `collection_series`, `collection_series_places`, `collection_series_regions`: source counts and hashes match; no orphan series/place/region references.
5. `roadside_station_registry`: all 1,234 rows match the source hash and all official names are nonblank. `announcements` and `app_release_policies` remain intentionally empty; user-specific tables are also empty.

The import trigger on `places` had set all 1,713 `updated_at` values to the import timestamp. These timestamps were restored from the source master data without changing place content or coordinates. A fresh source/production timestamp hash now matches exactly. Do not rerun the one-time schema bootstrap or bulk seed importer.


A fresh advisor query on 2026-10-09 returned 16 `unused_index` findings (the count can vary as advisor snapshots and workload statistics change). This replaces older notes in this document that reported 30/31; indexes remain in place until there is representative production traffic and query-plan evidence.


Migration-history repair inventory on the current branch: **80 SQL migration files total**, comprising **75 legacy/pre-baseline versions** to mark applied and **5 post-baseline migrations** to apply with `supabase db push`. The five post-baseline files are `20261009010000_secure_event_participation_rpc.sql`, `20261009020000_secure_event_preference_rpc.sql`, `20261009031000_secure_profile_write_rpc.sql`, `20261009032000_atomic_roadside_station_registry_replace.sql`, and `20261009040000_preserve_place_import_timestamps.sql`. The live production schema already contains the corresponding reviewed objects, so the local CLI sequence must start with the script's dry-run and exact preflight; never manually insert migration history rows or run an unguarded push.


The clean bootstrap's place trigger was corrected after the live reconciliation: `updated_at` is now refreshed only on UPDATE, while INSERT preserves an explicitly imported source timestamp (and still uses the column default for ordinary new rows). The live production timestamps have already been restored and their hash matches the source. The new migration is pending the documented CLI migration-history repair and `supabase db push` sequence; do not use the schema bootstrap to apply it.
