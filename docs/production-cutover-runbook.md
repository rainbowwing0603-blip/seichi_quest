# Production schema cutover runbook

**Target project:** `npirfaoxcarfuqjlwgav` (`seichi-quest-production`)

## Live status, checked 2026-10-09

The clean production schema and all 10,320 curated master/reference rows have now been applied and validated. The live DB has 25 application tables, 24 reviewed RLS policies, RLS on every application table, no `public.seichi`, no test-project Storage URLs in master data, and zero user-specific rows copied. All expected table counts, spatial lookup, event-content foreign-key joins, and atomic registry RPC grants were verified.

**Do not run `scripts/bootstrap-production-schema.ps1 -Apply` again.** It is a one-time script that correctly refuses to run when application tables already exist. The next database step is migration-history repair using the guarded script below, followed by `supabase db push`. The migration history currently has no recorded migrations. Auth anonymous sign-in, Storage policies/assets, deployed Edge Function secret rotation, and production release-policy setup remain separate pre-release gates.

## Critical warning

Do **not** run `supabase db push` against the empty production project before the clean bootstrap. The repository contains historical migrations that assume an older schema and may recreate or depend on the retired `public.seichi` model. The production bootstrap candidate is the reviewed current-state baseline; it must be applied first, then the pre-baseline migration history must be reconciled before normal pushes.

The scripts are intentionally guarded and default to dry-run. Neither script contains a database password or publishable key.

## One-time cutover (bootstrap steps already completed)

1. Merge/review the production-bootstrap PR and update the local checkout to that commit. The schema/data bootstrap portion is already complete; use the remaining steps for migration-history reconciliation only.
2. Confirm the target project ref in the Supabase Dashboard is `npirfaoxcarfuqjlwgav`. The schema and master data are now present; do not assume the project is empty.
3. Link the CLI to production:
   ```powershell
   supabase link --project-ref npirfaoxcarfuqjlwgav
   ```
4. Set `SUPABASE_DB_URL` in the current PowerShell session to the **direct database connection URI** for that production project. Do not commit it, put it in a script, or paste it into chat.
5. **Historical step, already completed. Do not rerun.** The guarded bootstrap script was prepared for the original empty-project state and will refuse against the live populated schema.
   ```powershell
   .\scripts\bootstrap-production-schema.ps1
   .\scripts\bootstrap-production-schema.ps1 -Apply
   ```
   The script refuses to run if public/private/GIS application schemas or migration history are already populated, or if the connection URI does not identify the expected project. It imports 25 application tables, 24 reviewed public RLS policies, and 10,320 master/reference rows. It verifies table/policy counts, RLS, the automatic-RLS event trigger, the absence of `public.seichi`, event-state write grants, and each curated table's row count before committing.
6. Only after the bootstrap transaction succeeds, mark all repository migrations older than `20261009010000` as already represented by the baseline:
   ```powershell
   .\scripts\repair-production-migration-history.ps1
   .\scripts\repair-production-migration-history.ps1 -Apply
   ```
   The repair script verifies the linked project ref and queries the database to ensure the full bootstrap actually succeeded before it can mark any version as applied. Review its version list during the dry-run.
7. Apply the five post-baseline migrations (participation RPC, preference RPC, profile-write RPC, atomic registry replacement, and place timestamp preservation) and verify history alignment:
   ```powershell
   supabase db push
   supabase migration list
   ```
   These migrations are idempotent and their current definitions are also represented in the clean baseline. The place trigger preserves supplied source timestamps on INSERT while still refreshing `updated_at` on content UPDATE. The push records the current source migration history without replaying the old bootstrap chain.

## Still separate from database cutover

- **Auth:** confirm anonymous sign-in is enabled for production, because the Flutter client uses anonymous sign-in when there is no session. This must be checked in Supabase Auth settings.
- **Storage:** no bucket or object bytes are copied by the database seed. Review bucket visibility and policies independently. The one closed-test project URL for the Jomo Karuta cover is deliberately nulled in the seed. Official artwork permission is not yet confirmed, so do not copy those objects until rights and hashes are reviewed.
- **Edge Functions:** do not deploy the old roadside-station importer as-is. The old deployed function may still contain its previous maintenance key even though the repository source now reads `ROADSIDESTATION_IMPORT_KEY`. The repository now replaces the non-atomic delete/reinsert with `replace_roadside_station_registry(jsonb)`: it validates and stages all 1,234 rows, preserves matched place links/GPS enrichment and operational statuses, then upserts and removes stale rows atomically. The RPC is executable only by `service_role`. The closed-test functions were redeployed to use fresh V2 secret names with gateway JWT verification: importer v12, GPS enrichment v16, and GPS reconciliation v2. The previous hardcoded keys are no longer accepted by the active source. Configure independently generated `ROADSIDESTATION_IMPORT_KEY_V2`, `ROADSIDESTATION_GPS_ENRICH_KEY_V2`, and `ROADSIDESTATION_GPS_RECONCILE_KEY_V2` values in Supabase Secrets before using maintenance operations; until then, the functions fail closed. These maintenance functions remain undeployed in production. The connector can deploy Edge Functions but cannot create/rotate secrets. The production `delete-account` function is deployed as version 2 with gateway JWT verification enabled and explicit POST/OPTIONS CORS methods; verify its authenticated delete/cascade path with a disposable test user before release. The GPS enrichment and reconciliation source has now been recovered and reviewed. Do not deploy any maintenance function to production until the V2 secrets are configured, missing-secret/invalid-key/non-POST/dry-run behavior is validated in the closed-test project, and a production maintenance run is explicitly approved.
- **iOS/Android production release:** the production app build must use the production URL and publishable key. This database cutover does not release an app or alter Google Play tracks.
- **User data:** Auth users, profiles, visits, collection history, event preferences/participation, favorites, announcement reads, location-security records, reset history, and admin membership are intentionally not copied.

## Recovery

The bootstrap schema and all 47 seed SQL files are assembled into a temporary local SQL file and executed as one explicit transaction. Any SQL error should leave the transaction rolled back. Before retrying, check that public/private/GIS application schemas remain empty and that the production migration history has no entries. If the transaction succeeded, do not rerun it: the migration-history repair script is the next step. If migration repair is interrupted, inspect `supabase migration list` and the remote migration history before retrying.


## Production release policy gate

The baseline creates `app_release_policies` but deliberately leaves it empty. Before distributing a production build, insert a reviewed policy row for each platform with the intended current build, minimum supported build, version label, store URL, and update message. Do not copy the closed-test values automatically. The app fails open if no active policy row exists, but then it cannot enforce a minimum version.
