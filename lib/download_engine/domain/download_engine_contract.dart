import 'dart:async';

import 'download_models.dart';

abstract interface class DownloadEngine {
  Stream<DownloadProgress> get progress;
  Future<void> enqueue(DownloadRequest request);
  Future<void> pause(String id);
  Future<void> resume(String id);
  Future<void> cancel(String id);
  Future<void> cancelAll();
  Future<void> reprioritize(String id, DownloadPriority priority);
  Future<void> recoverUnfinished();
  Future<void> shutdown();
}
