# Production master-data seed

This folder contains a curated export of **master/reference data only** from the closed-test Supabase project, captured 2026-10-09. It intentionally excludes Auth users, profiles, collection history, visits, preferences, favorites, participation, announcement reads, location-security state/events, reset history, and admin membership.

## Apply order

Run the SQL files in lexicographic filename order **only after** the reviewed production schema candidate has been applied to an empty production database. Do not run this seed on the populated closed-test database. The inserts use `ON CONFLICT DO NOTHING` so an interrupted import can be resumed, but the target should be empty for the first import.

1. Events
2. Places
3. Contents
4. Achievements and geo/series reference data
5. Event-content mappings and content blocks
6. Event-achievement and region mappings
7. Roadside-station registry

## Excluded by design

- `announcements`: editorial content needs review before production publication.
- `app_release_policies`: must be initialized with deliberate production build/version values, not copied from closed-test build settings.
- Storage object data: must be copied separately after verifying rights, object hashes, MIME types and bucket policies.
- The one `events.cover_image_url` pointing at the closed-test Supabase project was nulled in this export. Other image references are local Flutter `assets/...` paths and are retained.
- No row data from user-specific tables is included.

## Validation

The source counts are documented in `docs/production-schema-target.md`. After import, compare per-table counts and run foreign-key checks, geospatial query checks, and the read-only RLS audit. This export is a data artifact, not a replacement for schema migrations or a production deployment approval.

Before the first production release, follow `PRODUCTION_RELEASE_POLICY.md` to insert the correct production build/version row. Do not copy closed-test release-policy values.


## Guarded import runner

Use `scripts/import-production-master-data.ps1` rather than manually pasting these files. It defaults to dry-run, requires `SUPABASE_DB_URL` to contain the expected production project ref, requires an explicit typed confirmation before writes, runs each SQL file in its own transaction, stops on the first error, and checks all 13 table counts against the manifest. A partial rerun requires the explicit `-ResumePartialImport` switch.

Dry run:

```powershell
$env:SUPABASE_DB_URL = "postgresql://...production connection string..."
.\scripts\import-production-master-data.ps1
```

Only after reviewing the target and manifest, the explicit apply form is:

```powershell
.\scripts\import-production-master-data.ps1 -Apply
```

Keep the connection string in an environment variable; do not commit it or paste it into chat. This runner does not apply schema DDL, Storage objects, Auth settings, release policy, or Edge Functions.
