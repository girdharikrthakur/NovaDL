import 'dart:async';

import 'package:logging/logging.dart';
import 'package:rxdart/rxdart.dart';

import '../../core/errors/app_exception.dart';
import '../domain/download_engine_contract.dart';
import '../domain/download_models.dart';
import '../infrastructure/yt_dlp_service.dart';

final class QueueManager implements DownloadEngine {
  QueueManager({
    required YtDlpService ytDlp,
    required Logger logger,
    Future<void> Function(DownloadProgress progress)? onProgress,
    this.concurrentLimit = 3,
  }) : _ytDlp = ytDlp,
       _logger = logger,
       _onProgress = onProgress;

  final YtDlpService _ytDlp;
  final Logger _logger;
  final Future<void> Function(DownloadProgress progress)? _onProgress;
  final int concurrentLimit;
  final _progress = BehaviorSubject<DownloadProgress>();
  final _queued = <DownloadRequest>[];
  final _running = <String, YtDlpProcessHandle>{};
  final _requests = <String, DownloadRequest>{};
  final _paused = <String>{};
  bool _draining = false;

  @override
  Stream<DownloadProgress> get progress => _progress.stream;

  @override
  Future<void> enqueue(DownloadRequest request) async {
    _requests[request.id] = request;
    if (request.scheduledAt != null &&
        request.scheduledAt!.isAfter(DateTime.now())) {
      _progress.add(
        DownloadProgress(
          id: request.id,
          status: DownloadStatus.scheduled,
          stage: 'Scheduled',
        ),
      );
      Timer(request.scheduledAt!.difference(DateTime.now()), () {
        _queued.add(request);
        unawaited(_drain());
      });
      return;
    }
    _enqueueByPriority(request);
    _progress.add(
      DownloadProgress(
        id: request.id,
        status: DownloadStatus.queued,
        stage: 'Queued',
      ),
    );
    await _drain();
  }

  @override
  Future<void> pause(String id) async {
    _paused.add(id);
    final handle = _running.remove(id);
    if (handle != null) {
      await handle.kill();
      _progress.add(
        DownloadProgress(
          id: id,
          status: DownloadStatus.paused,
          stage: 'Paused',
        ),
      );
    }
  }

  @override
  Future<void> resume(String id) async {
    final request = _requests[id];
    if (request == null) return;
    _paused.remove(id);
    _enqueueByPriority(request);
    _progress.add(
      DownloadProgress(id: id, status: DownloadStatus.queued, stage: 'Queued'),
    );
    await _drain();
  }

  @override
  Future<void> cancel(String id) async {
    _paused.remove(id);
    _requests.remove(id);
    final handle = _running.remove(id);
    if (handle != null) await handle.kill();
    _progress.add(
      DownloadProgress(
        id: id,
        status: DownloadStatus.canceled,
        stage: 'Canceled',
      ),
    );
    await _drain();
  }

  @override
  Future<void> cancelAll() async {
    _queued.clear();
    final ids = {..._requests.keys};
    for (final id in ids) {
      await cancel(id);
    }
  }

  @override
  Future<void> reprioritize(String id, DownloadPriority priority) async {
    final existing = _requests[id];
    if (existing == null) return;
    final updated = DownloadRequest(
      id: existing.id,
      url: existing.url,
      outputDirectory: existing.outputDirectory,
      kind: existing.kind,
      priority: priority,
      selection: existing.selection,
      scheduledAt: existing.scheduledAt,
      maxRetries: existing.maxRetries,
      bandwidthLimit: existing.bandwidthLimit,
      extraArgs: existing.extraArgs,
    );
    _requests[id] = updated;
    _queued.removeWhere((request) => request.id == id);
    _enqueueByPriority(updated);
    await _drain();
  }

  @override
  Future<void> recoverUnfinished() async {
    _logger.info(
      'Recovery hook ready: load queued/running rows from SQLite and enqueue.',
    );
  }

  @override
  Future<void> shutdown() async {
    for (final handle in _running.values) {
      await handle.kill();
    }
    await _progress.close();
  }

  Future<void> _drain() async {
    if (_draining) return;
    _draining = true;
    try {
      while (_running.length < concurrentLimit && _queued.isNotEmpty) {
        final request = _queued.removeAt(0);
        if (_paused.contains(request.id) ||
            !_requests.containsKey(request.id)) {
          continue;
        }
        await _startWithRetry(request, attempt: 0);
      }
    } finally {
      _draining = false;
    }
  }

  Future<void> _startWithRetry(
    DownloadRequest request, {
    required int attempt,
  }) async {
    try {
      _progress.add(
        DownloadProgress(
          id: request.id,
          status: DownloadStatus.analyzing,
          stage: 'Preparing',
        ),
      );
      final handle = await _ytDlp.start(request);
      _running[request.id] = handle;
      handle.progress.listen((event) {
        final progress = event.copyWith(retryAttempt: attempt);
        _progress.add(progress);
        if (progress.status == DownloadStatus.completed) {
          unawaited(_onProgress?.call(progress));
        }
        if (event.status == DownloadStatus.completed ||
            event.status == DownloadStatus.failed) {
          _running.remove(request.id);
          if (event.status == DownloadStatus.failed &&
              attempt < request.maxRetries &&
              !_paused.contains(request.id)) {
            _progress.add(
              event.copyWith(
                status: DownloadStatus.retrying,
                stage: 'Retrying',
                retryAttempt: attempt + 1,
              ),
            );
            Timer(
              Duration(seconds: 2 << attempt),
              () => unawaited(_startWithRetry(request, attempt: attempt + 1)),
            );
          } else {
            unawaited(_drain());
          }
        }
      });
    } on AppException catch (error, stack) {
      _logger.warning('Download failed before process start', error, stack);
      _progress.add(
        DownloadProgress(
          id: request.id,
          status: DownloadStatus.failed,
          stage: 'Failed',
          message: error.message,
        ),
      );
      await _drain();
    }
  }

  void _enqueueByPriority(DownloadRequest request) {
    _queued.add(request);
    _queued.sort(_comparePriority);
  }

  static int _comparePriority(DownloadRequest a, DownloadRequest b) {
    return b.priority.index.compareTo(a.priority.index);
  }
}
