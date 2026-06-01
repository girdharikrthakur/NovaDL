import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novadl/ui/app/novadl_app.dart';

void main() {
  testWidgets('renders NovaDL desktop shell', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1320, 840));
    await tester.pumpWidget(
      const ProviderScope(child: NovaDLApp(useNativeChrome: false)),
    );
    await tester.pumpAndSettle();

    expect(find.text('NovaDL'), findsOneWidget);
    expect(find.text('Dashboard'), findsWidgets);
    expect(find.text('Downloads'), findsOneWidget);
    expect(find.text('Current downloads'), findsOneWidget);
  });
}
