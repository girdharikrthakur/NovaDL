import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/file_launcher.dart';
import '../../../database/app_database.dart';
import '../../../store/app_providers.dart';
import '../../components/panel.dart';

final class LibraryPage extends ConsumerStatefulWidget {
  const LibraryPage({super.key});

  @override
  ConsumerState<LibraryPage> createState() => _LibraryPageState();
}

final class _LibraryPageState extends ConsumerState<LibraryPage> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(mediaLibraryProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Media Library',
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 18),
        Panel(
          child: TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search files, tags, creators, codecs',
              border: OutlineInputBorder(),
            ),
            onChanged: (query) =>
                ref.read(mediaLibraryProvider.notifier).reload(query: query),
          ),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: Panel(
            child: items.when(
              data: (mediaItems) {
                if (mediaItems.isEmpty) {
                  return const Center(
                    child: Text('Completed videos will appear here.'),
                  );
                }

                return GridView.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 320,
                    mainAxisExtent: 156,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                  ),
                  itemCount: mediaItems.length,
                  itemBuilder: (context, index) =>
                      _MediaTile(item: mediaItems[index]),
                );
              },
              error: (error, _) =>
                  Center(child: Text('Library unavailable: $error')),
              loading: () => const Center(child: CircularProgressIndicator()),
            ),
          ),
        ),
      ],
    );
  }
}

final class _MediaTile extends ConsumerWidget {
  const _MediaTile({required this.item});

  final AppMediaItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = item.filePath;
    final file = File(path);
    final isAudio = item.mediaType == 'audio';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(isAudio ? Icons.music_note : Icons.movie, size: 30),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              path,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                FilledButton.tonalIcon(
                  onPressed: file.existsSync()
                      ? () => FileLauncher.openDefault(path)
                      : null,
                  icon: Icon(isAudio ? Icons.graphic_eq : Icons.play_arrow),
                  label: const Text('Open'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
