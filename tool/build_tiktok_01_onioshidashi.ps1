param(
  [string]$Output = ".\media_assets\video_output\tiktok_01_onioshidashi.mp4"
)

$ErrorActionPreference = "Stop"
Set-Location (Resolve-Path (Join-Path $PSScriptRoot ".."))

$ffmpeg = (Get-Command ffmpeg -ErrorAction SilentlyContinue).Source
if (-not $ffmpeg) { throw "ffmpeg が PATH にありません。" }

$font = (Resolve-Path ".\assets\fonts\NotoSansJP-Variable.ttf").Path.Replace("\","/")
$app = (Resolve-Path ".\media_assets\app_captures_final\44_関孝和像・算聖の碑_map.png").Path
$work = ".\media_assets\video_work\tiktok_01_onioshidashi"
$outDir = Split-Path $Output -Parent
New-Item -ItemType Directory -Force $work,$outDir | Out-Null

$photos = @(
  @{ path=".\media_assets\cache\onioshidashi\930d827e7c422df4.jpg"; url="https://upload.wikimedia.org/wikipedia/commons/e/ec/Mt.Asama_from_Onioshidashi.jpg"; credit="保姆虫と登山 / CC BY-SA 4.0" },
  @{ path=".\media_assets\cache\onioshidashi\417d60f6ec6f4006.jpg"; url="https://upload.wikimedia.org/wikipedia/commons/6/68/%E9%AC%BC%E6%8A%BC%E5%87%BA%E3%81%97%E5%9C%92_-_panoramio_%281%29.jpg"; credit="SpringField1967 / CC BY-SA 3.0" },
  @{ path=".\media_assets\cache\onioshidashi\d1a00e68e8b0a5d2.jpg"; url="https://upload.wikimedia.org/wikipedia/commons/d/d0/Onioshidashien.jpg"; credit="Bmeg / CC BY-SA 3.0" }
)
foreach ($p in $photos) {
  if (-not (Test-Path $p.path)) {
    New-Item -ItemType Directory -Force (Split-Path $p.path -Parent) | Out-Null
    Invoke-WebRequest -Uri $p.url -OutFile $p.path
  }
}

function Txt([string]$name,[string]$value) {
  $p = Join-Path $work "$name.txt"
  [IO.File]::WriteAllText((Resolve-Path $work).Path + "\$name.txt",$value,(New-Object Text.UTF8Encoding($false)))
  return (Resolve-Path $p).Path.Replace("\","/").Replace(":","\:")
}
function MakePhoto([string]$src,[string]$out,[double]$dur,[string]$text,[int]$size=74) {
  $t=Txt ([IO.Path]::GetFileNameWithoutExtension($out)) $text
  & $ffmpeg -y -loop 1 -t $dur -i $src -vf "scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920,drawbox=x=0:y=0:w=iw:h=330:color=black@0.38:t=fill,drawtext=fontfile='$font':textfile='$t':fontcolor=white:fontsize=$size:x=(w-text_w)/2:y=120:line_spacing=18:borderw=3:bordercolor=black@0.35" -r 30 -c:v libx264 -pix_fmt yuv420p -an $out | Out-Null
}
function MakeCard([string]$out,[double]$dur,[string]$text,[int]$size=86) {
  $t=Txt ([IO.Path]::GetFileNameWithoutExtension($out)) $text
  & $ffmpeg -y -f lavfi -i "color=c=0x10162b:s=1080x1920:d=$dur:r=30" -vf "drawtext=fontfile='$font':textfile='$t':fontcolor=white:fontsize=$size:x=(w-text_w)/2:y=(h-text_h)/2:line_spacing=24:borderw=2:bordercolor=black@0.4" -c:v libx264 -pix_fmt yuv420p -an $out | Out-Null
}

$seg=@()
$seg += "$work\01.mp4"; MakePhoto $photos[0].path $seg[-1] 2.6 "この場所、どこ？"
$seg += "$work\02.mp4"; MakePhoto $photos[1].path $seg[-1] 2.4 "ヒントは、この景色。"
$seg += "$work\03.mp4"; MakePhoto $photos[2].path $seg[-1] 2.4 "3　　2　　1" 110
$seg += "$work\04.mp4"; MakeCard $seg[-1] 2.2 "正解は、、、" 104
$seg += "$work\05.mp4"; MakeCard $seg[-1] 2.8 "聖地クエストで確かめよう" 78

# Use a different real app-map capture so the quiz answer is not exposed.
# Crop 1080x2400 to the top 1920 px; this also removes the Media Studio panel.
$appText=Txt "app" "地図を頼りに、現地へ。"
& $ffmpeg -y -loop 1 -t 3.6 -i $app -vf "crop=1080:1920:0:0,drawbox=x=0:y=1560:w=iw:h=360:color=black@0.42:t=fill,drawtext=fontfile='$font':textfile='$appText':fontcolor=white:fontsize=70:x=(w-text_w)/2:y=1680:borderw=3:bordercolor=black@0.35" -r 30 -c:v libx264 -pix_fmt yuv420p -an "$work\06.mp4" | Out-Null
$seg += "$work\06.mp4"
$seg += "$work\07.mp4"; MakeCard $seg[-1] 2.4 "場所を巡って、集めよう。\n聖地クエスト" 76

$creditText = "写真: $($photos[0].credit) / $($photos[1].credit) / $($photos[2].credit)"
$seg += "$work\08.mp4"; MakeCard $seg[-1] 1.8 $creditText 34

$concat = Join-Path $work "concat.txt"
$lines = $seg | ForEach-Object { "file '$((Resolve-Path $_).Path.Replace("'","''"))'" }
[IO.File]::WriteAllLines((Resolve-Path $work).Path + "\concat.txt",$lines,(New-Object Text.UTF8Encoding($false)))
& $ffmpeg -y -f concat -safe 0 -i $concat -c copy $Output | Out-Null

Write-Host ""
Write-Host "=== TikTok prototype complete ===" -ForegroundColor Green
Get-Item $Output | Select-Object FullName,@{N="MB";E={[math]::Round($_.Length/1MB,2)}}
Write-Host "Duration target: 20.2 sec / 1080x1920 / 30fps"
