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
$preflight = & $supabaseCommand.Source db query --linked --project-ref $expectedProjectRef $preflightSql
$preflightExitCode = $LASTEXITCODE
$preflightText = $preflight | Out-String
if ($preflightExitCode -ne 0 -or $preflightText -notmatch '(?m)[│|]\s*READY\s*[│|]') {
    Write-Host $preflightText
    throw 'Production bootstrap preflight failed. No migration history was changed. Do not repair until the schema and master data are fully applied.'
}

$migrationDirectory = Join-Path $repoRoot 'supabase/migrations'
$versions = @(
    Get-ChildItem -LiteralPath $migrationDirectory -Filter '*.sql' -File |
    ForEach-Object {
        if ($_.BaseName -match '^(\d{8,14})_') {
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
    Write-Host 'DRY RUN ONLY. Preflight used Supabase CLI; no migration history changed. Re-run with -Apply only after reviewing the version list and linking this worktree to production.'
    return
}

$linkedProjectPath = Join-Path $repoRoot 'supabase/.temp/project-ref'
if (-not (Test-Path -LiteralPath $linkedProjectPath)) {
    throw "Dry run passed, but applying requires this worktree to be linked first. Run: supabase link --project-ref $expectedProjectRef"
}
$linkedProject = [System.IO.File]::ReadAllText($linkedProjectPath, [System.Text.Encoding]::UTF8).Trim()
if ($linkedProject -cne $expectedProjectRef) {
    throw "Linked project '$linkedProject' is not the expected production project '$expectedProjectRef'. No repair was run."
}

$confirmation = Read-Host "Type REPAIR $expectedProjectRef to mark the listed legacy migrations applied"
if ($confirmation -cne "REPAIR $expectedProjectRef") { throw 'Confirmation did not match. No migration history changed.' }

& supabase migration repair @versions --status applied
if ($LASTEXITCODE -ne 0) {
    throw "Supabase migration repair failed with exit code $LASTEXITCODE. Review 'supabase migration list' before retrying."
}
Write-Host 'Legacy migration history marked applied. Next run supabase db push to apply only the new post-baseline migrations, then verify supabase migration list.'
