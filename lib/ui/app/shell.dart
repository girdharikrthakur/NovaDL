import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

final class AppShell extends StatelessWidget {
  const AppShell({required this.child, this.useNativeChrome = true, super.key});

  final Widget child;
  final bool useNativeChrome;

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final index = switch (location) {
      '/downloads' => 1,
      '/library' => 2,
      '/subscriptions' => 3,
      '/settings' => 4,
      _ => 0,
    };

    return Scaffold(
      body: Stack(
        children: [
          const _FlatBackdrop(),
          Column(
            children: [
              _TitleBar(useNativeChrome: useNativeChrome),
              Expanded(
                child: Row(
                  children: [
                    NavigationRail(
                      selectedIndex: index,
                      onDestinationSelected: (selected) =>
                          context.go(_pathForIndex(selected)),
                      labelType: NavigationRailLabelType.all,
                      destinations: const [
                        NavigationRailDestination(
                          icon: Icon(Icons.dashboard_outlined),
                          selectedIcon: Icon(Icons.dashboard),
                          label: Text('Dashboard'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.downloading_outlined),
                          selectedIcon: Icon(Icons.downloading),
                          label: Text('Downloads'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.video_library_outlined),
                          selectedIcon: Icon(Icons.video_library),
                          label: Text('Library'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.rss_feed_outlined),
                          selectedIcon: Icon(Icons.rss_feed),
                          label: Text('Watchers'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.tune_outlined),
                          selectedIcon: Icon(Icons.tune),
                          label: Text('Settings'),
                        ),
                      ],
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 24, 24),
                        child: child,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _pathForIndex(int index) => switch (index) {
    1 => '/downloads',
    2 => '/library',
    3 => '/subscriptions',
    4 => '/settings',
    _ => '/',
  };
}

final class _TitleBar extends StatelessWidget {
  const _TitleBar({required this.useNativeChrome});

  final bool useNativeChrome;

  @override
  Widget build(BuildContext context) {
    final content = Row(
      children: [
        const SizedBox(width: 18),
        Image.asset('assets/icons/novadl_logo_64.png', width: 24, height: 24),
        const SizedBox(width: 10),
        Text(
          'NovaDL',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const Spacer(),
        if (useNativeChrome) ...[
          MinimizeWindowButton(),
          MaximizeWindowButton(),
          CloseWindowButton(),
        ],
      ],
    );

    if (!useNativeChrome) {
      return SizedBox(height: 48, child: content);
    }

    return WindowTitleBarBox(child: MoveWindow(child: content));
  }
}

final class _FlatBackdrop extends StatelessWidget {
  const _FlatBackdrop();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
        ),
      ),
    );
  }
}
