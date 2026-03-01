import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';

void main() {
  runZonedGuarded(
    () {
      WidgetsFlutterBinding.ensureInitialized();
      runApp(const ProviderScope(child: CallibrateApp()));
    },
    (error, stack) {
      debugPrint('Unhandled error: $error\n$stack');
    },
  );
}
