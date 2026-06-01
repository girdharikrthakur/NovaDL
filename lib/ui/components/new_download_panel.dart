import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../download_engine/domain/download_models.dart';
import '../../store/app_providers.dart';
import '../../store/settings_controller.dart';
import 'panel.dart';

final class NewDownloadPanel extends ConsumerStatefulWidget {
  const NewDownloadPanel({super.key});

  @override
  ConsumerState<NewDownloadPanel> createState() => _NewDownloadPanelState();
}

final class _NewDownloadPanelState extends ConsumerState<NewDownloadPanel> {
  final _urlController = TextEditingController();
  String _resolution = 'Best available';
  CodecPreference _codec = CodecPreference.auto;
  String _container = 'mp4';
  String _audioFormat = 'mp3';
  String _audioBitrate = 'Best';
  String _videoAudioBitrate = 'Best';
  bool _extractAudio = false;
  bool _downloadWholePlaylist = true;
  bool _downloadSubtitles = false;
  bool _downloadThumbnail = true;
  bool _embedMetadata = true;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsControllerProvider);
    return Panel(
      child: settings.when(
        data: (state) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'New download',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _urlController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.link),
                hintText:
                    'Paste a YouTube video, playlist, channel, or livestream URL',
                border: const OutlineInputBorder(),
                suffixIcon: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilledButton.icon(
                    onPressed: _isSubmitting ? null : () => _start(state),
                    icon: _isSubmitting
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.play_arrow),
                    label: const Text('Start'),
                  ),
                ),
                suffixIconConstraints: const BoxConstraints(
                  minWidth: 120,
                  minHeight: 42,
                ),
              ),
              onSubmitted: (_) => _start(state),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickOutputDirectory,
                    icon: const Icon(Icons.folder_open),
                    label: Text(
                      state.downloadDirectory.path,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                      value: false,
                      icon: Icon(Icons.movie),
                      label: Text('Video'),
                    ),
                    ButtonSegment(
                      value: true,
                      icon: Icon(Icons.music_note),
                      label: Text('Audio'),
                    ),
                  ],
                  selected: {_extractAudio},
                  onSelectionChanged: (value) =>
                      setState(() => _extractAudio = value.first),
                ),
                if (!_extractAudio) ...[
                  _Menu<String>(
                    label: 'Resolution',
                    value: _resolution,
                    values: const [
                      'Best available',
                      'Auto',
                      '2160p',
                      '1440p',
                      '1080p',
                      '720p',
                      '480p',
                      '360p',
                    ],
                    onChanged: (value) => setState(() => _resolution = value),
                  ),
                  _Menu<CodecPreference>(
                    label: 'Codec',
                    value: _codec,
                    values: CodecPreference.values,
                    labelFor: _codecLabel,
                    onChanged: (value) => setState(() => _codec = value),
                  ),
                  _Menu<String>(
                    label: 'Container',
                    value: _container,
                    values: const ['mp4', 'mkv', 'webm'],
                    onChanged: (value) => setState(() => _container = value),
                  ),
                  _Menu<String>(
                    label: 'Audio quality',
                    value: _videoAudioBitrate,
                    values: const ['Best', '320', '256', '192', '128'],
                    onChanged: (value) =>
                        setState(() => _videoAudioBitrate = value),
                  ),
                ] else ...[
                  _Menu<String>(
                    label: 'Audio format',
                    value: _audioFormat,
                    values: const ['mp3', 'm4a', 'opus', 'wav', 'flac'],
                    onChanged: (value) => setState(() => _audioFormat = value),
                  ),
                  _Menu<String>(
                    label: 'Bitrate',
                    value: _audioBitrate,
                    values: const ['Best', '320', '256', '192', '128'],
                    onChanged: (value) => setState(() => _audioBitrate = value),
                  ),
                ],
                FilterChip(
                  selected: _downloadWholePlaylist,
                  label: const Text('All playlist videos'),
                  avatar: const Icon(Icons.playlist_play),
                  onSelected: (value) =>
                      setState(() => _downloadWholePlaylist = value),
                ),
                FilterChip(
                  selected: _downloadSubtitles,
                  label: const Text('Subtitles'),
                  avatar: const Icon(Icons.closed_caption),
                  onSelected: (value) =>
                      setState(() => _downloadSubtitles = value),
                ),
                FilterChip(
                  selected: _downloadThumbnail,
                  label: const Text('Thumbnail'),
                  avatar: const Icon(Icons.image),
                  onSelected: (value) =>
                      setState(() => _downloadThumbnail = value),
                ),
                FilterChip(
                  selected: _embedMetadata,
                  label: const Text('Metadata'),
                  avatar: const Icon(Icons.sell),
                  onSelected: (value) => setState(() => _embedMetadata = value),
                ),
              ],
            ),
          ],
        ),
        error: (error, _) => Text('Settings unavailable: $error'),
        loading: () => const SizedBox(
          height: 120,
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }

  Future<void> _pickOutputDirectory() async {
    final path = await FilePicker.platform.getDirectoryPath();
    if (path == null) return;
    ref.read(settingsControllerProvider.notifier).setDownloadDirectory(path);
  }

  Future<void> _start(AppSettingsState settings) async {
    final messenger = ScaffoldMessenger.of(context);
    final url = Uri.tryParse(_urlController.text.trim());
    if (url == null || !url.hasScheme || url.host.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Paste a valid video or playlist URL.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final selectedPlaylistItems = _downloadWholePlaylist
          ? await _selectPlaylistItems(url)
          : null;
      if (selectedPlaylistItems != null && selectedPlaylistItems.isEmpty) {
        return;
      }

      final engine = await ref.read(downloadEngineProvider.future);
      await engine.enqueue(
        DownloadRequest(
          url: url,
          outputDirectory: Directory(settings.downloadDirectory.path),
          kind: _downloadWholePlaylist
              ? DownloadKind.playlist
              : DownloadKind.video,
          selection: FormatSelection(
            bestAvailable:
                !_extractAudio &&
                (_resolution == 'Best available' || _resolution == 'Auto'),
            resolution:
                _extractAudio ||
                    _resolution == 'Best available' ||
                    _resolution == 'Auto'
                ? null
                : _resolution,
            videoCodec: _codec,
            container: _container,
            extractAudio: _extractAudio,
            audioCodec: _extractAudio ? _audioFormat : null,
            audioBitrateKbps: _extractAudio
                ? (_audioBitrate == 'Best' ? null : int.tryParse(_audioBitrate))
                : (_videoAudioBitrate == 'Best'
                      ? null
                      : int.tryParse(_videoAudioBitrate)),
            downloadSubtitles: _downloadSubtitles,
            downloadThumbnail: _downloadThumbnail,
            embedMetadata: _embedMetadata,
          ),
          extraArgs: [
            if (_downloadWholePlaylist) '--yes-playlist' else '--no-playlist',
            if (_downloadWholePlaylist) '--ignore-errors',
            if (selectedPlaylistItems != null &&
                selectedPlaylistItems.isNotEmpty) ...[
              '--playlist-items',
              selectedPlaylistItems.join(','),
            ],
            if (settings.proxyUrl.isNotEmpty) ...['--proxy', settings.proxyUrl],
            if (settings.cookiesPath.isNotEmpty) ...[
              '--cookies',
              settings.cookiesPath,
            ],
          ],
        ),
      );
      _urlController.clear();
      messenger.showSnackBar(
        const SnackBar(content: Text('Download added to the queue.')),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not start download: $error')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<List<int>?> _selectPlaylistItems(Uri url) async {
    final messenger = ScaffoldMessenger.of(context);
    late final List<PlaylistVideo> videos;
    try {
      final ytDlp = await ref.read(ytDlpServiceProvider.future);
      videos = await ytDlp.analyzePlaylist(url);
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Could not inspect playlist. Starting normal download instead. $error',
          ),
        ),
      );
      return null;
    }
    if (!mounted || videos.isEmpty) return null;

    final selected = await showGeneralDialog<List<int>>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close playlist selector',
      barrierColor: Colors.black.withValues(alpha: .32),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (context, _, __) => _PlaylistSelectionDialog(videos: videos),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, .035),
              end: Offset.zero,
            ).animate(curved),
            child: ScaleTransition(
              scale: Tween<double>(begin: .965, end: 1).animate(curved),
              child: child,
            ),
          ),
        );
      },
    );

    return selected ?? const [];
  }

  String _codecLabel(CodecPreference value) => switch (value) {
    CodecPreference.auto => 'Auto',
    CodecPreference.av1 => 'AV1',
    CodecPreference.vp9 => 'VP9',
    CodecPreference.h264 => 'H264',
  };
}

final class _PlaylistSelectionDialog extends StatefulWidget {
  const _PlaylistSelectionDialog({required this.videos});

  final List<PlaylistVideo> videos;

  @override
  State<_PlaylistSelectionDialog> createState() =>
      _PlaylistSelectionDialogState();
}

final class _PlaylistSelectionDialogState
    extends State<_PlaylistSelectionDialog> {
  late final Set<int> _selected = widget.videos
      .map((video) => video.index)
      .toSet();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760, maxHeight: 620),
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.playlist_play,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Select playlist videos',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.of(
                          context,
                          rootNavigator: true,
                        ).pop(null),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        child: Text(
                          '${_selected.length} of ${widget.videos.length} selected',
                          key: ValueKey(_selected.length),
                        ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () => setState(() {
                          _selected
                            ..clear()
                            ..addAll(widget.videos.map((video) => video.index));
                        }),
                        icon: const Icon(Icons.done_all),
                        label: const Text('Select all'),
                      ),
                      TextButton.icon(
                        onPressed: () => setState(_selected.clear),
                        icon: const Icon(Icons.clear_all),
                        label: const Text('Clear'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Flexible(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: widget.videos.length,
                        itemBuilder: (context, index) {
                          final video = widget.videos[index];
                          final selected = _selected.contains(video.index);
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            curve: Curves.easeOutCubic,
                            margin: const EdgeInsets.only(bottom: 6),
                            decoration: BoxDecoration(
                              color: selected
                                  ? Theme.of(
                                      context,
                                    ).colorScheme.primaryContainer
                                  : Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: CheckboxListTile(
                              value: selected,
                              onChanged: (value) => setState(() {
                                if (value ?? false) {
                                  _selected.add(video.index);
                                } else {
                                  _selected.remove(video.index);
                                }
                              }),
                              title: Text(
                                video.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                [
                                  '#${video.index}',
                                  if (video.duration != null)
                                    _formatDuration(video.duration!),
                                ].join(' · '),
                              ),
                              secondary: const Icon(Icons.smart_display),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(
                          context,
                          rootNavigator: true,
                        ).pop(null),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 10),
                      FilledButton.icon(
                        onPressed: _selected.isEmpty
                            ? null
                            : () => Navigator.of(
                                context,
                                rootNavigator: true,
                              ).pop(_selected.toList(growable: false)..sort()),
                        icon: const Icon(Icons.download),
                        label: const Text('Download selected'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }
}

final class _Menu<T> extends StatelessWidget {
  const _Menu({
    required this.label,
    required this.value,
    required this.values,
    required this.onChanged,
    this.labelFor,
  });

  final String label;
  final T value;
  final List<T> values;
  final ValueChanged<T> onChanged;
  final String Function(T value)? labelFor;

  @override
  Widget build(BuildContext context) {
    return DropdownMenu<T>(
      label: Text(label),
      initialSelection: value,
      dropdownMenuEntries: values
          .map(
            (item) => DropdownMenuEntry<T>(
              value: item,
              label: labelFor?.call(item) ?? item.toString(),
            ),
          )
          .toList(growable: false),
      onSelected: (item) {
        if (item != null) onChanged(item);
      },
    );
  }
}
