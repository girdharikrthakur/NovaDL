import 'dart:io';

final class FileLauncher {
  const FileLauncher._();

  static Future<void> openDefault(String path) async {
    if (!File(path).existsSync()) return;
    if (Platform.isWindows) {
      await Process.run('cmd.exe', [
        '/c',
        'start',
        '',
        path,
      ], runInShell: false);
      return;
    }
    if (Platform.isMacOS) {
      await Process.start('open', [path], runInShell: false);
      return;
    }
    await Process.start('xdg-open', [path], runInShell: false);
  }

  static Future<void> openWith(String playerPath, String mediaPath) async {
    if (!File(playerPath).existsSync() || !File(mediaPath).existsSync()) return;
    if (Platform.isWindows) {
      await Process.run('cmd.exe', [
        '/c',
        'start',
        '',
        playerPath,
        mediaPath,
      ], runInShell: false);
      return;
    }
    await Process.start(playerPath, [mediaPath], runInShell: false);
  }
}
