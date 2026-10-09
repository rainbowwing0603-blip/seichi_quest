[CmdletBinding()]
param(
    [switch]$Apply
)

$ErrorActionPreference = 'Stop'
$expectedProjectRef = 'npirfaoxcarfuqjlwgav'
$baselineVersion = [long]'20261009010000'
$repoRoot = Split-Path -Parent $PSScriptRoot
$linkedProjectPath = Join-Path $repoRoot 'supabase/.temp/project-ref'

if (-not (Get-Command supabase -ErrorAction SilentlyContinue)) { throw 'Supabase CLI is required.' }
if (-not (Get-Command psql -ErrorAction SilentlyContinue)) { throw 'psql is required for the database preflight.' }
if (-not (Test-Path -LiteralPath $linkedProjectPath)) {
    throw 'Project is not linked. Run supabase link --project-ref npirfaoxcarfuqjlwgav first.'
}
$linkedProject = [System.IO.File]::ReadAllText($linkedProjectPath, [System.Text.Encoding]::UTF8).Trim()
if ($linkedProject -cne $expectedProjectRef) {
    throw "Linked project '$linkedProject' is not the expected production project '$expectedProjectRef'."
}

$databaseUrl = $env:SUPABASE_DB_URL
if ([string]::IsNullOrWhiteSpace($databaseUrl) -or $databaseUrl -notmatch [regex]::Escape($expectedProjectRef)) {
    throw "Set SUPABASE_DB_URL to the direct DB URI for production project '$expectedProjectRef'."
}

$preflightSql = @'
SELECT CASE
  WHEN (SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
        WHERE n.nspname='public' AND c.relkind IN ('r','p')
          AND c.relname <> 'spatial_ref_sys' AND NOT c.relispartition) = 25
   AND (SELECT count(*) FROM pg_policies WHERE schemaname='public') = 24
   AND to_regclass('public.seichi') IS NULL
   AND (SELECT count(*) FROM public.events) = 51
   AND (SELECT count(*) FROM public.places) = 1713
   AND (SELECT count(*) FROM public.contents) = 2742
   AND (SELECT count(*) FROM public.event_contents) = 2721
   AND (SELECT count(*) FROM public.content_blocks) = 336
   AND (SELECT count(*) FROM public.achievements) = 18
   AND (SELECT count(*) FROM public.event_achievements) = 18
   AND (SELECT count(*) FROM public.geo_regions) = 57
   AND (SELECT count(*) FROM public.geo_region_prefectures) = 141
   AND (SELECT count(*) FROM public.collection_series) = 1
   AND (SELECT count(*) FROM public.collection_series_places) = 1231
   AND (SELECT count(*) FROM public.collection_series_regions) = 57
   AND (SELECT count(*) FROM public.roadside_station_registry) = 1234
   AND EXISTS (SELECT 1 FROM pg_event_trigger WHERE evtname = 'ensure_rls')
   AND NOT has_table_privilege('authenticated', 'public.user_event_participations', 'INSERT')
   AND NOT has_table_privilege('authenticated', 'public.user_event_participations', 'UPDATE')
   AND NOT has_table_privilege('authenticated', 'public.user_event_preferences', 'INSERT')
   AND NOT has_table_privilege('authenticated', 'public.user_event_preferences', 'UPDATE')
   AND NOT EXISTS (
     SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
     WHERE n.nspname='public' AND c.relkind IN ('r','p')
       AND c.relname <> 'spatial_ref_sys' AND NOT c.relispartition AND NOT c.relrowsecurity
   )
  THEN 'READY'
  ELSE 'NOT_READY'
END;
'@
$preflight = & psql --no-psqlrc --tuples-only --no-align --set ON_ERROR_STOP=1 --dbname $databaseUrl --command $preflightSql
if ($LASTEXITCODE -ne 0 -or ($preflight | Out-String).Trim() -ne 'READY') {
    throw 'Production bootstrap preflight failed. Do not repair migration history until the schema and master data are fully applied.'
}

$migrationDirectory = Join-Path $repoRoot 'supabase/migrations'
$versions = @(
    Get-ChildItem -LiteralPath $migrationDirectory -Filter '*.sql' -File |
    ForEach-Object {
        if ($_.BaseName -match '^(\d{14})_') {
            $version = [long]$Matches[1]
            if ($version -lt $baselineVersion) { $version }
        }
    } |
    Sort-Object -Unique
)
if ($versions.Count -eq 0) { throw 'No pre-baseline migration versions found.' }

Write-Host "Verified production project: $expectedProjectRef"
Write-Host "Verified clean bootstrap: 25 tables, 24 policies, master data counts, RLS, no public.seichi"
Write-Host "Migration versions to mark applied: $($versions.Count)"
Write-Host ($versions -join ', ')
if (-not $Apply) {
    Write-Host 'DRY RUN ONLY. No migration history changed. Re-run with -Apply after reviewing the version list.'
    return
}

$confirmation = Read-Host "Type REPAIR $expectedProjectRef to mark the listed legacy migrations applied"
if ($confirmation -cne "REPAIR $expectedProjectRef") { throw 'Confirmation did not match. No migration history changed.' }

& supabase migration repair @versions --status applied
if ($LASTEXITCODE -ne 0) {
    throw "Supabase migration repair failed with exit code $LASTEXITCODE. Review 'supabase migration list' before retrying."
}
Write-Host 'Legacy migration history marked applied. Next run supabase db push to apply only the new post-baseline migrations, then verify supabase migration list.'
