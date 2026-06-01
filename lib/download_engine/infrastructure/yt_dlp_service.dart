import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:rxdart/rxdart.dart';

import '../../core/errors/app_exception.dart';
import '../../core/security/path_guard.dart';
import '../domain/download_models.dart';

final class YtDlpProcessHandle {
  YtDlpProcessHandle(this.process, this.progress);

  final Process process;
  final Stream<DownloadProgress> progress;

  Future<void> kill() async {
    process.kill(ProcessSignal.sigterm);
    await process.exitCode.timeout(
      const Duration(seconds: 4),
      onTimeout: () {
        process.kill(ProcessSignal.sigkill);
        return -1;
      },
    );
  }
}

final class YtDlpService {
  YtDlpService({
    required this.executable,
    this.ffmpegExecutable,
    required this.logger,
  });

  final File executable;
  final File? ffmpegExecutable;
  final Logger logger;
  final _outputPaths = <String, String>{};

  Future<String> version() async {
    final result = await Process.run(executable.path, const [
      '--version',
    ], runInShell: false);
    if (result.exitCode != 0) {
      throw DependencyException(
        'yt-dlp version check failed.',
        cause: result.stderr,
      );
    }
    return result.stdout.toString().trim();
  }

  Future<Map<String, Object?>> analyze(Uri url) async {
    final args = PathGuard.sanitizeArguments([
      '--dump-single-json',
      '--no-warnings',
      url.toString(),
    ]);
    final result = await Process.run(executable.path, args, runInShell: false);
    if (result.exitCode != 0) {
      throw DownloadException(
        'Metadata extraction failed.',
        cause: result.stderr,
      );
    }
    return jsonDecode(result.stdout.toString()) as Map<String, Object?>;
  }

  Future<List<PlaylistVideo>> analyzePlaylist(Uri url) async {
    final args = PathGuard.sanitizeArguments([
      '--dump-single-json',
      '--flat-playlist',
      '--ignore-no-formats-error',
      '--no-warnings',
      url.toString(),
    ]);
    final result = await Process.run(executable.path, args, runInShell: false);
    if (result.exitCode != 0) {
      throw DownloadException(
        'Playlist extraction failed.',
        cause: result.stderr,
      );
    }
    final metadata =
        jsonDecode(result.stdout.toString()) as Map<String, Object?>;
    final entries = metadata['entries'];
    if (entries is! List<Object?> || entries.isEmpty) {
      return const [];
    }

    return entries.indexed
        .map((entry) {
          final position = entry.$1 + 1;
          final value = entry.$2;
          final data = value is Map<String, Object?>
              ? value
              : <String, Object?>{};
          final seconds = data['duration'];
          return PlaylistVideo(
            index: position,
            id: data['id']?.toString() ?? position.toString(),
            title:
                data['title']?.toString() ??
                data['webpage_url']?.toString() ??
                'Video $position',
            duration: seconds is num
                ? Duration(seconds: seconds.round())
                : null,
            thumbnail: data['thumbnail']?.toString(),
          );
        })
        .toList(growable: false);
  }

  Future<YtDlpProcessHandle> start(DownloadRequest request) async {
    final args = <String>[
      '--newline',
      '--progress-template',
      'download:%(progress._percent_str)s|%(progress._speed_str)s|%(progress._eta_str)s|%(progress.fragment_index)s|%(progress.fragment_count)s',
      '--paths',
      request.outputDirectory.path,
      '--retries',
      request.maxRetries.toString(),
      '--fragment-retries',
      '10',
      '--retry-sleep',
      'linear=2::20',
      '--continue',
      '--no-overwrites',
      if (ffmpegExecutable != null) ...[
        '--ffmpeg-location',
        ffmpegExecutable!.parent.path,
      ],
      if (request.bandwidthLimit != null) ...[
        '--limit-rate',
        request.bandwidthLimit!,
      ],
      ...request.selection.toYtDlpArgs(),
      ...request.extraArgs,
      request.url.toString(),
    ];

    final process = await Process.start(
      executable.path,
      PathGuard.sanitizeArguments(args),
      runInShell: false,
      workingDirectory: request.outputDirectory.path,
    );

    final stdoutLines = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter());
    final stderrLines = process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter());
    final controller = BehaviorSubject<DownloadProgress>();

    stdoutLines.listen(
      (line) =>
          _parseProgress(request.id, line, controller, request.outputDirectory),
      onError: (Object error, StackTrace stack) =>
          logger.warning('yt-dlp stdout failed', error, stack),
    );
    stderrLines.listen(
      (line) {
        logger.info('yt-dlp: $line');
        controller.add(
          DownloadProgress(
            id: request.id,
            status: DownloadStatus.running,
            stage: 'yt-dlp',
            message: line,
          ),
        );
      },
      onError: (Object error, StackTrace stack) =>
          logger.warning('yt-dlp stderr failed', error, stack),
    );

    unawaited(
      process.exitCode.then((code) {
        if (code == 0) {
          controller.add(
            DownloadProgress(
              id: request.id,
              status: DownloadStatus.completed,
              percent: 100,
              stage: 'Complete',
              completedFilePath: _outputPaths[request.id],
            ),
          );
        } else {
          controller.add(
            DownloadProgress(
              id: request.id,
              status: DownloadStatus.failed,
              stage: 'Failed',
              message: 'yt-dlp exited with $code',
            ),
          );
        }
        unawaited(controller.close());
      }),
    );

    return YtDlpProcessHandle(process, controller.stream);
  }

  void _parseProgress(
    String id,
    String line,
    Sink<DownloadProgress> sink,
    Directory outputDirectory,
  ) {
    final normalizedLine = line
        .replaceAll('\r', '')
        .replaceAll('\u001b[K', '')
        .trim();
    if (!normalizedLine.startsWith('download:')) {
      final outputPath = _extractOutputPath(normalizedLine, outputDirectory);
      if (outputPath != null) {
        _outputPaths[id] = outputPath;
      }
      sink.add(
        DownloadProgress(
          id: id,
          status: DownloadStatus.running,
          stage: _stageFromLine(normalizedLine),
          message: normalizedLine,
          completedFilePath: outputPath,
        ),
      );
      return;
    }

    final parts = normalizedLine.substring('download:'.length).split('|');
    final percent =
        double.tryParse(parts.first.replaceAll('%', '').trim()) ?? 0;
    sink.add(
      DownloadProgress(
        id: id,
        status: DownloadStatus.running,
        percent: percent.clamp(0, 100),
        speedBytesPerSecond: _parseSpeed(parts.elementAtOrNull(1)),
        eta: _parseEta(parts.elementAtOrNull(2)),
        fragmentIndex: int.tryParse(parts.elementAtOrNull(3) ?? ''),
        fragmentCount: int.tryParse(parts.elementAtOrNull(4) ?? ''),
        stage: 'Downloading',
        completedFilePath: _outputPaths[id],
      ),
    );
  }

  String? _extractOutputPath(String line, Directory outputDirectory) {
    final patterns = [
      RegExp(r'Destination:\s+"?(.+?)"?$'),
      RegExp(r'Merging formats into\s+"?(.+?)"?$'),
      RegExp(r'\[download\]\s+(.+?)\s+has already been downloaded'),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(line);
      if (match != null) {
        final raw = match.group(1)?.trim().replaceAll(RegExp(r'^"|"$'), '');
        if (raw == null || raw.isEmpty) return null;
        return p.isAbsolute(raw) ? raw : p.join(outputDirectory.path, raw);
      }
    }
    return null;
  }

  String _stageFromLine(String line) {
    if (line.contains('[ExtractAudio]')) return 'Extracting audio';
    if (line.contains('[Merger]')) return 'Merging';
    if (line.contains('[Metadata]')) return 'Embedding metadata';
    if (line.contains('[download]')) return 'Downloading';
    return 'Processing';
  }

  int _parseSpeed(String? raw) {
    if (raw == null || raw == 'NA') return 0;
    final cleaned = raw.trim().replaceAll(' ', '');
    if (cleaned == 'NA' || cleaned.isEmpty) return 0;
    final match = RegExp(
      r'([\d.]+)([KMGT]?i?B|[KMGT]?B|B)/s',
      caseSensitive: false,
    ).firstMatch(cleaned);
    if (match == null) return 0;
    final value = double.tryParse(match.group(1) ?? '') ?? 0;
    final unit = (match.group(2) ?? 'B').toUpperCase();
    final multiplier = switch (unit) {
      'KIB' || 'KB' => 1024,
      'MIB' || 'MB' => 1024 * 1024,
      'GIB' || 'GB' => 1024 * 1024 * 1024,
      'TIB' || 'TB' => 1024 * 1024 * 1024 * 1024,
      _ => 1,
    };
    return (value * multiplier).round();
  }

  Duration? _parseEta(String? raw) {
    if (raw == null || raw == 'NA') return null;
    final parts = raw.split(':').map(int.tryParse).toList();
    if (parts.any((part) => part == null)) return null;
    return switch (parts.length) {
      2 => Duration(minutes: parts[0]!, seconds: parts[1]!),
      3 => Duration(hours: parts[0]!, minutes: parts[1]!, seconds: parts[2]!),
      _ => null,
    };
  }
}
