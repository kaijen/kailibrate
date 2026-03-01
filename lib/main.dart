import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'core/services/notification_service.dart';
import 'app.dart';

void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      tz.initializeTimeZones();
      await NotificationService.instance.initialize();
      runApp(const ProviderScope(child: CallibrateApp()));
    },
    (error, stack) {
      debugPrint('Unhandled error: $error\n$stack');
    },
  );
}
