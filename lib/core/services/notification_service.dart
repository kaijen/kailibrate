import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import '../database/app_database.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const _channelId = 'callibrate_deadlines';
  static const _channelName = 'Auflösungsfristen';
  static const _channelDesc =
      'Erinnert dich, wenn eine Vorhersage aufgelöst werden soll.';

  Future<void> initialize() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await _plugin.initialize(initSettings);

    // Benachrichtigungskanal anlegen (Android 8+)
    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDesc,
      importance: Importance.defaultImportance,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // POST_NOTIFICATIONS-Berechtigung anfragen (Android 13+)
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  Future<void> scheduleDeadlineNotifications(
    int questionId,
    String questionText,
    DateTime deadline,
  ) async {
    final now = tz.TZDateTime.now(tz.local);

    final dayBefore = tz.TZDateTime(
      tz.local,
      deadline.year,
      deadline.month,
      deadline.day - 1,
      9,
    );
    final deadlineDay = tz.TZDateTime(
      tz.local,
      deadline.year,
      deadline.month,
      deadline.day,
      9,
    );

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );
    const details = NotificationDetails(android: androidDetails);

    if (dayBefore.isAfter(now)) {
      await _plugin.zonedSchedule(
        questionId * 2,
        'Vorhersage läuft morgen ab',
        questionText,
        dayBefore,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }

    if (deadlineDay.isAfter(now)) {
      await _plugin.zonedSchedule(
        questionId * 2 + 1,
        'Vorhersage läuft heute ab',
        questionText,
        deadlineDay,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  Future<void> cancelNotificationsForQuestion(int questionId) async {
    await _plugin.cancel(questionId * 2);
    await _plugin.cancel(questionId * 2 + 1);
  }

  Future<void> rescheduleAll(List<PredictionView> predictions) async {
    await _plugin.cancelAll();
    for (final p in predictions) {
      final deadline = p.question.deadline;
      if (deadline == null) continue;
      if (p.status == PredictionStatus.resolved) continue;
      if (deadline.isBefore(DateTime.now())) continue;
      try {
        await scheduleDeadlineNotifications(
          p.question.id,
          p.question.questionText,
          deadline,
        );
      } catch (e) {
        debugPrint('Notification scheduling failed for ${p.question.id}: $e');
      }
    }
  }
}
