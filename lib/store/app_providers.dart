import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:rxdart/rxdart.dart';

import '../core/dependencies/dependency_locator.dart';
import '../core/logging/app_logger.dart';
import '../database/app_database.dart';
import '../download_engine/application/queue_manager.dart';
import '../download_engine/domain/download_engine_contract.dart';
import '../download_engine/domain/download_models.dart';
import '../download_engine/infrastructure/yt_dlp_service.dart';
import '../services/ffmpeg/ffmpeg_manager.dart';

final databaseProvider = FutureProvider<AppDatabase>((ref) async {
  final database = await AppDatabase.open();
  ref.onDispose(database.close);
  return database;
});

final loggerProvider = Provider.family<Logger, String>(
  (ref, name) => AppLogger.get(name),
);

final dependencyLocatorProvider = Provider<DependencyLocator>(
  (ref) => const DependencyLocator(),
);

final ytDlpExecutableProvider = FutureProvider<File>((ref) async {
  return ref.watch(dependencyLocatorProvider).resolveYtDlp();
});

final ffmpegExecutableProvider = FutureProvider<File?>((ref) async {
  final manager = FfmpegManager(
    locator: ref.watch(dependencyLocatorProvider),
    logger: ref.watch(loggerProvider('ffmpeg')),
  );
  return manager.detect();
});

final ytDlpServiceProvider = FutureProvider<YtDlpService>((ref) async {
  final executable = await ref.watch(ytDlpExecutableProvider.future);
  final ffmpeg = await ref.watch(ffmpegExecutableProvider.future);
  return YtDlpService(
    executable: executable,
    ffmpegExecutable: ffmpeg,
    logger: ref.watch(loggerProvider('yt-dlp')),
  );
});

final downloadEngineProvider = FutureProvider<DownloadEngine>((ref) async {
  final ytDlp = await ref.watch(ytDlpServiceProvider.future);
  final engine = QueueManager(
    ytDlp: ytDlp,
    logger: ref.watch(loggerProvider('queue')),
    onProgress: (progress) async {
      if (progress.status == DownloadStatus.completed) {
        await ref.read(mediaLibraryProvider.notifier).recordCompleted(progress);
      }
    },
    concurrentLimit: 3,
  );
  ref.onDispose(() => engine.shutdown());
  return engine;
});

final downloadProgressProvider = StreamProvider<DownloadProgress>((ref) async* {
  final engine = await ref.watch(downloadEngineProvider.future);
  yield* engine.progress;
});

final downloadQueueItemsProvider = StreamProvider<List<DownloadProgress>>((
  ref,
) async* {
  final engine = await ref.watch(downloadEngineProvider.future);
  yield const [];
  yield* engine.progress
      .scan<Map<String, DownloadProgress>>((items, event, _) {
        final previous = items[event.id];
        final merged = previous == null
            ? event
            : event.copyWith(
                percent: event.percent == 0 ? previous.percent : event.percent,
                speedBytesPerSecond: event.speedBytesPerSecond == 0
                    ? previous.speedBytesPerSecond
                    : event.speedBytesPerSecond,
                eta: event.eta ?? previous.eta,
                fragmentIndex: event.fragmentIndex ?? previous.fragmentIndex,
                fragmentCount: event.fragmentCount ?? previous.fragmentCount,
                completedFilePath:
                    event.completedFilePath ?? previous.completedFilePath,
              );
        return {...items, event.id: merged};
      }, <String, DownloadProgress>{})
      .map((items) {
        final values = items.values.toList(growable: false);
        return values.reversed.toList(growable: false);
      });
});

final mediaLibraryProvider =
    AsyncNotifierProvider<MediaLibraryController, List<AppMediaItem>>(
      MediaLibraryController.new,
    );

final class MediaLibraryController extends AsyncNotifier<List<AppMediaItem>> {
  @override
  Future<List<AppMediaItem>> build() async {
    final database = await ref.watch(databaseProvider.future);
    return database.mediaItems();
  }

  Future<void> reload({String query = ''}) async {
    final database = await ref.read(databaseProvider.future);
    state = AsyncData(database.mediaItems(query: query));
  }

  Future<void> recordCompleted(DownloadProgress item) async {
    final path = item.completedFilePath;
    if (path == null || path.isEmpty) return;
    final database = await ref.read(databaseProvider.future);
    database.recordCompletedMedia(
      id: item.id,
      filePath: path,
      title: item.message,
    );
    state = AsyncData(database.mediaItems());
  }
}

final dioProvider = Provider<Dio>((ref) {
  return Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(minutes: 5),
      sendTimeout: const Duration(minutes: 5),
    ),
  );
});
