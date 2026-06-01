# NovaDL

NovaDL is a modern Windows-first desktop downloader for `yt-dlp`, built with Flutter. It is designed to feel like a real desktop product: fast queueing, playlist selection, bundled dependencies, a persistent media library, polished theming, and safe process execution.

NovaDL is inspired by tools like Stacher, but the goal is not to be a thin wrapper. The app has its own queue engine, SQLite-backed library, dependency management, settings system, and extensible architecture.

![NovaDL logo](assets/icons/novadl_logo.png)

## Highlights

- Download videos, audio, playlists, channels, and livestreams through `yt-dlp`.
- Ships with portable `yt-dlp.exe`, `ffmpeg.exe`, and `ffprobe.exe` in release builds.
- Select video quality, codec, container, subtitles, thumbnails, and metadata options.
- Choose **Best available** or a fixed resolution such as `2160p`, `1440p`, `1080p`, or `720p`.
- Detect playlists and open an animated picker to choose exactly which videos to download.
- Run concurrent downloads with queue progress, retry handling, cancel/stop controls, and stop-all.
- Persist completed downloads in a SQLite media library.
- Open downloaded videos from the app or with a preferred external player.
- Configure theme mode, full app color, accent color, and predefined theme presets.
- Use secure process execution: no shell wrapping, sanitized arguments, and path-aware dependency lookup.

## Current Status

NovaDL is in early desktop-app development. The Windows build, UI shell, bundled dependency pipeline, download queue, playlist selector, and media-library persistence are implemented. Some advanced features are scaffolded for future expansion, including automatic dependency rollback history, subscriptions, richer metadata indexing, and full installer publishing.

## Screens

Suggested GitHub screenshot locations:

```text
docs/screenshots/dashboard.png
docs/screenshots/downloads.png
docs/screenshots/library.png
docs/screenshots/settings.png
```

Add screenshots there and reference them like this:

```md
![Dashboard](docs/screenshots/dashboard.png)
```

## Tech Stack

- Flutter desktop for the Windows UI
- Dart for app logic and services
- Riverpod for state management
- SQLite via `sqlite3` for persistent app data
- `yt-dlp` for extraction and downloads
- `ffmpeg` for merging, conversion, and media processing
- PowerShell scripts for dependency staging and Windows packaging
- GitHub Actions for Windows CI/release builds

## Repository Layout

```text
lib/
  core/                 Shared errors, logging, dependency lookup, security, themes
  database/             SQLite schema and media-library persistence
  download_engine/      Queue engine, download contracts, yt-dlp process adapter
  services/             ffmpeg and subscription services
  store/                Riverpod providers and settings controller
  ui/                   App shell, pages, reusable components
  updater/              Dependency updater scaffolding

assets/
  icons/                NovaDL logo and app assets

windows/                Flutter Windows runner and executable resources
packaging/              Installer/appcast configuration
scripts/                Dependency fetch and packaging scripts
third_party/            Locally staged release dependencies
```

## How Downloads Work

1. Paste a video or playlist URL.
2. Choose output folder, quality, codec, container, and optional extras.
3. If the URL is a playlist, NovaDL asks `yt-dlp` for a flat playlist listing.
4. The animated picker lets you select all or specific videos.
5. NovaDL enqueues a typed download request.
6. The queue manager starts `yt-dlp` without shell execution.
7. Progress is parsed from `yt-dlp` output and shown in the Downloads page.
8. Completed files are saved into SQLite and appear in the Media Library.

## Bundled Dependencies

Release builds copy dependencies beside `novadl.exe`:

```text
dependencies/
  yt-dlp/
    yt-dlp.exe
  ffmpeg/
    bin/
      ffmpeg.exe
      ffprobe.exe
```

Runtime lookup order:

1. App-updated dependency in the user support directory
2. Bundled dependency beside `novadl.exe`
3. System-installed fallback where applicable, such as `where ffmpeg`

The staged binary files are ignored by Git so the repository stays lightweight. CI and local packaging can download them on demand.

## Requirements

- Windows 10 or newer
- Flutter stable with Windows desktop enabled
- Visual Studio Build Tools with the Desktop development with C++ workload
- PowerShell 5+ or PowerShell 7+
- Internet access when staging `yt-dlp` and `ffmpeg`

Check Flutter:

```powershell
flutter doctor
```

Enable Windows desktop if needed:

```powershell
flutter config --enable-windows-desktop
```

## Build From Source

Clone the repository:

```powershell
git clone https://github.com/YOUR_USERNAME/novadl.git
cd novadl
```

Install Dart/Flutter packages:

```powershell
flutter pub get
```

Stage bundled `yt-dlp` and `ffmpeg`:

```powershell
.\scripts\fetch_dependencies.ps1
```

Run the app:

```powershell
flutter run -d windows
```

Build a release executable:

```powershell
flutter build windows --release
```

The output is created at:

```text
build/windows/x64/runner/Release/novadl.exe
```

## Package Windows Builds

Run:

```powershell
.\scripts\package_windows.ps1
```

This script:

1. Runs `flutter pub get`
2. Downloads/stages `yt-dlp` and `ffmpeg`
3. Builds the Windows release
4. Runs Inno Setup if `iscc` is installed

For reproducible commercial or CI releases, pass pinned checksums:

```powershell
.\scripts\package_windows.ps1 `
  -YtDlpSha256 "YOUR_YTDLP_SHA256" `
  -FfmpegZipSha256 "YOUR_FFMPEG_ZIP_SHA256"
```

If checksums are omitted, the script still works but prints a warning.

## GitHub Actions

The workflow at `.github/workflows/windows-release.yml` builds NovaDL on Windows.

It runs:

- `flutter pub get`
- dependency staging
- `flutter analyze`
- `flutter test`
- `flutter build windows --release`
- portable ZIP artifact creation

Tag releases with:

```powershell
git tag v0.1.0
git push origin v0.1.0
```

## Settings

NovaDL currently supports:

- Download folder
- Concurrent download setting
- Stable/nightly yt-dlp channel preference
- Auto-update toggles for yt-dlp and ffmpeg
- Dependency check for bundled tools
- Custom `ffmpeg.exe`
- Preferred external video player
- Proxy URL
- Cookies file
- Debug logging
- Start minimized
- Theme preset
- System/dark/light mode
- Overall app color
- Accent color

## Security Model

NovaDL treats media download URLs and command arguments as untrusted input.

- `yt-dlp` and `ffmpeg` are launched with `Process.start` / `Process.run`.
- `runInShell` is disabled.
- Arguments are passed as lists, not concatenated command strings.
- Unsafe newline/null arguments are rejected.
- Download output paths are modeled explicitly.
- Dependency checksums are supported during staging and updater workflows.

## Troubleshooting

### The app says yt-dlp is missing

Run:

```powershell
.\scripts\fetch_dependencies.ps1
flutter build windows --release
```

Then check:

```text
build/windows/x64/runner/Release/dependencies/yt-dlp/yt-dlp.exe
```

### ffmpeg is not detected

Make sure the release folder contains:

```text
dependencies/ffmpeg/bin/ffmpeg.exe
dependencies/ffmpeg/bin/ffprobe.exe
```

You can also set a custom ffmpeg path in Settings.

### Playlist selection does not appear

NovaDL opens the selector only when `yt-dlp --flat-playlist` returns playlist entries. If extraction fails, NovaDL falls back to a normal download and shows a message.

### Media disappears after restart

Completed items are persisted to SQLite. If you built an older version, rebuild the latest source and complete a new download so the library can record it.

## Development Commands

Format:

```powershell
dart format lib test
```

Analyze:

```powershell
flutter analyze
```

Test:

```powershell
flutter test
```

Build:

```powershell
flutter build windows --release
```

## Roadmap

- Rich metadata and thumbnail indexing
- Subscription/watchers for channels and playlists
- Automatic yt-dlp update scheduling
- Automatic ffmpeg update scheduling
- Dependency rollback UI
- Download history filters
- SponsorBlock integration
- Chapter editing
- Transcoding profiles
- Browser extension integration
- Cloud sync and remote download control

## Contributing

Issues and pull requests are welcome. Please keep changes focused and run the validation commands before submitting:

```powershell
dart format lib test
flutter analyze
flutter test
```

For changes that touch packaging or dependencies, also run:

```powershell
.\scripts\package_windows.ps1
```

## License

Add your chosen license before publishing publicly. Common options are MIT, Apache-2.0, and GPL-3.0. Note that bundled dependency licensing should be reviewed before commercial distribution, especially the selected ffmpeg build.

## Credits

NovaDL is powered by:

- [`yt-dlp`](https://github.com/yt-dlp/yt-dlp)
- [`FFmpeg`](https://ffmpeg.org/)
- [`Flutter`](https://flutter.dev/)
