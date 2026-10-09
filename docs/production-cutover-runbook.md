# Production schema cutover runbook

**Target project:** `npirfaoxcarfuqjlwgav` (`seichi-quest-production`)

## Critical warning

Do **not** run `supabase db push` against the empty production project before the clean bootstrap. The repository contains historical migrations that assume an older schema and may recreate or depend on the retired `public.seichi` model. The production bootstrap candidate is the reviewed current-state baseline; it must be applied first, then the pre-baseline migration history must be reconciled before normal pushes.

The scripts are intentionally guarded and default to dry-run. Neither script contains a database password or publishable key.

## One-time cutover

1. Merge/review the production-bootstrap PR and update the local checkout to that commit.
2. Confirm the target project ref in the Supabase Dashboard is `npirfaoxcarfuqjlwgav`. The current production project was confirmed empty during preparation.
3. Link the CLI to production:
   ```powershell
   supabase link --project-ref npirfaoxcarfuqjlwgav
   ```
4. Set `SUPABASE_DB_URL` in the current PowerShell session to the **direct database connection URI** for that production project. Do not commit it, put it in a script, or paste it into chat.
5. Run the dry-run, inspect the target and file counts, then apply the schema and all curated master data in one PostgreSQL transaction:
   ```powershell
   .\scripts\bootstrap-production-schema.ps1
   .\scripts\bootstrap-production-schema.ps1 -Apply
   ```
   The script refuses to run if public/private/GIS application schemas or migration history are already populated, or if the connection URI does not identify the expected project. It imports 25 application tables, 26 reviewed public RLS policies, and 10,320 master/reference rows. It verifies table/policy counts, RLS, the automatic-RLS event trigger, the absence of `public.seichi`, event-state write grants, and each curated table's row count before committing.
6. Only after the bootstrap transaction succeeds, mark all repository migrations older than `20261009010000` as already represented by the baseline:
   ```powershell
   .\scripts\repair-production-migration-history.ps1
   .\scripts\repair-production-migration-history.ps1 -Apply
   ```
   The repair script verifies the linked project ref and queries the database to ensure the full bootstrap actually succeeded before it can mark any version as applied. Review its version list during the dry-run.
7. Apply the two post-baseline RPC migrations and verify history alignment:
   ```powershell
   supabase db push
   supabase migration list
   ```
   Those RPC migrations are idempotent and are also included in the baseline. The push records the current source migration history without replaying the old bootstrap chain.

## Still separate from database cutover

- **Auth:** confirm anonymous sign-in is enabled for production, because the Flutter client uses anonymous sign-in when there is no session. This must be checked in Supabase Auth settings.
- **Storage:** no bucket or object bytes are copied by the database seed. Review bucket visibility and policies independently. The one closed-test project URL for the Jomo Karuta cover is deliberately nulled in the seed. Official artwork permission is not yet confirmed, so do not copy those objects until rights and hashes are reviewed.
- **Edge Functions:** do not deploy the old roadside-station importer as-is. The old deployed function may still contain its previous maintenance key even though the repository source now reads `ROADSIDESTATION_IMPORT_KEY`. Rotate the key in Supabase Secrets, then deploy only after replacing its non-atomic delete/reinsert implementation with staging and atomic promotion. The available connection does not expose secret-management/deploy actions.
- **iOS/Android production release:** the production app build must use the production URL and publishable key. This database cutover does not release an app or alter Google Play tracks.
- **User data:** Auth users, profiles, visits, collection history, event preferences/participation, favorites, announcement reads, location-security records, reset history, and admin membership are intentionally not copied.

## Recovery

The bootstrap schema and all 47 seed SQL files are assembled into a temporary local SQL file and executed as one explicit transaction. Any SQL error should leave the transaction rolled back. Before retrying, check that public/private/GIS application schemas remain empty and that the production migration history has no entries. If the transaction succeeded, do not rerun it: the migration-history repair script is the next step. If migration repair is interrupted, inspect `supabase migration list` and the remote migration history before retrying.


## Production release policy gate

The baseline creates `app_release_policies` but deliberately leaves it empty. Before distributing a production build, insert a reviewed policy row for each platform with the intended current build, minimum supported build, version label, store URL, and update message. Do not copy the closed-test values automatically. The app fails open if no active policy row exists, but then it cannot enforce a minimum version.
