import 'dart:async';

import 'package:logging/logging.dart';

final class SubscriptionService {
  SubscriptionService({required this.logger});

  final Logger logger;

  Future<void> checkDueSubscriptions() async {
    logger.info(
      'Subscription check hook ready: query due rows, analyze channel playlists, enqueue new uploads.',
    );
  }
}
