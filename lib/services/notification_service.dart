import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:permission_handler/permission_handler.dart';

import '../models/journal.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

  NotificationService({FlutterLocalNotificationsPlugin? plugin})
      : flutterLocalNotificationsPlugin =
            plugin ?? FlutterLocalNotificationsPlugin();

  static const String _channelId = 'journal_notifications_v2';
  static const String _channelName = 'Journal Reminders';
  static const String _channelDesc = 'Reminders to write in your journal';

  Future<void> init() async {
    try {
      tz.initializeTimeZones();
      try {
        final String localTimezone = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(localTimezone));
      } catch (e) {
        debugPrint('Error setting local timezone: $e');
        // Fallback to generic UTC if local fails
        tz.setLocalLocation(tz.getLocation('UTC'));
      }

      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );

      const InitializationSettings initializationSettings =
          InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );

      await flutterLocalNotificationsPlugin.initialize(initializationSettings);

      // Explicitly create the channel for Android
      await _createNotificationChannel();

      // Check pending notifications debug
      final pending =
          await flutterLocalNotificationsPlugin.pendingNotificationRequests();
      debugPrint('Pending notifications: ${pending.length}');
    } catch (e) {
      debugPrint('Error initializing functionality: $e');
    }
  }

  Future<void> _createNotificationChannel() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDesc,
      importance: Importance.max,
      playSound: true,
      showBadge: true,
    );

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  Future<bool> checkBatteryOptimizations() async {
    final status = await Permission.ignoreBatteryOptimizations.status;
    debugPrint("Battery optimization status: $status");
    return status.isGranted;
  }

  Future<bool> requestBatteryOptimizations() async {
    final status = await Permission.ignoreBatteryOptimizations.request();
    return status.isGranted;
  }

  Future<bool> requestPermissions() async {
    final androidImplementation =
        flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    final bool? notificationsGranted =
        await androidImplementation?.requestNotificationsPermission();

    if (androidImplementation != null) {
      try {
        await androidImplementation.requestExactAlarmsPermission();
      } catch (e) {
        debugPrint('Error requesting exact alarms permission: $e');
      }
    }

    return notificationsGranted ?? false;
  }

  tz.TZDateTime _nextInstanceOfTime(TimeOfDay time, int weekDay) {
    // Current time in local timezone
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);

    // Dart Weekday: Mon=1 ... Sun=7
    // User Pref Weekday: Mon=0 ... Sun=6 (as stored in List<bool>)
    // Target weekday in Dart format:
    int targetDartWeekday = weekDay + 1;

    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );

    // If scheduled date is in the past, move to next day initially
    // (This is a simplified approach, logic below handles precise day matching)
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    // Move forward until we hit the correct weekday
    while (scheduledDate.weekday != targetDartWeekday) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    return scheduledDate;
  }

  Future<void> scheduleJournalNotifications(Journal journal) async {
    // Web does not support zonedSchedule in this plugin
    if (kIsWeb) return;

    // Always cancel old ones first to avoid duplicates or stale data
    await cancelJournalNotifications(journal.id);

    if (!journal.notificationsEnabled) {
      return;
    }

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    // Generate a unique base ID for this journal
    // Limitation: hashCode might collide, but rare enough for this scale.
    int journalHash = journal.id.hashCode;

    // We will use journalHash + offset as notification ID.
    // Offset logic: dayIndex (0-6) * 100 + timeIndex (0-11)
    // This allows up to 100 times per day (way more than needed)

    int count = 0;

    for (int dayIndex = 0;
        dayIndex < journal.notificationDays.length;
        dayIndex++) {
      if (journal.notificationDays[dayIndex]) {
        for (int timeIndex = 0;
            timeIndex < journal.notificationTimes.length;
            timeIndex++) {
          final timeStr = journal.notificationTimes[timeIndex];
          final timeParts = timeStr.split(':');
          final time = TimeOfDay(
              hour: int.parse(timeParts[0]), minute: int.parse(timeParts[1]));

          // Unique ID calculation
          int notificationId = journalHash + (dayIndex * 100) + timeIndex;

          try {
            await flutterLocalNotificationsPlugin.zonedSchedule(
              notificationId,
              journal.name,
              journal.notificationPhrase,
              _nextInstanceOfTime(time, dayIndex),
              platformChannelSpecifics,
              androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
              matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
            );
            count++;
          } catch (e) {
            debugPrint('Error scheduling notification: $e');
          }
        }
      }
    }
    debugPrint('Scheduled $count notifications for journal ${journal.name}');
  }

  Future<void> showTestNotification() async {
    try {
      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
      );
      const NotificationDetails platformChannelSpecifics =
          NotificationDetails(android: androidPlatformChannelSpecifics);

      await flutterLocalNotificationsPlugin.show(
        888,
        'Test Notification',
        'This is a test notification to verify permissions and settings.',
        platformChannelSpecifics,
      );
    } catch (e) {
      debugPrint("Error showing test notification: $e");
      rethrow;
    }
  }

  Future<String> scheduleTestNotification() async {
    try {
      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
      );
      const NotificationDetails platformChannelSpecifics =
          NotificationDetails(android: androidPlatformChannelSpecifics);

      final now = tz.TZDateTime.now(tz.local);
      final scheduledDate = now.add(const Duration(seconds: 10));

      // 1. Exact Alarm (10s)
      await flutterLocalNotificationsPlugin.zonedSchedule(
        889,
        'Scheduled Exact Test',
        'Exact notification (10s ago).',
        scheduledDate,
        platformChannelSpecifics,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );

      // 2. Inexact Alarm (15s) - Backup test
      final scheduledDateInexact = now.add(const Duration(seconds: 15));
      await flutterLocalNotificationsPlugin.zonedSchedule(
        890,
        'Scheduled Inexact Test',
        'Inexact notification (15s ago).',
        scheduledDateInexact,
        platformChannelSpecifics,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );

      return "Exact (10s): ${scheduledDate.toString()}\nInexact (15s): ${scheduledDateInexact.toString()}\n(TZ: ${tz.local.name})";
    } catch (e) {
      debugPrint("Error scheduling test notification: $e");
      rethrow;
    }
  }

  Future<void> cancelJournalNotifications(String journalId) async {
    int journalHash = journalId.hashCode;

    // Cancel all possible slots (7 days * 12 potential times)
    // Using the same id generation logic: base + (day * 100) + time
    for (int day = 0; day < 7; day++) {
      for (int time = 0; time < 12; time++) {
        await flutterLocalNotificationsPlugin
            .cancel(journalHash + (day * 100) + time);
      }
    }
  }
}
