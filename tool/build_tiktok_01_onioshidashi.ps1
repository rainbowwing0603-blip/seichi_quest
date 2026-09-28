param([string]$Output = ".\media_assets\video_output\tiktok_01_onioshidashi.mp4")
$ErrorActionPreference = "Stop"
Set-Location (Resolve-Path (Join-Path $PSScriptRoot ".."))

$ffmpegCmd = Get-Command ffmpeg -ErrorAction SilentlyContinue
if (-not $ffmpegCmd) { throw "ffmpeg is not available in PATH." }
$ffmpeg = $ffmpegCmd.Source

$utf8 = New-Object System.Text.UTF8Encoding($false)
$configPath = Join-Path $PSScriptRoot "tiktok_01_onioshidashi.json"
$config = [IO.File]::ReadAllText($configPath, $utf8) | ConvertFrom-Json
$manifest = [IO.File]::ReadAllText((Resolve-Path ".\media_assets\manifest.json"), $utf8) | ConvertFrom-Json

$appItem = Get-ChildItem ".\media_assets\app_captures_final" -Filter "44_*_map.png" | Select-Object -First 1
if (-not $appItem) { throw "App capture 44_*_map.png was not found." }
$app = $appItem.FullName

$work = ".\media_assets\video_work\tiktok_01_onioshidashi"
$outDir = Split-Path $Output -Parent
New-Item -ItemType Directory -Force $work,$outDir | Out-Null

$photos = @($manifest.assets | Where-Object {
  $_.spot_key -eq "onioshidashi" -and $_.status -eq "verified_candidate" -and $_.embedded_watermark -eq $false
} | Select-Object -First 3)
if ($photos.Count -lt 3) { throw "Three verified onioshidashi photos were not found in manifest.json." }

$missing = @($photos | Where-Object { -not (Test-Path $_.cache_path) })
if ($missing.Count -gt 0) {
  Write-Host ""
  Write-Host "Required licensed photos are not present in media_assets/cache." -ForegroundColor Yellow
  Write-Host "Wikimedia is rate-limiting downloads (HTTP 429), so this builder will not retry the network." -ForegroundColor Yellow
  Write-Host "Missing cache files:" -ForegroundColor Yellow
  $missing | ForEach-Object { Write-Host ("  " + $_.cache_path) }
  Write-Host ""
  Write-Host "Run this later, then rerun this builder:" -ForegroundColor Cyan
  Write-Host "  python tool/download_media_assets.py --max-files 3" -ForegroundColor Cyan
  throw "Required local photo assets are missing."
}

function EscapeAssText([string]$value) {
  return $value.Replace("\\","\\\\").Replace("{","\\{").Replace("}","\\}").Replace([Environment]::NewLine,"\\N").Replace("`n","\\N")
}
function WriteAss([string]$name,[string]$caption,[int]$size,[string]$alignment="8",[int]$marginV=120) {
  $native = Join-Path (Resolve-Path $work).Path ($name + ".ass")
  $txt = EscapeAssText $caption
  $ass = @"
[Script Info]
ScriptType: v4.00+
PlayResX: 1080
PlayResY: 1920
WrapStyle: 2

[V4+ Styles]
Format: Name,Fontname,Fontsize,PrimaryColour,SecondaryColour,OutlineColour,BackColour,Bold,Italic,Underline,StrikeOut,ScaleX,ScaleY,Spacing,Angle,BorderStyle,Outline,Shadow,Alignment,MarginL,MarginR,MarginV,Encoding
Style: Default,Noto Sans JP,$size,&H00FFFFFF,&H000000FF,&H66000000,&H66000000,0,0,0,0,100,100,0,0,1,3,0,$alignment,60,60,$marginV,1

[Events]
Format: Layer,Start,End,Style,Name,MarginL,MarginR,MarginV,Effect,Text
Dialogue: 0,0:00:00.00,9:59:59.00,Default,,0,0,0,,$txt
"@
  [IO.File]::WriteAllText($native,$ass,$utf8)
  return ("media_assets/video_work/tiktok_01_onioshidashi/" + $name + ".ass")
}
function MakePhoto([string]$src,[string]$out,[double]$dur,[string]$caption,[int]$size=74) {
  $ass=WriteAss ([IO.Path]::GetFileNameWithoutExtension($out)) $caption $size "8" 120
  $vf="scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920,drawbox=x=0:y=0:w=iw:h=330:color=black@0.38:t=fill,ass=filename='$ass'"
  & $ffmpeg -hide_banner -loglevel error -y -loop 1 -t $dur -i $src -vf $vf -r 30 -c:v libx264 -pix_fmt yuv420p -an $out
  if ($LASTEXITCODE -ne 0) { throw "ffmpeg failed: $out" }
}
function MakeCard([string]$out,[double]$dur,[string]$caption,[int]$size=86) {
  $ass=WriteAss ([IO.Path]::GetFileNameWithoutExtension($out)) $caption $size "5" 0
  $vf="ass=filename='$ass'"
  & $ffmpeg -hide_banner -loglevel error -y -f lavfi -i "color=c=0x10162b:s=1080x1920:r=30" -t $dur -vf $vf -c:v libx264 -pix_fmt yuv420p -an $out
  if ($LASTEXITCODE -ne 0) { throw "ffmpeg failed: $out" }
}

$seg=@()
$seg += "$work\01.mp4"; MakePhoto $photos[0].cache_path $seg[-1] 2.6 $config.question
$seg += "$work\02.mp4"; MakePhoto $photos[1].cache_path $seg[-1] 2.4 $config.hint
$seg += "$work\03.mp4"; MakePhoto $photos[2].cache_path $seg[-1] 2.4 $config.countdown 110
$seg += "$work\04.mp4"; MakeCard $seg[-1] 2.2 $config.answer_lead 104
$seg += "$work\05.mp4"; MakeCard $seg[-1] 2.8 $config.quest_cta 78

$appAss=WriteAss "app" $config.app_caption 70 "2" 150
$vfApp="crop=1080:1920:0:0,drawbox=x=0:y=1560:w=iw:h=360:color=black@0.42:t=fill,ass=filename='$appAss'"
& $ffmpeg -hide_banner -loglevel error -y -loop 1 -t 3.6 -i $app -vf $vfApp -r 30 -c:v libx264 -pix_fmt yuv420p -an "$work\06.mp4"
if ($LASTEXITCODE -ne 0) { throw "ffmpeg failed: app segment" }
$seg += "$work\06.mp4"

$seg += "$work\07.mp4"; MakeCard $seg[-1] 2.4 $config.final_caption 76
$credits = @($photos | ForEach-Object { "$($_.author) / $($_.license)" })
$creditText = $config.credit_prefix + ($credits -join " / ")
$seg += "$work\08.mp4"; MakeCard $seg[-1] 1.8 $creditText 34

$concatNative = Join-Path (Resolve-Path $work).Path "concat.txt"
$lines = $seg | ForEach-Object { "file '$((Resolve-Path $_).Path.Replace("'","''"))'" }
[IO.File]::WriteAllLines($concatNative,$lines,$utf8)
& $ffmpeg -y -f concat -safe 0 -i $concatNative -c copy $Output
if ($LASTEXITCODE -ne 0) { throw "ffmpeg concat failed." }

Write-Host ""
Write-Host "=== TikTok prototype complete ===" -ForegroundColor Green
Get-Item $Output | Select-Object FullName,@{N="MB";E={[math]::Round($_.Length/1MB,2)}}
Write-Host "Target: 20.2 sec / 1080x1920 / 30fps"
