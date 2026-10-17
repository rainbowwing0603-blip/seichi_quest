[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ImagePath,

    [Parameter(Mandatory = $true)]
    [string]$EventContentId,

    [switch]$ProductionOnly,
    [switch]$TestOnly
)

$ErrorActionPreference = "Stop"

if ($ProductionOnly -and $TestOnly) {
    throw "ProductionOnly and TestOnly cannot be used together."
}
if (-not (Test-Path -LiteralPath $ImagePath -PathType Leaf)) {
    throw "Image file not found: $ImagePath"
}
if ($EventContentId -notmatch '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$') {
    throw "EventContentId must be a UUID."
}

$bytes = [System.IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $ImagePath).Path)
if ($bytes.Length -lt 8 -or $bytes[0] -ne 0x89 -or $bytes[1] -ne 0x50 -or
    $bytes[2] -ne 0x4E -or $bytes[3] -ne 0x47 -or $bytes[4] -ne 0x0D -or
    $bytes[5] -ne 0x0A -or $bytes[6] -ne 0x1A -or $bytes[7] -ne 0x0A) {
    throw "The input file is not a PNG. Export the stamp as a transparent PNG first."
}

$targets = @()
if (-not $TestOnly) {
    $targets += [pscustomobject]@{
        Name = "production"
        Url = "https://npirfaoxcarfuqjlwgav.supabase.co"
        KeyName = "SEICHI_PROD_SUPABASE_SERVICE_ROLE_KEY"
    }
}
if (-not $ProductionOnly) {
    $targets += [pscustomobject]@{
        Name = "test"
        Url = "https://wxlvhpmolrtcwryaazfb.supabase.co"
        KeyName = "SEICHI_TEST_SUPABASE_SERVICE_ROLE_KEY"
    }
}

$objectPath = "stamps/$EventContentId.png"
foreach ($target in $targets) {
    $key = [Environment]::GetEnvironmentVariable($target.KeyName, "Process")
    if ([string]::IsNullOrWhiteSpace($key)) {
        $secure = Read-Host "Enter $($target.Name) Storage service-role key (input hidden)" -AsSecureString
        $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
        try {
            $key = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
        } finally {
            [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
        }
    }

    try {
        $headers = @{
            apikey = $key
            Authorization = "Bearer $key"
            "Content-Type" = "image/png"
            "x-upsert" = "true"
        }
        $uri = "$($target.Url)/storage/v1/object/content-media/$objectPath"
        Invoke-RestMethod -Method Post -Uri $uri -Headers $headers -Body $bytes | Out-Null

        $publicUrl = "$($target.Url)/storage/v1/object/public/content-media/$objectPath"
        Write-Host "[$($target.Name)] Upload successful: $publicUrl" -ForegroundColor Green
    } catch {
        throw "[$($target.Name)] Upload failed. Verify the service-role key, project, bucket, and Storage response. $($_.Exception.Message)"
    } finally {
        $key = $null
    }
}
