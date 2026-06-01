param(
  [string]$Configuration = "Release",
  [switch]$SkipDependencyFetch,
  [string]$YtDlpSha256 = "",
  [string]$FfmpegZipSha256 = ""
)

$ErrorActionPreference = "Stop"

flutter pub get

if (-not $SkipDependencyFetch) {
  & ".\scripts\fetch_dependencies.ps1" `
    -YtDlpSha256 $YtDlpSha256 `
    -FfmpegZipSha256 $FfmpegZipSha256
}

flutter build windows --release

if (Get-Command iscc -ErrorAction SilentlyContinue) {
  iscc ".\packaging\inno_setup.iss"
} else {
  Write-Warning "Inno Setup Compiler was not found. Windows build completed; installer was skipped."
}
