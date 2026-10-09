[CmdletBinding()]
param(
    [switch]$Apply
)

$ErrorActionPreference = 'Stop'
$expectedProjectRef = 'npirfaoxcarfuqjlwgav'
$repoRoot = Split-Path -Parent $PSScriptRoot
$baselinePath = Join-Path $repoRoot 'supabase/baselines/production_schema_candidate_20261009.sql'
$seedDirectory = Join-Path $repoRoot 'supabase/seed/production_master_data'

if (-not (Test-Path -LiteralPath $baselinePath)) { throw "Baseline SQL not found: $baselinePath" }
if (-not (Test-Path -LiteralPath $seedDirectory)) { throw "Seed directory not found: $seedDirectory" }
if (-not (Get-Command psql -ErrorAction SilentlyContinue)) { throw 'psql is required. Install PostgreSQL client tools before applying.' }

$databaseUrl = $env:SUPABASE_DB_URL
if ([string]::IsNullOrWhiteSpace($databaseUrl)) {
    throw 'Set SUPABASE_DB_URL in this PowerShell session to the direct production database connection URI. Do not save it in Git or paste it into chat.'
}
if ($databaseUrl -notmatch [regex]::Escape($expectedProjectRef)) {
    throw "Connection URI does not visibly identify the expected production project ref '$expectedProjectRef'. Refusing to continue."
}

$baseline = [System.IO.File]::ReadAllText($baselinePath, [System.Text.Encoding]::UTF8)
$baseline = [regex]::Replace($baseline, '^\s*BEGIN;\s*', '', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
$baseline = [regex]::Replace($baseline, '\s*COMMIT;\s*$', '', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)

$seedFiles = @(Get-ChildItem -LiteralPath $seedDirectory -Filter '*.sql' -File | Sort-Object -Property Name)
if ($seedFiles.Count -ne 47) {
    throw "Expected 47 curated seed SQL files, found $($seedFiles.Count). Review the manifest before proceeding."
}

$builder = [System.Text.StringBuilder]::new()
[void]$builder.AppendLine('BEGIN;')
$guardSql = @'
DO $guard$
DECLARE
  v_has_migration_history boolean;
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.tables
    WHERE table_schema IN ('public', 'private', 'gis')
      AND table_type = 'BASE TABLE'
      AND table_name <> 'spatial_ref_sys'
  ) THEN
    RAISE EXCEPTION 'Production application schemas are not empty. Refusing bootstrap.';
  END IF;

  IF to_regclass('supabase_migrations.schema_migrations') IS NOT NULL THEN
    EXECUTE 'SELECT EXISTS (SELECT 1 FROM supabase_migrations.schema_migrations)'
      INTO v_has_migration_history;
    IF v_has_migration_history THEN
      RAISE EXCEPTION 'Production migration history is not empty. Refusing one-time bootstrap.';
    END IF;
  END IF;
END
$guard$;
'@
[void]$builder.AppendLine($guardSql)
[void]$builder.AppendLine($baseline)
foreach ($file in $seedFiles) {
    [void]$builder.AppendLine("-- Seed file: $($file.Name)")
    [void]$builder.AppendLine([System.IO.File]::ReadAllText($file.FullName, [System.Text.Encoding]::UTF8))
}

$validateSql = @'
DO $validate$
DECLARE
  v_bad_rls integer;
  v_public_tables integer;
  v_policy_count integer;
BEGIN
  IF to_regclass('public.seichi') IS NOT NULL THEN
    RAISE EXCEPTION 'Retired public.seichi table unexpectedly exists.';
  END IF;

  SELECT count(*) INTO v_public_tables
  FROM pg_class c
  JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'public'
    AND c.relkind IN ('r','p')
    AND c.relname <> 'spatial_ref_sys'
    AND NOT c.relispartition;
  IF v_public_tables <> 25 THEN
    RAISE EXCEPTION 'Expected 25 application tables, found %.', v_public_tables;
  END IF;

  SELECT count(*) INTO v_bad_rls
  FROM pg_class c
  JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'public'
    AND c.relkind IN ('r','p')
    AND c.relname <> 'spatial_ref_sys'
    AND NOT c.relispartition
    AND NOT c.relrowsecurity;
  IF v_bad_rls <> 0 THEN
    RAISE EXCEPTION 'Found % public application tables without RLS.', v_bad_rls;
  END IF;

  SELECT count(*) INTO v_policy_count
  FROM pg_policies
  WHERE schemaname = 'public';
  IF v_policy_count <> 26 THEN
    RAISE EXCEPTION 'Expected 26 reviewed public policies, found %.', v_policy_count;
  END IF;

  IF (SELECT count(*) FROM public.events) <> 51
     OR (SELECT count(*) FROM public.places) <> 1713
     OR (SELECT count(*) FROM public.contents) <> 2742
     OR (SELECT count(*) FROM public.event_contents) <> 2721
     OR (SELECT count(*) FROM public.content_blocks) <> 336
     OR (SELECT count(*) FROM public.achievements) <> 18
     OR (SELECT count(*) FROM public.event_achievements) <> 18
     OR (SELECT count(*) FROM public.geo_regions) <> 57
     OR (SELECT count(*) FROM public.geo_region_prefectures) <> 141
     OR (SELECT count(*) FROM public.collection_series) <> 1
     OR (SELECT count(*) FROM public.collection_series_places) <> 1231
     OR (SELECT count(*) FROM public.collection_series_regions) <> 57
     OR (SELECT count(*) FROM public.roadside_station_registry) <> 1234 THEN
    RAISE EXCEPTION 'Curated master-data row counts do not match the reviewed manifest.';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_event_trigger WHERE evtname = 'ensure_rls') THEN
    RAISE EXCEPTION 'Automatic RLS event trigger ensure_rls is missing.';
  END IF;

  IF has_table_privilege('authenticated', 'public.user_event_participations', 'INSERT')
     OR has_table_privilege('authenticated', 'public.user_event_participations', 'UPDATE')
     OR has_table_privilege('authenticated', 'public.user_event_preferences', 'INSERT')
     OR has_table_privilege('authenticated', 'public.user_event_preferences', 'UPDATE') THEN
    RAISE EXCEPTION 'Direct authenticated event-state writes are still granted.';
  END IF;
END
$validate$;

SELECT 'production bootstrap validation passed' AS result;
COMMIT;
'@
[void]$builder.AppendLine($validateSql)

$tempSql = Join-Path ([System.IO.Path]::GetTempPath()) ("seichi_quest_production_bootstrap_{0}.sql" -f [guid]::NewGuid().ToString('N'))
try {
    [System.IO.File]::WriteAllText($tempSql, $builder.ToString(), [System.Text.UTF8Encoding]::new($false))
    $sizeMb = [math]::Round((Get-Item -LiteralPath $tempSql).Length / 1MB, 2)
    Write-Host "Target project ref: $expectedProjectRef"
    Write-Host "Curated seed SQL files: $($seedFiles.Count)"
    Write-Host "Combined SQL size: $sizeMb MB"
    Write-Host "Preflight guard: production public schema must be empty"
    Write-Host "Validation: 25 tables, 26 policies, RLS, no retired seichi table, all 10,320 master rows"
    if (-not $Apply) {
        Write-Host 'DRY RUN ONLY. No database changes made. Re-run with -Apply after reviewing the target and confirming the DB URI.'
        return
    }

    $confirmation = Read-Host "Type APPLY $expectedProjectRef to execute the single-transaction bootstrap"
    if ($confirmation -cne "APPLY $expectedProjectRef") {
        throw 'Confirmation did not match. No database changes made.'
    }

    & psql --no-psqlrc --set ON_ERROR_STOP=1 --dbname $databaseUrl --file $tempSql
    if ($LASTEXITCODE -ne 0) {
        throw "psql failed with exit code $LASTEXITCODE. The explicit transaction should have rolled back; verify the production table count before retrying."
    }
    Write-Host 'Bootstrap transaction completed and post-load validation passed.'
}
finally {
    if (Test-Path -LiteralPath $tempSql) {
        Remove-Item -LiteralPath $tempSql -Force
    }
}
