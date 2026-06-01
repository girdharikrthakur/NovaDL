import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../store/settings_controller.dart';
import '../pages/dashboard/dashboard_page.dart';
import '../pages/downloads/downloads_page.dart';
import '../pages/library/library_page.dart';
import '../pages/settings/settings_page.dart';
import '../pages/subscriptions/subscriptions_page.dart';
import 'shell.dart';

GoRouter _buildRouter({required bool useNativeChrome}) => GoRouter(
  initialLocation: '/',
  routes: [
    ShellRoute(
      builder: (context, state, child) =>
          AppShell(useNativeChrome: useNativeChrome, child: child),
      routes: [
        GoRoute(path: '/', builder: (_, __) => const DashboardPage()),
        GoRoute(path: '/downloads', builder: (_, __) => const DownloadsPage()),
        GoRoute(path: '/library', builder: (_, __) => const LibraryPage()),
        GoRoute(
          path: '/subscriptions',
          builder: (_, __) => const SubscriptionsPage(),
        ),
        GoRoute(path: '/settings', builder: (_, __) => const SettingsPage()),
      ],
    ),
  ],
);

final class NovaDLApp extends ConsumerStatefulWidget {
  const NovaDLApp({this.useNativeChrome = true, super.key});

  final bool useNativeChrome;

  @override
  ConsumerState<NovaDLApp> createState() => _NovaDLAppState();
}

final class _NovaDLAppState extends ConsumerState<NovaDLApp> {
  late final GoRouter _router = _buildRouter(
    useNativeChrome: widget.useNativeChrome,
  );

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsControllerProvider).valueOrNull;
    final accent = settings?.accentColor ?? const Color(0xFF60A5FA);
    final appColor = settings?.appColor ?? const Color(0xFF3B82F6);
    final themeMode = switch (settings?.themeMode) {
      AppThemeModeSetting.system => ThemeMode.system,
      AppThemeModeSetting.light => ThemeMode.light,
      _ => ThemeMode.dark,
    };
    return MaterialApp.router(
      title: 'NovaDL',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(seed: accent, appColor: appColor),
      darkTheme: AppTheme.dark(seed: accent, appColor: appColor),
      themeMode: themeMode,
      routerConfig: _router,
    );
  }
}
