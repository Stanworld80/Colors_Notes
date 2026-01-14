import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;


import '../models/journal.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();
    final String localTimezone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(localTimezone));

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  tz.TZDateTime _nextInstanceOfTime(TimeOfDay time, int weekDay) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    // The weekday in Dart's DateTime is 1 for Monday and 7 for Sunday.
    // We use 0 for Monday and 6 for Sunday. So, we adjust.
    int dartWeekday = weekDay + 1;

    tz.TZDateTime scheduledDate =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, time.hour, time.minute);

    while (scheduledDate.weekday != dartWeekday || scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  Future<void> scheduleJournalNotifications(Journal journal) async {
    await cancelJournalNotifications(journal.id);

    if (!journal.notificationsEnabled) {
      return;
    }

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'journal_notification_channel',
      'Journal Reminders',
      channelDescription: 'Reminders to write in your journal',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: false,
    );
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    int notificationId = journal.id.hashCode;

    for (int dayIndex = 0; dayIndex < journal.notificationDays.length; dayIndex++) {
      if (journal.notificationDays[dayIndex]) {
        for (final timeStr in journal.notificationTimes) {
          final timeParts = timeStr.split(':');
          final time = TimeOfDay(hour: int.parse(timeParts[0]), minute: int.parse(timeParts[1]));

          await flutterLocalNotificationsPlugin.zonedSchedule(
            notificationId++,
            journal.name,
            journal.notificationPhrase,
            _nextInstanceOfTime(time, dayIndex),
            platformChannelSpecifics,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          );
        }
      }
    }
  }

  Future<void> cancelJournalNotifications(String journalId) async {
    int baseId = journalId.hashCode;
    // Cancel a wide range of potential IDs, as we don't store them.
    // This should cover all notifications for a journal (7 days * 12 times).
    for (int i = 0; i < 84; i++) {
      await flutterLocalNotificationsPlugin.cancel(baseId + i);
    }
  }
}
