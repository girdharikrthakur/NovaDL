import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

import '../core/errors/app_exception.dart';

enum DependencyChannel { stable, nightly }

enum DependencyComponent { ytDlp, ffmpeg }

final class DependencyRelease {
  const DependencyRelease({
    required this.version,
    required this.downloadUrl,
    required this.sha256,
    required this.channel,
  });

  final String version;
  final Uri downloadUrl;
  final String sha256;
  final DependencyChannel channel;
}

abstract interface class DependencyReleaseSource {
  Future<DependencyRelease?> latest(
    DependencyComponent component,
    DependencyChannel channel,
  );
}

final class DependencyUpdater {
  DependencyUpdater({
    required this.http,
    required this.releaseSource,
    required this.installDirectory,
    required this.logger,
  });

  final Dio http;
  final DependencyReleaseSource releaseSource;
  final Directory installDirectory;
  final Logger logger;

  Future<File?> update({
    required DependencyComponent component,
    required DependencyChannel channel,
    required String? currentVersion,
  }) async {
    final release = await releaseSource.latest(component, channel);
    if (release == null || release.version == currentVersion) return null;

    final componentDir = Directory(
      p.join(installDirectory.path, component.name),
    );
    final versionsDir = Directory(p.join(componentDir.path, 'versions'));
    await versionsDir.create(recursive: true);

    final target = File(p.join(versionsDir.path, '${release.version}.exe'));
    final temp = File('${target.path}.download');
    logger.info('Downloading ${component.name} ${release.version}');

    try {
      await http.downloadUri(release.downloadUrl, temp.path);
      final checksum = await _sha256(temp);
      if (checksum.toLowerCase() != release.sha256.toLowerCase()) {
        throw DependencyException(
          'Checksum verification failed for ${component.name}.',
          recoverable: false,
        );
      }
      if (target.existsSync()) await target.delete();
      await temp.rename(target.path);
      await File(
        p.join(componentDir.path, 'current.txt'),
      ).writeAsString(release.version);
      return target;
    } catch (error, stack) {
      logger.warning(
        'Dependency update failed; rolling back to prior executable.',
        error,
        stack,
      );
      if (temp.existsSync()) await temp.delete();
      rethrow;
    }
  }

  Future<void> rollback(DependencyComponent component, String version) async {
    final currentFile = File(
      p.join(installDirectory.path, component.name, 'current.txt'),
    );
    await currentFile.writeAsString(version);
  }

  Future<String> _sha256(File file) async {
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString();
  }
}
