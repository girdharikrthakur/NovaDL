param(
  [string]$YtDlpUrl = "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe",
  [string]$FfmpegZipUrl = "https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-win64-gpl.zip",
  [string]$Destination = "third_party/dependencies/windows-x64/dependencies",
  [string]$YtDlpSha256 = "",
  [string]$FfmpegZipSha256 = ""
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

function Assert-Sha256 {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [string]$Expected
  )

  if ([string]::IsNullOrWhiteSpace($Expected)) {
    Write-Warning "No SHA-256 supplied for $Path. CI releases should pass pinned checksums."
    return
  }

  $actual = (Get-FileHash -Algorithm SHA256 -Path $Path).Hash.ToLowerInvariant()
  if ($actual -ne $Expected.ToLowerInvariant()) {
    throw "Checksum mismatch for $Path. Expected $Expected, got $actual."
  }
}

function Invoke-Download {
  param(
    [Parameter(Mandatory = $true)][string]$Uri,
    [Parameter(Mandatory = $true)][string]$OutFile
  )

  New-Item -ItemType Directory -Force -Path (Split-Path -Parent $OutFile) | Out-Null
  Invoke-WebRequest -Uri $Uri -OutFile $OutFile -UseBasicParsing
}

$root = Resolve-Path "."
$target = Join-Path $root $Destination
$ytDlpPath = Join-Path $target "yt-dlp/yt-dlp.exe"
$ffmpegRoot = Join-Path $target "ffmpeg"
$ffmpegBin = Join-Path $ffmpegRoot "bin"
$cache = Join-Path $root ".dependency-cache"
$ffmpegZip = Join-Path $cache "ffmpeg.zip"

New-Item -ItemType Directory -Force -Path $cache | Out-Null

Write-Host "Downloading yt-dlp..."
Invoke-Download -Uri $YtDlpUrl -OutFile $ytDlpPath
Assert-Sha256 -Path $ytDlpPath -Expected $YtDlpSha256

Write-Host "Downloading ffmpeg..."
Invoke-Download -Uri $FfmpegZipUrl -OutFile $ffmpegZip
Assert-Sha256 -Path $ffmpegZip -Expected $FfmpegZipSha256

if (Test-Path $ffmpegRoot) {
  Remove-Item -LiteralPath $ffmpegRoot -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $ffmpegBin | Out-Null

$extract = Join-Path $cache "ffmpeg-extract"
if (Test-Path $extract) {
  Remove-Item -LiteralPath $extract -Recurse -Force
}
Expand-Archive -Path $ffmpegZip -DestinationPath $extract -Force

$ffmpegExe = Get-ChildItem -Path $extract -Recurse -Filter "ffmpeg.exe" | Select-Object -First 1
$ffprobeExe = Get-ChildItem -Path $extract -Recurse -Filter "ffprobe.exe" | Select-Object -First 1

if ($null -eq $ffmpegExe -or $null -eq $ffprobeExe) {
  throw "ffmpeg archive did not contain ffmpeg.exe and ffprobe.exe."
}

Copy-Item -LiteralPath $ffmpegExe.FullName -Destination (Join-Path $ffmpegBin "ffmpeg.exe") -Force
Copy-Item -LiteralPath $ffprobeExe.FullName -Destination (Join-Path $ffmpegBin "ffprobe.exe") -Force

@{
  ytDlpUrl = $YtDlpUrl
  ytDlpSha256 = (Get-FileHash -Algorithm SHA256 -Path $ytDlpPath).Hash.ToLowerInvariant()
  ffmpegZipUrl = $FfmpegZipUrl
  ffmpegZipSha256 = (Get-FileHash -Algorithm SHA256 -Path $ffmpegZip).Hash.ToLowerInvariant()
  generatedAt = (Get-Date).ToUniversalTime().ToString("o")
} | ConvertTo-Json | Set-Content -Path (Join-Path $target "manifest.json") -Encoding UTF8

Write-Host "Bundled dependencies staged at $target"
