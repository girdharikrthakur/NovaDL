import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

final class AppMediaItem {
  const AppMediaItem({
    required this.id,
    required this.filePath,
    required this.title,
    required this.mediaType,
    required this.createdAt,
  });

  final String id;
  final String filePath;
  final String title;
  final String mediaType;
  final DateTime createdAt;
}

final class AppDatabase {
  AppDatabase._(this._db);

  final Database _db;

  static Future<AppDatabase> open() async {
    final support = await getApplicationSupportDirectory();
    final dir = Directory(p.join(support.path, 'NovaDL'));
    await dir.create(recursive: true);
    final db = sqlite3.open(p.join(dir.path, 'novadl.sqlite'));
    final database = AppDatabase._(db);
    database.migrate();
    return database;
  }

  void migrate() {
    _db.execute('PRAGMA foreign_keys = ON;');
    _db.execute('PRAGMA journal_mode = WAL;');
    _db.execute(_schema);
    _addColumnIfMissing(
      'media_items',
      'media_type',
      "TEXT NOT NULL DEFAULT 'video'",
    );
  }

  void _addColumnIfMissing(String table, String column, String definition) {
    final columns = _db.select('PRAGMA table_info($table)');
    final exists = columns.any((row) => row['name'] == column);
    if (!exists) {
      _db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
    }
  }

  ResultSet recentDownloads({int limit = 100}) {
    return _db.select(
      'SELECT * FROM downloads ORDER BY created_at DESC LIMIT ?',
      [limit],
    );
  }

  String? setting(String key) {
    final rows = _db.select(
      'SELECT value_json FROM app_settings WHERE key = ? LIMIT 1',
      [key],
    );
    if (rows.isEmpty) return null;
    return rows.first['value_json'] as String?;
  }

  void saveSetting(String key, String valueJson) {
    _db.execute(
      '''
      INSERT OR REPLACE INTO app_settings (key, value_json, updated_at)
      VALUES (?, ?, ?)
      ''',
      [key, valueJson, DateTime.now().toIso8601String()],
    );
  }

  List<AppMediaItem> mediaItems({String query = '', int limit = 1000}) {
    final normalizedQuery = query.trim().toLowerCase();
    final rows = normalizedQuery.isEmpty
        ? _db.select(
            'SELECT id, file_path, title, media_type, created_at FROM media_items ORDER BY created_at DESC LIMIT ?',
            [limit],
          )
        : _db.select(
            '''
            SELECT id, file_path, title, media_type, created_at
            FROM media_items
            WHERE lower(title) LIKE ? OR lower(file_path) LIKE ?
            ORDER BY created_at DESC
            LIMIT ?
            ''',
            ['%$normalizedQuery%', '%$normalizedQuery%', limit],
          );

    return rows
        .map(
          (row) => AppMediaItem(
            id: row['id'] as String,
            filePath: row['file_path'] as String,
            title:
                row['title'] as String? ??
                p.basename(row['file_path'] as String),
            mediaType:
                row['media_type'] as String? ??
                _mediaTypeForPath(row['file_path'] as String),
            createdAt:
                DateTime.tryParse(row['created_at'] as String) ??
                DateTime.now(),
          ),
        )
        .toList(growable: false);
  }

  void recordCompletedMedia({
    required String id,
    required String filePath,
    String? title,
    String? mediaType,
  }) {
    final now = DateTime.now().toIso8601String();
    final resolvedTitle = title?.trim().isNotEmpty ?? false
        ? title!.trim()
        : p.basename(filePath);
    final resolvedMediaType = mediaType ?? _mediaTypeForPath(filePath);
    _db.execute(
      '''
      INSERT OR REPLACE INTO downloads
      (id, url, title, status, kind, output_path, progress, priority, retry_count, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, COALESCE((SELECT created_at FROM downloads WHERE id = ?), ?), ?)
      ''',
      [
        id,
        '',
        resolvedTitle,
        'completed',
        'video',
        p.dirname(filePath),
        100.0,
        1,
        0,
        id,
        now,
        now,
      ],
    );
    _db.execute(
      '''
      INSERT OR REPLACE INTO media_items
      (id, download_id, file_path, title, media_type, thumbnail_path, metadata_json, tags_csv, created_at)
      VALUES (?, ?, ?, ?, ?, NULL, NULL, '', COALESCE((SELECT created_at FROM media_items WHERE id = ?), ?))
      ''',
      [id, id, filePath, resolvedTitle, resolvedMediaType, id, now],
    );
  }

  String _mediaTypeForPath(String filePath) {
    final ext = p.extension(filePath).toLowerCase();
    const audio = {'.mp3', '.m4a', '.opus', '.ogg', '.wav', '.flac', '.aac'};
    return audio.contains(ext) ? 'audio' : 'video';
  }

  void close() => _db.dispose();
}

const _schema = '''
CREATE TABLE IF NOT EXISTS downloads (
  id TEXT PRIMARY KEY,
  url TEXT NOT NULL,
  title TEXT,
  status TEXT NOT NULL,
  kind TEXT NOT NULL,
  output_path TEXT NOT NULL,
  progress REAL NOT NULL DEFAULT 0,
  priority INTEGER NOT NULL DEFAULT 1,
  retry_count INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_downloads_status ON downloads(status);
CREATE INDEX IF NOT EXISTS idx_downloads_created_at ON downloads(created_at);

CREATE TABLE IF NOT EXISTS media_items (
  id TEXT PRIMARY KEY,
  download_id TEXT NOT NULL REFERENCES downloads(id) ON DELETE CASCADE,
  file_path TEXT NOT NULL,
  title TEXT,
  media_type TEXT NOT NULL DEFAULT 'video',
  thumbnail_path TEXT,
  metadata_json TEXT,
  tags_csv TEXT NOT NULL DEFAULT '',
  created_at TEXT NOT NULL
);

CREATE VIRTUAL TABLE IF NOT EXISTS media_search USING fts5(
  title,
  tags,
  metadata,
  content=''
);

CREATE TABLE IF NOT EXISTS subscriptions (
  id TEXT PRIMARY KEY,
  url TEXT NOT NULL,
  name TEXT NOT NULL,
  schedule_cron TEXT NOT NULL,
  keyword_filter TEXT,
  enabled INTEGER NOT NULL DEFAULT 1,
  last_checked_at TEXT
);

CREATE TABLE IF NOT EXISTS app_settings (
  key TEXT PRIMARY KEY,
  value_json TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS logs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  scope TEXT NOT NULL,
  level TEXT NOT NULL,
  message TEXT NOT NULL,
  context_json TEXT,
  created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS update_history (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  component TEXT NOT NULL,
  channel TEXT NOT NULL,
  from_version TEXT,
  to_version TEXT NOT NULL,
  checksum TEXT NOT NULL,
  status TEXT NOT NULL,
  created_at TEXT NOT NULL
);
''';
