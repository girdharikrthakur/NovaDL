import 'package:flutter/material.dart';

import '../../components/panel.dart';

final class SubscriptionsPage extends StatelessWidget {
  const SubscriptionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Watchers',
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.rss_feed),
              label: const Text('Follow'),
            ),
          ],
        ),
        const SizedBox(height: 18),
        const Expanded(
          child: Panel(
            child: Center(
              child: Text(
                'Channel and playlist subscriptions with scheduled checks, keyword filters, and auto-enqueue rules.',
              ),
            ),
          ),
        ),
      ],
    );
  }
}
