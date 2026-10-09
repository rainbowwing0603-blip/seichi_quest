$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$relativePaths = @(
    'scripts/bootstrap-production-schema.ps1',
    'scripts/import-production-master-data.ps1',
    'scripts/repair-production-migration-history.ps1',
    'scripts/check_powershell_syntax.ps1'
)

$failed = $false
foreach ($relativePath in $relativePaths) {
    $path = Join-Path $repoRoot $relativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        Write-Host "FAIL: Required PowerShell script is missing: $relativePath"
        $failed = $true
        continue
    }

    $tokens = $null
    $parseErrors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile(
        $path,
        [ref]$tokens,
        [ref]$parseErrors
    )

    if ($parseErrors.Count -gt 0) {
        $failed = $true
        foreach ($parseError in $parseErrors) {
            Write-Host ("FAIL: {0}: line {1}, column {2}: {3}" -f
                $relativePath,
                $parseError.Extent.StartLineNumber,
                $parseError.Extent.StartColumnNumber,
                $parseError.Message
            )
        }
    }
    else {
        Write-Host "PASS: PowerShell syntax: $relativePath"
    }
}

if ($failed) {
    exit 1
}
