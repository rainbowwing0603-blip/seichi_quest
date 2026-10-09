[CmdletBinding()]
param(
    [switch]$Apply,
    [switch]$ResumePartialImport,
    [string]$ExpectedProjectRef = "npirfaoxcarfuqjlwgav"
)

$ErrorActionPreference = "Stop"
$seedRoot = Join-Path (Split-Path -Parent $PSScriptRoot) "supabase/seed/production_master_data"
$dbUrl = $env:SUPABASE_DB_URL

if ([string]::IsNullOrWhiteSpace($dbUrl)) {
    throw "Set SUPABASE_DB_URL in the current PowerShell session. Do not paste credentials into this script."
}
if ([string]::IsNullOrWhiteSpace($ExpectedProjectRef) -or $dbUrl -notmatch [regex]::Escape($ExpectedProjectRef)) {
    throw "Database URL does not contain the expected project ref '$ExpectedProjectRef'. No SQL was run."
}
$psqlCommand = Get-Command psql -ErrorAction SilentlyContinue
if (-not $psqlCommand) {
    throw "psql was not found. Install PostgreSQL command-line tools before importing."
}

$files = @(Get-ChildItem -LiteralPath $seedRoot -Filter "*.sql" -File | Sort-Object Name)
if ($files.Count -ne 47) {
    throw "Expected 47 ordered seed SQL files, found $($files.Count). Review the manifest before proceeding."
}

Write-Host "Target project ref: $ExpectedProjectRef"
Write-Host "Seed files: $($files.Count)"
$files | ForEach-Object { Write-Host ("  {0,-52} {1,8:N0} bytes" -f $_.Name, $_.Length) }

if (-not $Apply) {
    Write-Host ""
    Write-Host "DRY RUN ONLY. No SQL was executed."
    Write-Host "To apply, rerun with -Apply after reviewing the target and manifest."
    exit 0
}

if (-not $ResumePartialImport) {
    $existing = & $psqlCommand.Source --no-psqlrc --no-password --set ON_ERROR_STOP=1 --tuples-only --no-align --dbname $dbUrl --command @"
SELECT
  (SELECT count(*) FROM public.events) +
  (SELECT count(*) FROM public.places) +
  (SELECT count(*) FROM public.contents) +
  (SELECT count(*) FROM public.event_contents) +
  (SELECT count(*) FROM public.content_blocks) +
  (SELECT count(*) FROM public.achievements) +
  (SELECT count(*) FROM public.event_achievements) +
  (SELECT count(*) FROM public.geo_regions) +
  (SELECT count(*) FROM public.geo_region_prefectures) +
  (SELECT count(*) FROM public.collection_series) +
  (SELECT count(*) FROM public.collection_series_places) +
  (SELECT count(*) FROM public.collection_series_regions) +
  (SELECT count(*) FROM public.roadside_station_registry);
"@
    if ($LASTEXITCODE -ne 0) {
        throw "Production preflight query failed. No seed SQL was executed."
    }
    if ([int]("$existing".Trim()) -ne 0) {
        throw "Master tables are not empty. Import stopped before writes. Inspect counts or explicitly use -ResumePartialImport only for a previously interrupted import."
    }
}

$confirmation = Read-Host "Type IMPORT $ExpectedProjectRef to authorize master-data import"
if ($confirmation -cne "IMPORT $ExpectedProjectRef") {
    throw "Confirmation did not match. No seed SQL was executed."
}

foreach ($file in $files) {
    Write-Host "Applying $($file.Name)..."
    & $psqlCommand.Source --no-psqlrc --no-password --set ON_ERROR_STOP=1 --single-transaction --dbname $dbUrl --file $file.FullName
    if ($LASTEXITCODE -ne 0) {
        throw "Import failed at $($file.Name). That file was rolled back. Fix the cause, then rerun with -ResumePartialImport."
    }
}

$actual = & $psqlCommand.Source --no-psqlrc --no-password --set ON_ERROR_STOP=1 --tuples-only --no-align --field-separator "|" --dbname $dbUrl --command @"
SELECT 'events', count(*) FROM public.events
UNION ALL SELECT 'places', count(*) FROM public.places
UNION ALL SELECT 'contents', count(*) FROM public.contents
UNION ALL SELECT 'event_contents', count(*) FROM public.event_contents
UNION ALL SELECT 'content_blocks', count(*) FROM public.content_blocks
UNION ALL SELECT 'achievements', count(*) FROM public.achievements
UNION ALL SELECT 'event_achievements', count(*) FROM public.event_achievements
UNION ALL SELECT 'geo_regions', count(*) FROM public.geo_regions
UNION ALL SELECT 'geo_region_prefectures', count(*) FROM public.geo_region_prefectures
UNION ALL SELECT 'collection_series', count(*) FROM public.collection_series
UNION ALL SELECT 'collection_series_places', count(*) FROM public.collection_series_places
UNION ALL SELECT 'collection_series_regions', count(*) FROM public.collection_series_regions
UNION ALL SELECT 'roadside_station_registry', count(*) FROM public.roadside_station_registry;
"@
if ($LASTEXITCODE -ne 0) {
    throw "Post-import row-count verification query failed."
}

$expected = @{
    events = 51; places = 1713; contents = 2742; event_contents = 2721
    content_blocks = 336; achievements = 18; event_achievements = 18
    geo_regions = 57; geo_region_prefectures = 141; collection_series = 1
    collection_series_places = 1231; collection_series_regions = 57
    roadside_station_registry = 1234
}
$actualMap = @{}
foreach ($line in $actual) {
    $parts = "$line".Trim().Split("|")
    if ($parts.Count -eq 2) { $actualMap[$parts[0]] = [int]$parts[1] }
}
$failed = @()
foreach ($table in $expected.Keys) {
    if (-not $actualMap.ContainsKey($table) -or $actualMap[$table] -ne $expected[$table]) {
        $failed += "$table expected=$($expected[$table]) actual=$($actualMap[$table])"
    }
}
if ($failed.Count -gt 0) {
    throw "Post-import counts differ from the captured source snapshot: $($failed -join '; '). Do not release the app until reconciled."
}
Write-Host "PASS: all 13 master-table counts match the captured source snapshot."
Write-Host "Next: run supabase/security/production_rls_audit.sql and verify Storage objects/policies separately."
