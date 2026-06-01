import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/file_launcher.dart';
import '../../../download_engine/domain/download_models.dart';
import '../../../store/app_providers.dart';
import '../../components/new_download_panel.dart';
import '../../components/panel.dart';

final class DownloadsPage extends ConsumerStatefulWidget {
  const DownloadsPage({super.key});

  @override
  ConsumerState<DownloadsPage> createState() => _DownloadsPageState();
}

final class _DownloadsPageState extends ConsumerState<DownloadsPage> {
  bool _showNewDownload = true;

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(downloadProgressProvider);
    final items = ref.watch(downloadQueueItemsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Downloads',
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: () async {
                final engine = await ref.read(downloadEngineProvider.future);
                await engine.cancelAll();
              },
              icon: const Icon(Icons.stop_circle_outlined),
              label: const Text('Stop all'),
            ),
            const SizedBox(width: 10),
            FilledButton.icon(
              onPressed: () =>
                  setState(() => _showNewDownload = !_showNewDownload),
              icon: const Icon(Icons.add),
              label: Text(_showNewDownload ? 'Hide' : 'Add URL'),
            ),
          ],
        ),
        const SizedBox(height: 18),
        if (_showNewDownload) ...[
          const NewDownloadPanel(),
          const SizedBox(height: 14),
        ],
        Expanded(
          child: Panel(
            child: items.when(
              data: (queueItems) => queueItems.isEmpty
                  ? progress.maybeWhen(
                      data: (item) => _ProgressRow(item: item),
                      orElse: () => const Center(
                        child: Text('Queue ready. Add a URL to begin.'),
                      ),
                    )
                  : ListView.separated(
                      itemBuilder: (context, index) =>
                          _ProgressRow(item: queueItems[index]),
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemCount: queueItems.length,
                    ),
              error: (error, _) =>
                  Center(child: Text('Download engine unavailable: $error')),
              loading: () =>
                  const Center(child: Text('Queue ready. Add a URL to begin.')),
            ),
          ),
        ),
      ],
    );
  }
}

final class _ProgressRow extends ConsumerWidget {
  const _ProgressRow({required this.item});

  final DownloadProgress item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final percentText = '${item.percent.toStringAsFixed(1)}%';
    return ListTile(
      leading: const Icon(Icons.movie_filter_outlined),
      title: Text(_title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 6),
          LinearProgressIndicator(value: item.percent.clamp(0, 100) / 100),
          const SizedBox(height: 6),
          Text(
            [
              item.stage,
              if (item.fragmentIndex != null && item.fragmentCount != null)
                'fragment ${item.fragmentIndex}/${item.fragmentCount}',
              if (item.retryAttempt > 0) 'retry ${item.retryAttempt}',
            ].join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
      trailing: item.status == DownloadStatus.completed
          ? _CompletedActions(path: item.completedFilePath)
          : Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(percentText),
                IconButton.outlined(
                  tooltip: 'Stop download',
                  onPressed: item.status == DownloadStatus.canceled
                      ? null
                      : () async {
                          final engine = await ref.read(
                            downloadEngineProvider.future,
                          );
                          await engine.cancel(item.id);
                        },
                  icon: const Icon(Icons.stop),
                ),
              ],
            ),
    );
  }

  String get _title {
    if (item.completedFilePath != null) {
      return File(item.completedFilePath!).uri.pathSegments.last;
    }
    return item.message?.replaceFirst(RegExp(r'^\[[^\]]+\]\s*'), '') ??
        item.status.name;
  }
}

final class _CompletedActions extends ConsumerWidget {
  const _CompletedActions({required this.path});

  final String? path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canOpen = path != null && File(path!).existsSync();
    return Wrap(
      spacing: 8,
      children: [
        IconButton.filledTonal(
          tooltip: 'Open video',
          onPressed: canOpen ? () => FileLauncher.openDefault(path!) : null,
          icon: const Icon(Icons.play_circle),
        ),
      ],
    );
  }
}
