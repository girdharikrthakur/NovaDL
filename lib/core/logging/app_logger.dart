import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

final class AppLogger {
  AppLogger._();

  static bool _configured = false;

  static void configure({required bool debugMode}) {
    if (_configured) return;
    _configured = true;
    Logger.root.level = debugMode ? Level.ALL : Level.INFO;
    Logger.root.onRecord.listen((record) async {
      final payload = jsonEncode({
        'ts': record.time.toIso8601String(),
        'level': record.level.name,
        'logger': record.loggerName,
        'message': record.message,
        'error': record.error?.toString(),
        'stack': record.stackTrace?.toString(),
      });
      // Keep console logs structured for crash-report ingestion.
      // ignore: avoid_print
      print(payload);
      await _append(payload);
    });
  }

  static Logger get(String name) => Logger(name);

  static Future<File> exportLogFile() async {
    final dir = await _logDir();
    return File(p.join(dir.path, 'novadl.log'));
  }

  static Future<void> _append(String line) async {
    try {
      final file = await exportLogFile();
      await file.writeAsString('$line\n', mode: FileMode.append, flush: false);
    } catch (_) {
      // Logging must never take down the app.
    }
  }

  static Future<Directory> _logDir() async {
    final support = await getApplicationSupportDirectory();
    final dir = Directory(p.join(support.path, 'NovaDL', 'logs'));
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    return dir;
  }
}
