# Production migration-history reconciliation

Date: 2026-10-11
Production project ref: `npirfaoxcarfuqjlwgav`

## Why this is needed

A read-only comparison found 91 SQL migration files on `feature/android-next-release` and 87 versions in the production migration history. Six local versions are missing from production history, while two production history versions have no same-version file in the branch.

This is migration-history drift, not proof that the live schema is missing those changes. The live schema and effective RPC grants were inspected before preparing the reconciliation:

- `story_preview_server_time()` exists and is executable by `authenticated`, not `anon`.
- The public event-recommendation function is an invoker wrapper; its private implementation contains the NULL-safe age/gender predicates.
- `get_public_ranking(uuid, integer)` is executable by `authenticated`, not `anon`.
- The profile gender column and anonymous-admin policy checks are present.
- The three `public.st_estimatedextent` signatures targeted by the no-op restriction migration are absent.

## Exact history-only reconciliation

Mark these source versions as applied without replaying their SQL. Their effects are represented by later production migrations or the verified live state:

- `20261010100001`
- `20261010181426`
- `20261010181454`
- `20261010231230`
- `20261011090000`
- `20261011093000`

Mark these production-only history entries reverted because the same changes are represented in source under the later versions above:

- `20261010232928`
- `20261010234108`

The `reverted` operation changes migration bookkeeping only. It does not reverse database DDL or policy changes. Do not use this reconciliation if the source versions or the live preflight no longer match the exact reviewed set.

## Procedure

Run from the repository root in a worktree checked out to `fix/production-migration-history-reconcile-20261011` or a later branch containing this script:

```powershell
Set-Location C:\src\seichi_quest
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\reconcile-production-migration-history.ps1
```

The first invocation is dry-run only. Review the exact versions and the live preflight output. Only after confirming the linked project ref is the production project, run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\reconcile-production-migration-history.ps1 -Apply
```

The script checks the linked project ref, validates the live schema and RPC grants, compares the exact local/remote drift set, requires typing `RECONCILE npirfaoxcarfuqjlwgav`, applies only migration-history repairs, and verifies that local and remote migration version sets match afterward.

Do not run `supabase db push` as part of this history-only repair. No application data or schema is intended to change. If any preflight or exact-set check fails, the script stops without repairing history.
