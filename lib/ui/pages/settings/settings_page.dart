import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../store/app_providers.dart';
import '../../../store/settings_controller.dart';
import '../../components/panel.dart';

final class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    return ListView(
      children: [
        Text(
          'Settings',
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 18),
        settings.when(
          data: (state) => _SettingsForm(state: state, ref: ref),
          error: (error, _) =>
              Panel(child: Text('Settings unavailable: $error')),
          loading: () => const Panel(
            child: SizedBox(
              height: 180,
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
        ),
      ],
    );
  }
}

final class _SettingsForm extends StatelessWidget {
  const _SettingsForm({required this.state, required this.ref});

  final AppSettingsState state;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final controller = ref.read(settingsControllerProvider.notifier);
    return Column(
      children: [
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Downloads',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  final path = await FilePicker.platform.getDirectoryPath();
                  if (path != null) controller.setDownloadDirectory(path);
                },
                icon: const Icon(Icons.folder_open),
                label: Text(
                  state.downloadDirectory.path,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.stacked_line_chart),
                  const SizedBox(width: 12),
                  const Expanded(child: Text('Simultaneous downloads')),
                  SizedBox(
                    width: 280,
                    child: Slider(
                      min: 1,
                      max: 8,
                      divisions: 7,
                      label: state.concurrentDownloads.toString(),
                      value: state.concurrentDownloads.toDouble(),
                      onChanged: (value) =>
                          controller.setConcurrentDownloads(value.round()),
                    ),
                  ),
                  SizedBox(
                    width: 28,
                    child: Text(state.concurrentDownloads.toString()),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Panel(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.palette),
                title: const Text('Theme preset'),
                subtitle: Text(state.themePreset.label),
                trailing: DropdownMenu<AppThemePreset>(
                  initialSelection: state.themePreset,
                  dropdownMenuEntries: AppThemePreset.values
                      .map(
                        (preset) => DropdownMenuEntry(
                          value: preset,
                          label: preset.label,
                        ),
                      )
                      .toList(growable: false),
                  onSelected: (preset) {
                    if (preset != null) controller.setThemePreset(preset);
                  },
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.contrast),
                title: const Text('App theme'),
                subtitle: const Text('Choose system, dark, or light mode'),
                trailing: SegmentedButton<AppThemeModeSetting>(
                  segments: const [
                    ButtonSegment(
                      value: AppThemeModeSetting.system,
                      icon: Icon(Icons.desktop_windows),
                      label: Text('System'),
                    ),
                    ButtonSegment(
                      value: AppThemeModeSetting.dark,
                      icon: Icon(Icons.dark_mode),
                      label: Text('Dark'),
                    ),
                    ButtonSegment(
                      value: AppThemeModeSetting.light,
                      icon: Icon(Icons.light_mode),
                      label: Text('Light'),
                    ),
                  ],
                  selected: {state.themeMode},
                  onSelectionChanged: (value) =>
                      controller.setThemeMode(value.first),
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.format_paint),
                title: const Text('Overall app color'),
                subtitle: const Text(
                  'Tints the background, panels, navigation, and controls',
                ),
                trailing: Wrap(
                  spacing: 8,
                  children: [
                    for (final color in _appColors)
                      Tooltip(
                        message: _appColorName(color),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () => controller.setAppColor(color),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: color,
                              border: Border.all(
                                color:
                                    state.appColor.toARGB32() ==
                                        color.toARGB32()
                                    ? Theme.of(context).colorScheme.onSurface
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.radio_button_checked),
                title: const Text('Accent color'),
                subtitle: const Text(
                  'Controls buttons, highlights, and selection color',
                ),
                trailing: Wrap(
                  spacing: 8,
                  children: [
                    for (final color in _accentColors)
                      Tooltip(
                        message: _colorName(color),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () => controller.setAccentColor(color),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: color,
                              border: Border.all(
                                color:
                                    state.accentColor.toARGB32() ==
                                        color.toARGB32()
                                    ? Theme.of(context).colorScheme.onSurface
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.download),
                title: const Text('yt-dlp channel'),
                subtitle: const Text(
                  'Choose stable releases or nightly builds',
                ),
                trailing: SegmentedButton<YtDlpChannelSetting>(
                  segments: const [
                    ButtonSegment(
                      value: YtDlpChannelSetting.stable,
                      label: Text('Stable'),
                    ),
                    ButtonSegment(
                      value: YtDlpChannelSetting.nightly,
                      label: Text('Nightly'),
                    ),
                  ],
                  selected: {state.ytDlpChannel},
                  onSelectionChanged: (value) =>
                      controller.setYtDlpChannel(value.first),
                ),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.system_update_alt),
                title: const Text('Auto update yt-dlp'),
                value: state.autoUpdateYtDlp,
                onChanged: (value) =>
                    controller.setAutoUpdateYtDlp(value: value),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.video_settings),
                title: const Text('Auto update ffmpeg'),
                value: state.autoUpdateFfmpeg,
                onChanged: (value) =>
                    controller.setAutoUpdateFfmpeg(value: value),
              ),
              const Divider(),
              const _DependencyCheckTile(),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.build),
                title: const Text('Custom ffmpeg.exe'),
                subtitle: Text(
                  state.customFfmpegPath.isEmpty
                      ? 'Using bundled ffmpeg'
                      : state.customFfmpegPath,
                ),
                trailing: OutlinedButton(
                  onPressed: () async {
                    final result = await FilePicker.platform.pickFiles(
                      dialogTitle: 'Select ffmpeg.exe',
                      type: FileType.custom,
                      allowedExtensions: ['exe'],
                    );
                    final path = result?.files.single.path;
                    if (path != null) controller.setCustomFfmpegPath(path);
                  },
                  child: const Text('Browse'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Panel(
          child: Column(
            children: [
              TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.public),
                  labelText: 'Proxy URL',
                  hintText: 'http://127.0.0.1:8080',
                  border: OutlineInputBorder(),
                ),
                controller: TextEditingController(text: state.proxyUrl),
                onChanged: controller.setProxyUrl,
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.cookie),
                title: const Text('Cookies file'),
                subtitle: Text(
                  state.cookiesPath.isEmpty
                      ? 'No cookies file selected'
                      : state.cookiesPath,
                ),
                trailing: OutlinedButton(
                  onPressed: () async {
                    final result = await FilePicker.platform.pickFiles(
                      dialogTitle: 'Select cookies.txt',
                    );
                    final path = result?.files.single.path;
                    if (path != null) controller.setCookiesPath(path);
                  },
                  child: const Text('Browse'),
                ),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.bug_report),
                title: const Text('Debug logs'),
                value: state.debugLogs,
                onChanged: (value) => controller.setDebugLogs(value: value),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.minimize),
                title: const Text('Start minimized'),
                value: state.startMinimized,
                onChanged: (value) =>
                    controller.setStartMinimized(value: value),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

final class _DependencyCheckTile extends ConsumerStatefulWidget {
  const _DependencyCheckTile();

  @override
  ConsumerState<_DependencyCheckTile> createState() =>
      _DependencyCheckTileState();
}

final class _DependencyCheckTileState
    extends ConsumerState<_DependencyCheckTile> {
  bool _checking = false;
  String _status = 'Check bundled yt-dlp and ffmpeg availability';

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.system_update_alt),
      title: const Text('Dependency check'),
      subtitle: Text(_status),
      trailing: FilledButton(
        onPressed: _checking ? null : _check,
        child: _checking
            ? const SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Check'),
      ),
    );
  }

  Future<void> _check() async {
    setState(() => _checking = true);
    try {
      final ytDlp = await ref.read(ytDlpServiceProvider.future);
      final ytDlpVersion = await ytDlp.version();
      final ffmpeg = await ref.read(ffmpegExecutableProvider.future);
      var ffmpegVersion = 'not found';
      if (ffmpeg != null && ffmpeg.existsSync()) {
        final result = await Process.run(ffmpeg.path, const [
          '-version',
        ], runInShell: false);
        if (result.exitCode == 0) {
          ffmpegVersion = result.stdout
              .toString()
              .split(RegExp(r'\r?\n'))
              .first;
        }
      }
      setState(() {
        _status = 'yt-dlp $ytDlpVersion · $ffmpegVersion';
      });
    } catch (error) {
      setState(() {
        _status = 'Dependency check failed: $error';
      });
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }
}

const _accentColors = [
  Color(0xFF60A5FA),
  Color(0xFF22C55E),
  Color(0xFFF97316),
  Color(0xFFEC4899),
  Color(0xFF14B8A6),
  Color(0xFFEAB308),
];

const _appColors = [
  Color(0xFF3B82F6),
  Color(0xFF0F766E),
  Color(0xFF475569),
  Color(0xFF9A3412),
  Color(0xFF6D28D9),
  Color(0xFF7C2D12),
];

String _colorName(Color color) => switch (color.toARGB32()) {
  0xFF60A5FA => 'Blue',
  0xFF22C55E => 'Green',
  0xFFF97316 => 'Orange',
  0xFFEC4899 => 'Pink',
  0xFF14B8A6 => 'Teal',
  0xFFEAB308 => 'Gold',
  _ => 'Accent',
};

String _appColorName(Color color) => switch (color.toARGB32()) {
  0xFF3B82F6 => 'Blue base',
  0xFF0F766E => 'Teal base',
  0xFF475569 => 'Graphite base',
  0xFF9A3412 => 'Ember base',
  0xFF6D28D9 => 'Violet base',
  0xFF7C2D12 => 'Clay base',
  _ => 'App color',
};
