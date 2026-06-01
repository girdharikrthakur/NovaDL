import 'dart:io';

import 'package:logging/logging.dart';

import '../../core/dependencies/dependency_locator.dart';

final class FfmpegManager {
  FfmpegManager({required this.locator, required this.logger});

  final DependencyLocator locator;
  final Logger logger;

  Future<File?> detect({String? customPath}) async {
    final bundledOrCustom = await locator.resolveFfmpeg(customPath: customPath);
    if (bundledOrCustom != null) {
      return bundledOrCustom;
    }
    final result = await Process.run('where', const [
      'ffmpeg',
    ], runInShell: false);
    if (result.exitCode == 0) {
      final candidates = result.stdout
          .toString()
          .split(RegExp(r'\r?\n'))
          .where((line) => line.trim().isNotEmpty);
      final first = candidates.isEmpty ? null : candidates.first;
      if (first != null) return File(first.trim());
    }
    logger.info('ffmpeg not detected; updater can install portable ffmpeg.');
    return null;
  }
}
