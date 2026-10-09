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
- **Unused-index advisor (30 findings):** the production project has only just been bootstrapped and has no meaningful production query history yet. Indexes are retained until workload statistics exist; do not drop them based on zero usage immediately after cutover.

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
