import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'app_providers.dart';

enum YtDlpChannelSetting { stable, nightly }

enum AppThemeModeSetting { system, dark, light }

enum AppThemePreset { nova, aurora, graphite, ember, violet }

extension AppThemePresetDetails on AppThemePreset {
  String get label => switch (this) {
    AppThemePreset.nova => 'Nova',
    AppThemePreset.aurora => 'Aurora',
    AppThemePreset.graphite => 'Graphite',
    AppThemePreset.ember => 'Ember',
    AppThemePreset.violet => 'Violet',
  };

  Color get accent => switch (this) {
    AppThemePreset.nova => const Color(0xFF60A5FA),
    AppThemePreset.aurora => const Color(0xFF14B8A6),
    AppThemePreset.graphite => const Color(0xFF94A3B8),
    AppThemePreset.ember => const Color(0xFFF97316),
    AppThemePreset.violet => const Color(0xFFA78BFA),
  };

  Color get appColor => switch (this) {
    AppThemePreset.nova => const Color(0xFF3B82F6),
    AppThemePreset.aurora => const Color(0xFF0F766E),
    AppThemePreset.graphite => const Color(0xFF475569),
    AppThemePreset.ember => const Color(0xFF9A3412),
    AppThemePreset.violet => const Color(0xFF6D28D9),
  };
}

final class AppSettingsState {
  const AppSettingsState({
    required this.downloadDirectory,
    this.concurrentDownloads = 3,
    this.ytDlpChannel = YtDlpChannelSetting.stable,
    this.proxyUrl = '',
    this.cookiesPath = '',
    this.customFfmpegPath = '',
    this.videoPlayerPath = '',
    this.appColor = const Color(0xFF3B82F6),
    this.accentColor = const Color(0xFF60A5FA),
    this.themeMode = AppThemeModeSetting.dark,
    this.themePreset = AppThemePreset.nova,
    this.autoUpdateYtDlp = true,
    this.autoUpdateFfmpeg = true,
    this.startMinimized = false,
    this.debugLogs = false,
  });

  final Directory downloadDirectory;
  final int concurrentDownloads;
  final YtDlpChannelSetting ytDlpChannel;
  final String proxyUrl;
  final String cookiesPath;
  final String customFfmpegPath;
  final String videoPlayerPath;
  final Color appColor;
  final Color accentColor;
  final AppThemeModeSetting themeMode;
  final AppThemePreset themePreset;
  final bool autoUpdateYtDlp;
  final bool autoUpdateFfmpeg;
  final bool startMinimized;
  final bool debugLogs;

  AppSettingsState copyWith({
    Directory? downloadDirectory,
    int? concurrentDownloads,
    YtDlpChannelSetting? ytDlpChannel,
    String? proxyUrl,
    String? cookiesPath,
    String? customFfmpegPath,
    String? videoPlayerPath,
    Color? appColor,
    Color? accentColor,
    AppThemeModeSetting? themeMode,
    AppThemePreset? themePreset,
    bool? autoUpdateYtDlp,
    bool? autoUpdateFfmpeg,
    bool? startMinimized,
    bool? debugLogs,
  }) {
    return AppSettingsState(
      downloadDirectory: downloadDirectory ?? this.downloadDirectory,
      concurrentDownloads: concurrentDownloads ?? this.concurrentDownloads,
      ytDlpChannel: ytDlpChannel ?? this.ytDlpChannel,
      proxyUrl: proxyUrl ?? this.proxyUrl,
      cookiesPath: cookiesPath ?? this.cookiesPath,
      customFfmpegPath: customFfmpegPath ?? this.customFfmpegPath,
      videoPlayerPath: videoPlayerPath ?? this.videoPlayerPath,
      appColor: appColor ?? this.appColor,
      accentColor: accentColor ?? this.accentColor,
      themeMode: themeMode ?? this.themeMode,
      themePreset: themePreset ?? this.themePreset,
      autoUpdateYtDlp: autoUpdateYtDlp ?? this.autoUpdateYtDlp,
      autoUpdateFfmpeg: autoUpdateFfmpeg ?? this.autoUpdateFfmpeg,
      startMinimized: startMinimized ?? this.startMinimized,
      debugLogs: debugLogs ?? this.debugLogs,
    );
  }
}

final class SettingsController extends AsyncNotifier<AppSettingsState> {
  @override
  Future<AppSettingsState> build() async {
    final downloads = await getDownloadsDirectory();
    final fallback = AppSettingsState(
      downloadDirectory: downloads ?? Directory.current,
    );
    final database = await ref.watch(databaseProvider.future);
    final raw = database.setting('app_settings');
    if (raw == null) return fallback;
    try {
      final json = jsonDecode(raw) as Map<String, Object?>;
      return AppSettingsState(
        downloadDirectory: Directory(
          json['downloadDirectory']?.toString() ??
              fallback.downloadDirectory.path,
        ),
        concurrentDownloads:
            (json['concurrentDownloads'] as num?)?.round() ??
            fallback.concurrentDownloads,
        ytDlpChannel: _enumByName(
          YtDlpChannelSetting.values,
          json['ytDlpChannel']?.toString(),
          fallback.ytDlpChannel,
        ),
        proxyUrl: json['proxyUrl']?.toString() ?? fallback.proxyUrl,
        cookiesPath: json['cookiesPath']?.toString() ?? fallback.cookiesPath,
        customFfmpegPath:
            json['customFfmpegPath']?.toString() ?? fallback.customFfmpegPath,
        videoPlayerPath:
            json['videoPlayerPath']?.toString() ?? fallback.videoPlayerPath,
        appColor: Color(
          (json['appColor'] as num?)?.round() ?? fallback.appColor.toARGB32(),
        ),
        accentColor: Color(
          (json['accentColor'] as num?)?.round() ??
              fallback.accentColor.toARGB32(),
        ),
        themeMode: _enumByName(
          AppThemeModeSetting.values,
          json['themeMode']?.toString(),
          fallback.themeMode,
        ),
        themePreset: _enumByName(
          AppThemePreset.values,
          json['themePreset']?.toString(),
          fallback.themePreset,
        ),
        autoUpdateYtDlp:
            json['autoUpdateYtDlp'] as bool? ?? fallback.autoUpdateYtDlp,
        autoUpdateFfmpeg:
            json['autoUpdateFfmpeg'] as bool? ?? fallback.autoUpdateFfmpeg,
        startMinimized:
            json['startMinimized'] as bool? ?? fallback.startMinimized,
        debugLogs: json['debugLogs'] as bool? ?? fallback.debugLogs,
      );
    } catch (_) {
      return fallback;
    }
  }

  void setDownloadDirectory(String path) {
    final current = state.valueOrNull;
    if (current == null || path.trim().isEmpty) return;
    _set(current.copyWith(downloadDirectory: Directory(path)));
  }

  void setConcurrentDownloads(int value) {
    final current = state.valueOrNull;
    if (current == null) return;
    _set(current.copyWith(concurrentDownloads: value.clamp(1, 8)));
  }

  void setYtDlpChannel(YtDlpChannelSetting value) {
    final current = state.valueOrNull;
    if (current == null) return;
    _set(current.copyWith(ytDlpChannel: value));
  }

  void setProxyUrl(String value) {
    final current = state.valueOrNull;
    if (current == null) return;
    _set(current.copyWith(proxyUrl: value.trim()));
  }

  void setCookiesPath(String value) {
    final current = state.valueOrNull;
    if (current == null) return;
    _set(current.copyWith(cookiesPath: value.trim()));
  }

  void setCustomFfmpegPath(String value) {
    final current = state.valueOrNull;
    if (current == null) return;
    _set(current.copyWith(customFfmpegPath: value.trim()));
  }

  void setVideoPlayerPath(String value) {
    final current = state.valueOrNull;
    if (current == null) return;
    _set(current.copyWith(videoPlayerPath: value.trim()));
  }

  void setAccentColor(Color value) {
    final current = state.valueOrNull;
    if (current == null) return;
    _set(current.copyWith(accentColor: value));
  }

  void setAppColor(Color value) {
    final current = state.valueOrNull;
    if (current == null) return;
    _set(current.copyWith(appColor: value));
  }

  void setThemeMode(AppThemeModeSetting value) {
    final current = state.valueOrNull;
    if (current == null) return;
    _set(current.copyWith(themeMode: value));
  }

  void setThemePreset(AppThemePreset value) {
    final current = state.valueOrNull;
    if (current == null) return;
    _set(
      current.copyWith(
        themePreset: value,
        appColor: value.appColor,
        accentColor: value.accent,
      ),
    );
  }

  void setAutoUpdateYtDlp({required bool value}) {
    final current = state.valueOrNull;
    if (current == null) return;
    _set(current.copyWith(autoUpdateYtDlp: value));
  }

  void setAutoUpdateFfmpeg({required bool value}) {
    final current = state.valueOrNull;
    if (current == null) return;
    _set(current.copyWith(autoUpdateFfmpeg: value));
  }

  void setStartMinimized({required bool value}) {
    final current = state.valueOrNull;
    if (current == null) return;
    _set(current.copyWith(startMinimized: value));
  }

  void setDebugLogs({required bool value}) {
    final current = state.valueOrNull;
    if (current == null) return;
    _set(current.copyWith(debugLogs: value));
  }

  void _set(AppSettingsState next) {
    state = AsyncData(next);
    unawaited(_persist(next));
  }

  Future<void> _persist(AppSettingsState value) async {
    final database = await ref.read(databaseProvider.future);
    database.saveSetting(
      'app_settings',
      jsonEncode({
        'downloadDirectory': value.downloadDirectory.path,
        'concurrentDownloads': value.concurrentDownloads,
        'ytDlpChannel': value.ytDlpChannel.name,
        'proxyUrl': value.proxyUrl,
        'cookiesPath': value.cookiesPath,
        'customFfmpegPath': value.customFfmpegPath,
        'videoPlayerPath': value.videoPlayerPath,
        'appColor': value.appColor.toARGB32(),
        'accentColor': value.accentColor.toARGB32(),
        'themeMode': value.themeMode.name,
        'themePreset': value.themePreset.name,
        'autoUpdateYtDlp': value.autoUpdateYtDlp,
        'autoUpdateFfmpeg': value.autoUpdateFfmpeg,
        'startMinimized': value.startMinimized,
        'debugLogs': value.debugLogs,
      }),
    );
  }

  T _enumByName<T extends Enum>(List<T> values, String? name, T fallback) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    return fallback;
  }
}

final settingsControllerProvider =
    AsyncNotifierProvider<SettingsController, AppSettingsState>(
      SettingsController.new,
    );
