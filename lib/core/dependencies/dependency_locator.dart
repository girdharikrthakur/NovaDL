import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

final class DependencyLocator {
  const DependencyLocator();

  Future<File> resolveYtDlp() async {
    final updated = await _updatedVersionedExecutable('ytDlp');
    if (updated != null) return updated;

    final legacyUpdated = await _supportFile(['yt-dlp', 'yt-dlp.exe']);
    if (legacyUpdated.existsSync()) return legacyUpdated;

    return _bundledFile(['yt-dlp', 'yt-dlp.exe']);
  }

  Future<File?> resolveFfmpeg({String? customPath}) async {
    if (customPath != null && File(customPath).existsSync()) {
      return File(customPath);
    }

    final updated = await _updatedVersionedExecutable('ffmpeg');
    if (updated != null) return updated;

    final bundled = _bundledFile(['ffmpeg', 'bin', 'ffmpeg.exe']);
    if (bundled.existsSync()) return bundled;

    final portable = _bundledFile(['ffmpeg', 'ffmpeg.exe']);
    if (portable.existsSync()) return portable;

    return null;
  }

  Directory bundledRoot() {
    return Directory(
      p.join(File(Platform.resolvedExecutable).parent.path, 'dependencies'),
    );
  }

  Future<Directory> supportRoot() async {
    final support = await getApplicationSupportDirectory();
    return Directory(p.join(support.path, 'NovaDL', 'dependencies'));
  }

  File _bundledFile(List<String> parts) {
    return File(p.joinAll([bundledRoot().path, ...parts]));
  }

  Future<File> _supportFile(List<String> parts) async {
    final root = await supportRoot();
    return File(p.joinAll([root.path, ...parts]));
  }

  Future<File?> _updatedVersionedExecutable(String component) async {
    final root = await supportRoot();
    final currentFile = File(p.join(root.path, component, 'current.txt'));
    if (!currentFile.existsSync()) return null;

    final version = currentFile.readAsStringSync().trim();
    if (version.isEmpty) return null;

    final executable = File(
      p.join(root.path, component, 'versions', '$version.exe'),
    );
    return executable.existsSync() ? executable : null;
  }
}
