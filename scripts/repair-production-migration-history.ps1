[CmdletBinding()]
param(
    [switch]$Apply
)

$ErrorActionPreference = 'Stop'
$expectedProjectRef = 'npirfaoxcarfuqjlwgav'
$baselineVersion = [long]'20261009010000'
$repoRoot = Split-Path -Parent $PSScriptRoot
$linkedProjectPath = Join-Path $repoRoot 'supabase/.temp/project-ref'

$supabaseCommand = Get-Command supabase -ErrorAction SilentlyContinue
if (-not $supabaseCommand) { throw 'Supabase CLI is required.' }

$preflightSql = @'
SELECT CASE
  WHEN (SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
        WHERE n.nspname='public' AND c.relkind IN ('r','p')
          AND c.relname <> 'spatial_ref_sys' AND NOT c.relispartition) = 25
   AND (SELECT count(*) FROM pg_policies WHERE schemaname='public') = 24
   AND to_regclass('public.seichi') IS NULL
   AND to_regclass('supabase_migrations.schema_migrations') IS NULL
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
   AND to_regprocedure('public.replace_roadside_station_registry(jsonb)') IS NOT NULL
   AND to_regprocedure('public.set_places_updated_at()') IS NOT NULL
   AND EXISTS (
     SELECT 1 FROM pg_trigger t
     JOIN pg_class c ON c.oid = t.tgrelid
     JOIN pg_namespace n ON n.oid = c.relnamespace
     WHERE n.nspname = 'public'
       AND c.relname = 'places'
       AND t.tgname = 'places_set_updated_at'
       AND NOT t.tgisinternal
   )
   AND NOT has_function_privilege('anon', 'public.replace_roadside_station_registry(jsonb)', 'EXECUTE')
   AND NOT has_function_privilege('authenticated', 'public.replace_roadside_station_registry(jsonb)', 'EXECUTE')
   AND has_function_privilege('service_role', 'public.replace_roadside_station_registry(jsonb)', 'EXECUTE')
   AND (SELECT count(*) FROM public.profiles) = 0
   AND (SELECT count(*) FROM public.place_visits) = 0
   AND (SELECT count(*) FROM public.collection_history) = 0
   AND (SELECT count(*) FROM public.user_event_preferences) = 0
   AND (SELECT count(*) FROM public.user_event_participations) = 0
   AND (SELECT count(*) FROM public.user_event_favorites) = 0
   AND (SELECT count(*) FROM public.announcement_reads) = 0
   AND (SELECT count(*) FROM public.location_security_states) = 0
   AND (SELECT count(*) FROM public.location_security_events) = 0
   AND (SELECT count(*) FROM public.event_collection_resets) = 0
   AND (SELECT count(*) FROM public.announcements) = 0
   AND (SELECT count(*) FROM public.app_release_policies) = 0
   AND NOT has_table_privilege('anon', 'public.user_event_participations', 'INSERT')
   AND NOT has_table_privilege('anon', 'public.user_event_participations', 'UPDATE')
   AND NOT has_table_privilege('anon', 'public.user_event_participations', 'DELETE')
   AND NOT has_table_privilege('authenticated', 'public.user_event_participations', 'INSERT')
   AND NOT has_table_privilege('authenticated', 'public.user_event_participations', 'UPDATE')
   AND NOT has_table_privilege('authenticated', 'public.user_event_participations', 'DELETE')
   AND NOT has_table_privilege('anon', 'public.user_event_preferences', 'INSERT')
   AND NOT has_table_privilege('anon', 'public.user_event_preferences', 'UPDATE')
   AND NOT has_table_privilege('anon', 'public.user_event_preferences', 'DELETE')
   AND NOT has_table_privilege('authenticated', 'public.user_event_preferences', 'INSERT')
   AND NOT has_table_privilege('authenticated', 'public.user_event_preferences', 'UPDATE')
   AND NOT has_table_privilege('authenticated', 'public.user_event_preferences', 'DELETE')
   AND NOT EXISTS (
     SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
     WHERE n.nspname='public' AND c.relkind IN ('r','p')
       AND c.relname <> 'spatial_ref_sys' AND NOT c.relispartition AND NOT c.relrowsecurity
   )
  THEN 'READY'
  ELSE 'NOT_READY'
END;
'@

$preflight = & $supabaseCommand.Source db query --linked --project-ref $expectedProjectRef $preflightSql
$preflightExitCode = $LASTEXITCODE
$preflightText = $preflight | Out-String
if ($preflightExitCode -ne 0 -or $preflightText -notmatch '(?m)[│|]\s*READY\s*[│|]') {
    Write-Host $preflightText
    throw 'Production bootstrap preflight failed. No migration history was changed. Do not repair until the schema and master data are fully applied.'
}

$migrationDirectory = Join-Path $repoRoot 'supabase/migrations'
$migrationFiles = @(Get-ChildItem -LiteralPath $migrationDirectory -Filter '*.sql' -File)
$unrecognizedFiles = @($migrationFiles | Where-Object { $_.BaseName -notmatch '^\d{8,14}_.+' })
if ($unrecognizedFiles.Count -gt 0) {
    throw ("Unrecognized migration filename(s); no repair performed: " + ($unrecognizedFiles.Name -join ', '))
}

$allVersions = @(
    foreach ($file in $migrationFiles) {
        if ($file.BaseName -match '^(\d{8,14})_.+$') {
            [long]$Matches[1]
        }
    }
)
$duplicateVersions = @($allVersions | Group-Object | Where-Object { $_.Count -gt 1 })
if ($duplicateVersions.Count -gt 0) {
    throw ("Duplicate migration version(s); no repair performed: " + (($duplicateVersions | ForEach-Object { $_.Name }) -join ', '))
}

$versions = @($allVersions | Where-Object { $_ -lt $baselineVersion } | Sort-Object)
$postBaselineVersions = @($allVersions | Where-Object { $_ -ge $baselineVersion } | Sort-Object)
$expectedPostBaselineVersions = @(
    [long]'20261009010000',
    [long]'20261009020000',
    [long]'20261009031000',
    [long]'20261009032000',
    [long]'20261009040000'
)
if ($versions.Count -ne 75) {
    throw "Expected exactly 75 pre-baseline migrations to repair, found $($versions.Count). No repair performed."
}
if ($postBaselineVersions.Count -ne $expectedPostBaselineVersions.Count -or
    (Compare-Object -ReferenceObject $expectedPostBaselineVersions -DifferenceObject $postBaselineVersions).Count -gt 0) {
    throw "Post-baseline migration set differs from the reviewed five migrations. No repair performed."
}

Write-Host "Verified production project: $expectedProjectRef"
Write-Host "Verified clean bootstrap: 25 tables, 24 policies, master data counts, RLS, no public.seichi"
Write-Host "Migration versions to mark applied: $($versions.Count)"
Write-Host ($versions -join ', ')

if (-not $Apply) {
    Write-Host 'DRY RUN ONLY. Preflight used Supabase CLI; no migration history changed. Re-run with -Apply only after reviewing the version list and linking this worktree to production.'
    return
}

if (-not (Test-Path -LiteralPath $linkedProjectPath)) {
    throw "Dry run passed, but applying requires this worktree to be linked first. Run: supabase link --project-ref $expectedProjectRef"
}
$linkedProject = [System.IO.File]::ReadAllText($linkedProjectPath, [System.Text.Encoding]::UTF8).Trim()
if ($linkedProject -cne $expectedProjectRef) {
    throw "Linked project '$linkedProject' is not the expected production project '$expectedProjectRef'. No repair was run."
}

$confirmation = Read-Host "Type REPAIR $expectedProjectRef to mark the listed legacy migrations applied"
if ($confirmation -cne "REPAIR $expectedProjectRef") {
    throw 'Confirmation did not match. No migration history changed.'
}

& supabase migration repair @versions --status applied
if ($LASTEXITCODE -ne 0) {
    throw "Supabase migration repair failed with exit code $LASTEXITCODE. Review 'supabase migration list' before retrying."
}
Write-Host 'Legacy migration history marked applied. Next run supabase db push to apply only the new post-baseline migrations, then verify supabase migration list.'
