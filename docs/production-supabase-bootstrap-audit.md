# Production Supabase bootstrap audit

Date: 2026-10-09

## Current state

- Closed-test project: `wxlvhpmolrtcwryaazfb` (read-only during this audit).
- Production project: `npirfaoxcarfuqjlwgav` (new and still empty).
- The closed-test database reports migration versions through `20261007211445`.
- The repository branch `feature/android-next-release` was missing the two latest functional migrations. They have been restored from the deployed function definitions:
  - `20261005232656_story_preview_server_time.sql`
  - `20261007211445_event_demographic_recommendations.sql`
- Three earlier CodeMagic bridge migrations are also recorded in the deployed migration history but absent from the repository. Their original SQL must be recovered from history or their final-state effect must be documented before reconstructing a full replayable migration chain.
- The repository migration chain is not a complete bootstrap for an empty project: its earliest migration already depends on existing core tables. Replaying the directory against a fresh project is therefore not a safe bootstrap strategy.

## Safe implementation decision

Do not apply the existing migration directory to production yet. Do not mutate the closed-test database to make it match the repository.

Instead:

1. Capture a schema snapshot from the live closed-test database, including table/column definitions, defaults, constraints, indexes, RLS policies, grants, triggers, functions, extensions, and storage bucket/policy definitions.
2. Compare that snapshot with the repository SQL and document any intentional drift.
3. Recover or explicitly retire the three missing historical CodeMagic migrations without inventing their original contents.
4. Build and review a reproducible production baseline from the verified current schema. Keep data export separate from schema deployment.
5. Migrate only approved reference/master data. Exclude Auth users, profile rows, collection history, visits, preferences, favorites, location-security records, and other user-generated data by default.
6. Copy required Storage objects only after identifying the exact public/private buckets and their access policies. Verify references and object counts.
7. Apply the baseline to the empty production project, then compare schema signatures and run security advisors and functional smoke tests before configuring a production build.

## Verification gate

Production deployment must remain blocked until:
- the production schema matches the approved baseline;
- RLS and grants are verified for every exposed table;
- SECURITY DEFINER functions have reviewed search paths and least-privilege EXECUTE grants;
- Storage policies and required assets are verified;
- required master-data row counts and key relationships match the approved export;
- the closed-test project and its tester data remain unchanged.

This audit document records the decision only. It does not apply schema changes or copy data.
