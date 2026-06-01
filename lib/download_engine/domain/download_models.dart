import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

enum DownloadKind { video, audio, playlist, channel, livestream }

enum DownloadStatus {
  queued,
  analyzing,
  running,
  paused,
  retrying,
  completed,
  failed,
  canceled,
  scheduled,
}

enum DownloadPriority { low, normal, high, urgent }

enum CodecPreference { auto, av1, vp9, h264 }

final class PlaylistVideo extends Equatable {
  const PlaylistVideo({
    required this.index,
    required this.id,
    required this.title,
    this.duration,
    this.thumbnail,
  });

  final int index;
  final String id;
  final String title;
  final Duration? duration;
  final String? thumbnail;

  @override
  List<Object?> get props => [index, id, title, duration, thumbnail];
}

final class FormatSelection extends Equatable {
  const FormatSelection({
    this.bestAvailable = false,
    this.resolution,
    this.fps,
    this.videoCodec = CodecPreference.auto,
    this.audioCodec,
    this.container = 'mp4',
    this.audioBitrateKbps,
    this.hdr = false,
    this.extractAudio = false,
    this.embedMetadata = true,
    this.downloadThumbnail = true,
    this.downloadSubtitles = false,
  });

  final bool bestAvailable;
  final String? resolution;
  final int? fps;
  final CodecPreference videoCodec;
  final String? audioCodec;
  final String container;
  final int? audioBitrateKbps;
  final bool hdr;
  final bool extractAudio;
  final bool embedMetadata;
  final bool downloadThumbnail;
  final bool downloadSubtitles;

  List<String> toYtDlpArgs() {
    final args = <String>[];
    if (extractAudio) {
      args.addAll(['--extract-audio', '--audio-format', audioCodec ?? 'mp3']);
      if (audioBitrateKbps != null) {
        args.addAll(['--audio-quality', '${audioBitrateKbps!}K']);
      }
    } else {
      final filters = <String>[];
      if (!bestAvailable && resolution != null) {
        filters.add('[height<=${resolution!.replaceAll('p', '')}]');
      }
      if (fps != null) {
        filters.add('[fps<=${fps!}]');
      }
      final videoCodecName = switch (videoCodec) {
        CodecPreference.auto => null,
        CodecPreference.av1 => 'av01',
        CodecPreference.vp9 => 'vp9',
        CodecPreference.h264 => 'avc1',
      };
      if (videoCodecName != null) {
        filters.add('[vcodec^=$videoCodecName]');
      }
      final videoSelector = 'bv*${filters.join()}';
      final audioSelector = audioBitrateKbps == null
          ? 'ba'
          : 'ba[abr<=${audioBitrateKbps!}]';
      args.addAll(['-f', '$videoSelector+$audioSelector/b']);
      args.addAll(['--merge-output-format', container]);
    }
    if (embedMetadata) {
      args.add('--embed-metadata');
    }
    if (downloadThumbnail) {
      args.add('--write-thumbnail');
    }
    if (downloadSubtitles) {
      args.addAll(['--write-subs', '--sub-langs', 'all']);
    }
    return args;
  }

  @override
  List<Object?> get props => [
    bestAvailable,
    resolution,
    fps,
    videoCodec,
    audioCodec,
    container,
    audioBitrateKbps,
    hdr,
    extractAudio,
    embedMetadata,
    downloadThumbnail,
    downloadSubtitles,
  ];
}

final class DownloadRequest extends Equatable {
  DownloadRequest({
    String? id,
    required this.url,
    required this.outputDirectory,
    this.kind = DownloadKind.video,
    this.priority = DownloadPriority.normal,
    this.selection = const FormatSelection(),
    this.scheduledAt,
    this.maxRetries = 3,
    this.bandwidthLimit,
    this.extraArgs = const [],
  }) : id = id ?? const Uuid().v7();

  final String id;
  final Uri url;
  final Directory outputDirectory;
  final DownloadKind kind;
  final DownloadPriority priority;
  final FormatSelection selection;
  final DateTime? scheduledAt;
  final int maxRetries;
  final String? bandwidthLimit;
  final List<String> extraArgs;

  @override
  List<Object?> get props => [
    id,
    url,
    outputDirectory.path,
    kind,
    priority,
    selection,
    scheduledAt,
    maxRetries,
    bandwidthLimit,
    extraArgs,
  ];
}

final class DownloadProgress extends Equatable {
  const DownloadProgress({
    required this.id,
    required this.status,
    this.percent = 0,
    this.speedBytesPerSecond = 0,
    this.eta,
    this.stage = 'Queued',
    this.fragmentIndex,
    this.fragmentCount,
    this.message,
    this.completedFilePath,
    this.retryAttempt = 0,
  });

  final String id;
  final DownloadStatus status;
  final double percent;
  final int speedBytesPerSecond;
  final Duration? eta;
  final String stage;
  final int? fragmentIndex;
  final int? fragmentCount;
  final String? message;
  final String? completedFilePath;
  final int retryAttempt;

  DownloadProgress copyWith({
    DownloadStatus? status,
    double? percent,
    int? speedBytesPerSecond,
    Duration? eta,
    String? stage,
    int? fragmentIndex,
    int? fragmentCount,
    String? message,
    String? completedFilePath,
    int? retryAttempt,
  }) {
    return DownloadProgress(
      id: id,
      status: status ?? this.status,
      percent: percent ?? this.percent,
      speedBytesPerSecond: speedBytesPerSecond ?? this.speedBytesPerSecond,
      eta: eta ?? this.eta,
      stage: stage ?? this.stage,
      fragmentIndex: fragmentIndex ?? this.fragmentIndex,
      fragmentCount: fragmentCount ?? this.fragmentCount,
      message: message ?? this.message,
      completedFilePath: completedFilePath ?? this.completedFilePath,
      retryAttempt: retryAttempt ?? this.retryAttempt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    status,
    percent,
    speedBytesPerSecond,
    eta,
    stage,
    fragmentIndex,
    fragmentCount,
    message,
    completedFilePath,
    retryAttempt,
  ];
}
