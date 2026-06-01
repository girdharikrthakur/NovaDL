import 'dart:io';

import 'package:path/path.dart' as p;

import '../errors/app_exception.dart';

final class PathGuard {
  const PathGuard({required this.allowedRoots});

  final List<Directory> allowedRoots;

  Future<File> validateWritableFile(String rawPath) async {
    final normalized = p.normalize(p.absolute(rawPath));
    final isAllowed = allowedRoots.any((root) {
      final rootPath = p.normalize(p.absolute(root.path));
      return p.isWithin(rootPath, normalized) ||
          rootPath == p.dirname(normalized);
    });
    if (!isAllowed) {
      throw const SecurityException(
        'Path is outside configured download roots.',
      );
    }
    return File(normalized);
  }

  static List<String> sanitizeArguments(Iterable<String> args) {
    return args
        .map((arg) {
          if (arg.contains('\x00') ||
              arg.contains('\n') ||
              arg.contains('\r')) {
            throw const SecurityException('Unsafe process argument rejected.');
          }
          return arg;
        })
        .toList(growable: false);
  }
}
