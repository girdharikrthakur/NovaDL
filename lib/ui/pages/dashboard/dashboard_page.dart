import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../download_engine/domain/download_models.dart';
import '../../../store/app_providers.dart';
import '../../components/new_download_panel.dart';
import '../../components/panel.dart';

final class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(downloadQueueItemsProvider);
    final library = ref.watch(mediaLibraryProvider);
    final queueItems = queue.valueOrNull ?? const <DownloadProgress>[];
    final active = queueItems
        .where(
          (item) =>
              item.status == DownloadStatus.running ||
              item.status == DownloadStatus.analyzing ||
              item.status == DownloadStatus.retrying,
        )
        .length;
    final queued = queueItems
        .where(
          (item) =>
              item.status == DownloadStatus.running ||
              item.status == DownloadStatus.analyzing ||
              item.status == DownloadStatus.retrying ||
              item.status == DownloadStatus.queued ||
              item.status == DownloadStatus.scheduled,
        )
        .length;
    final speed = queueItems.fold<int>(
      0,
      (total, item) => total + item.speedBytesPerSecond,
    );
    final completed = library.valueOrNull?.length ?? 0;
    final current = queueItems
        .where(
          (item) =>
              item.status == DownloadStatus.running ||
              item.status == DownloadStatus.analyzing ||
              item.status == DownloadStatus.retrying ||
              item.status == DownloadStatus.queued,
        )
        .take(6)
        .toList(growable: false);

    return ListView(
      children:
          [
                Text(
                  'Dashboard',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 18),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 4,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: 1.8,
                  children: [
                    _Metric(
                      title: 'Active',
                      value: active.toString(),
                      icon: Icons.bolt,
                    ),
                    _Metric(
                      title: 'Queued',
                      value: queued.toString(),
                      icon: Icons.playlist_add_check,
                    ),
                    _Metric(
                      title: 'Speed',
                      value: _formatSpeed(speed),
                      icon: Icons.speed,
                    ),
                    _Metric(
                      title: 'Library',
                      value: '$completed files',
                      icon: Icons.storage,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const NewDownloadPanel(),
                const SizedBox(height: 14),
                Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Current downloads',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 10),
                      if (current.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 18),
                          child: Center(
                            child: Text('No active downloads right now.'),
                          ),
                        )
                      else
                        for (final item in current)
                          ListTile(
                            leading: const Icon(Icons.downloading),
                            title: Text(
                              _downloadTitle(item),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: LinearProgressIndicator(
                              value: item.percent.clamp(0, 100) / 100,
                            ),
                            trailing: Text(
                              '${item.percent.toStringAsFixed(1)}%',
                            ),
                          ),
                    ],
                  ),
                ),
              ]
              .animate(interval: 45.ms)
              .fadeIn(duration: 220.ms)
              .slideY(begin: .02, end: 0),
    );
  }

  String _formatSpeed(int bytesPerSecond) {
    if (bytesPerSecond <= 0) return '0 MB/s';
    final mb = bytesPerSecond / (1024 * 1024);
    if (mb >= 1) return '${mb.toStringAsFixed(1)} MB/s';
    final kb = bytesPerSecond / 1024;
    return '${kb.toStringAsFixed(0)} KB/s';
  }

  String _downloadTitle(DownloadProgress item) {
    final details = <String>[
      item.stage,
      if (item.speedBytesPerSecond > 0) _formatSpeed(item.speedBytesPerSecond),
      if (item.eta != null) _formatEta(item.eta!),
    ];
    return details.join(' · ');
  }

  String _formatEta(Duration eta) {
    final hours = eta.inHours;
    final minutes = eta.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = eta.inSeconds.remainder(60).toString().padLeft(2, '0');
    return hours > 0
        ? '$hours:$minutes:$seconds left'
        : '$minutes:$seconds left';
  }
}

final class _Metric extends StatelessWidget {
  const _Metric({required this.title, required this.value, required this.icon});

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Panel(
      child: Row(
        children: [
          Icon(icon, size: 30),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(title, style: Theme.of(context).textTheme.labelLarge),
              Text(
                value,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
