[CmdletBinding()]
param([switch]$Apply)

$ErrorActionPreference = 'Stop'
$expectedProjectRef = 'npirfaoxcarfuqjlwgav'
$repoRoot = Split-Path -Parent $PSScriptRoot
$linkedProjectPath = Join-Path $repoRoot 'supabase/.temp/project-ref'
$migrationDirectory = Join-Path $repoRoot 'supabase/migrations'

# These versions are represented by later migrations or verified live state.
# This script edits migration history only; it never executes migration SQL.
$sourceVersionsToMarkApplied = @(
    '20261010100001', # Story-time RPC grant; effective ACL verified live
    '20261010181426', # Recommendation fix folded into 20261010231050
    '20261010181454', # Profile gender schema/RPC folded into 20261010231050
    '20261010231230', # Public PostGIS extent helpers are absent in production
    '20261011090000', # Ranking ACL recorded by 20261010232928
    '20261011093000'  # Admin policies recorded by 20261010234108
)
$remoteVersionsToMarkReverted = @(
    '20261010232928', # Duplicate ranking ACL, retained in source as 20261011090000
    '20261010234108'  # Duplicate admin policies, retained in source as 20261011093000
)

function Invoke-Supabase {
    param([Parameter(Mandatory)][string[]]$Arguments)
    $output = & $script:supabaseCommand.Source @Arguments 2>&1
    $exitCode = $LASTEXITCODE
    $text = $output | Out-String
    if ($exitCode -ne 0) {
        throw "Supabase command failed ($($Arguments -join ' ')):$([Environment]::NewLine)$text"
    }
    return $text
}

function Get-MigrationColumns {
    param([Parameter(Mandatory)][string]$Text)
    $local = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    $remote = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    foreach ($line in ($Text -split '\r?\n')) {
        $cells = $line -split '[│|]'
        if ($cells.Count -lt 2) { continue }
        $left = ($cells[0] -replace '\x1b\[[0-9;]*m', '').Trim()
        $right = ($cells[1] -replace '\x1b\[[0-9;]*m', '').Trim()
        if ($left -match '^(\d{8,14})$') { [void]$local.Add($Matches[1]) }
        if ($right -match '^(\d{8,14})$') { [void]$remote.Add($Matches[1]) }
    }
    return @{ Local = $local; Remote = $remote }
}

$supabaseCommand = Get-Command supabase -ErrorAction SilentlyContinue
if (-not $supabaseCommand) { throw 'Supabase CLI is required. No changes were made.' }
if (-not (Test-Path -LiteralPath $linkedProjectPath)) {
    throw "Worktree is not linked. Link to $expectedProjectRef only if this is the intended production worktree."
}
$linkedProject = [System.IO.File]::ReadAllText($linkedProjectPath, [System.Text.Encoding]::UTF8).Trim()
if ($linkedProject -cne $expectedProjectRef) {
    throw "Linked project '$linkedProject' is not production '$expectedProjectRef'. No changes were made."
}

$migrationFiles = @(Get-ChildItem -LiteralPath $migrationDirectory -Filter '*.sql' -File)
$sourceVersions = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
foreach ($file in $migrationFiles) {
    if ($file.BaseName -notmatch '^(\d{8,14})_.+$') {
        throw "Invalid migration filename '$($file.Name)'. No changes were made."
    }
    if (-not $sourceVersions.Add($Matches[1])) {
        throw "Duplicate local migration version '$($Matches[1])'. No changes were made."
    }
}
foreach ($version in $sourceVersionsToMarkApplied) {
    if (-not $sourceVersions.Contains($version)) {
        throw "Expected source migration $version is missing. No changes were made."
    }
}
foreach ($version in $remoteVersionsToMarkReverted) {
    if ($sourceVersions.Contains($version)) {
        throw "Remote-only version $version unexpectedly exists in source. No changes were made."
    }
}

$preflightSql = @'
SELECT CASE WHEN
  to_regprocedure('public.story_preview_server_time()') IS NOT NULL
  AND has_function_privilege('authenticated', 'public.story_preview_server_time()', 'EXECUTE')
  AND NOT has_function_privilege('anon', 'public.story_preview_server_time()', 'EXECUTE')
  AND to_regprocedure('public.get_event_recommendations(integer)') IS NOT NULL
  AND to_regprocedure('private.get_event_recommendations(integer)') IS NOT NULL
  AND (SELECT NOT prosecdef FROM pg_proc WHERE oid = to_regprocedure('public.get_event_recommendations(integer)'))
  AND (SELECT prosecdef FROM pg_proc WHERE oid = to_regprocedure('private.get_event_recommendations(integer)'))
  AND position('age_group is null' IN lower(pg_get_functiondef(to_regprocedure('private.get_event_recommendations(integer)')))) > 0
  AND position('gender is null' IN lower(pg_get_functiondef(to_regprocedure('private.get_event_recommendations(integer)')))) > 0
  AND to_regprocedure('public.get_public_ranking(uuid,integer)') IS NOT NULL
  AND has_function_privilege('authenticated', 'public.get_public_ranking(uuid,integer)', 'EXECUTE')
  AND NOT has_function_privilege('anon', 'public.get_public_ranking(uuid,integer)', 'EXECUTE')
  AND to_regcolumn('public.profiles.gender') IS NOT NULL
  AND to_regprocedure('public.st_estimatedextent(text,text)') IS NULL
  AND to_regprocedure('public.st_estimatedextent(text,text,text)') IS NULL
  AND to_regprocedure('public.st_estimatedextent(text,text,text,boolean)') IS NULL
  AND EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='content_blocks' AND policyname='content_blocks_admin_insert' AND with_check ILIKE '%is_anonymous%')
  AND EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='events' AND policyname='events_admin_update_theme' AND qual ILIKE '%is_anonymous%')
THEN 'READY' ELSE 'NOT_READY' END;
'@
$preflightText = Invoke-Supabase -Arguments @('db','query','--linked','--project-ref',$expectedProjectRef,$preflightSql)
if ($preflightText -notmatch '(?m)[│|]\s*READY\s*[│|]') {
    throw "Production schema/ACL preflight failed. No migration history was changed.$([Environment]::NewLine)$preflightText"
}

$listingText = Invoke-Supabase -Arguments @('migration','list','--linked')
$columns = Get-MigrationColumns -Text $listingText
if ($columns.Local.Count -ne $sourceVersions.Count) {
    throw "Could not safely parse local migration list (CLI reports $($columns.Local.Count), files contain $($sourceVersions.Count)). No changes were made.$([Environment]::NewLine)$listingText"
}
if ($columns.Remote.Count -eq 0) {
    throw "Could not safely parse remote migration list. No changes were made.$([Environment]::NewLine)$listingText"
}
$localOnly = @($columns.Local | Where-Object { -not $columns.Remote.Contains($_) } | Sort-Object)
$remoteOnly = @($columns.Remote | Where-Object { -not $columns.Local.Contains($_) } | Sort-Object)
$expectedLocalOnly = @($sourceVersionsToMarkApplied | Sort-Object)
$expectedRemoteOnly = @($remoteVersionsToMarkReverted | Sort-Object)
if (($localOnly -join ',') -cne ($expectedLocalOnly -join ',') -or
    ($remoteOnly -join ',') -cne ($expectedRemoteOnly -join ',')) {
    throw "Migration drift differs from the reviewed exact set. No changes were made.$([Environment]::NewLine)Local-only: $($localOnly -join ', ')$([Environment]::NewLine)Remote-only: $($remoteOnly -join ', ')$([Environment]::NewLine)$listingText"
}

Write-Host "Production project verified: $expectedProjectRef"
Write-Host 'Live schema/ACL preflight: READY'
Write-Host "Local versions to mark applied: $($sourceVersionsToMarkApplied -join ', ')"
Write-Host "Remote-only duplicate versions to mark reverted: $($remoteVersionsToMarkReverted -join ', ')"
Write-Host 'Migration history only will change; migration SQL and application data are not modified.'

if (-not $Apply) {
    Write-Host 'DRY RUN ONLY. Review the version lists. Re-run with -Apply to perform guarded history reconciliation.'
    return
}

$confirmation = Read-Host "Type RECONCILE $expectedProjectRef to continue"
if ($confirmation -cne "RECONCILE $expectedProjectRef") {
    throw 'Confirmation did not match. No migration history was changed.'
}

Invoke-Supabase -Arguments (@('migration','repair') + $sourceVersionsToMarkApplied + @('--status','applied')) | Write-Host
Invoke-Supabase -Arguments (@('migration','repair') + $remoteVersionsToMarkReverted + @('--status','reverted')) | Write-Host

$verifiedText = Invoke-Supabase -Arguments @('migration','list','--linked')
$verified = Get-MigrationColumns -Text $verifiedText
$stillLocalOnly = @($verified.Local | Where-Object { -not $verified.Remote.Contains($_) })
$stillRemoteOnly = @($verified.Remote | Where-Object { -not $verified.Local.Contains($_) })
if ($stillLocalOnly.Count -ne 0 -or $stillRemoteOnly.Count -ne 0) {
    throw "History repair ran, but migration lists still differ. Do not run db push; inspect:$([Environment]::NewLine)$verifiedText"
}
Write-Host 'SUCCESS: local and production migration version sets match. No schema migration was replayed.'
