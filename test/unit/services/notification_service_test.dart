import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:colors_notes/services/notification_service.dart';
import 'package:colors_notes/models/journal.dart';
import 'package:colors_notes/models/palette.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:cloud_firestore/cloud_firestore.dart';

// Annotation to generate the mocks
@GenerateMocks(
    [FlutterLocalNotificationsPlugin, AndroidFlutterLocalNotificationsPlugin])
import 'notification_service_test.mocks.dart';

void main() {
  late NotificationService service;
  late MockFlutterLocalNotificationsPlugin mockPlugin;
  late MockAndroidFlutterLocalNotificationsPlugin mockAndroidPlugin;

  setUpAll(() {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('UTC'));
  });

  setUp(() {
    mockPlugin = MockFlutterLocalNotificationsPlugin();
    mockAndroidPlugin = MockAndroidFlutterLocalNotificationsPlugin();
    service = NotificationService(plugin: mockPlugin);

    // Mock resolvePlatformSpecificImplementation for generic calls
    when(mockPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>())
        .thenReturn(mockAndroidPlugin);
  });

  group('NotificationService', () {
    test('init initializes local notifications plugin', () async {
      // Arrange
      when(mockPlugin.initialize(any,
              onDidReceiveNotificationResponse:
                  anyNamed('onDidReceiveNotificationResponse'),
              onDidReceiveBackgroundNotificationResponse:
                  anyNamed('onDidReceiveBackgroundNotificationResponse')))
          .thenAnswer((_) async => true);

      when(mockPlugin.pendingNotificationRequests())
          .thenAnswer((_) async => []);

      // Act
      await service.init();

      // Assert
      verify(mockPlugin.initialize(any)).called(1);
      // It also tries to create a channel on Android
      verify(mockAndroidPlugin.createNotificationChannel(any)).called(1);
    });

    test('scheduleJournalNotifications schedules notifications when enabled',
        () async {
      // Arrange
      final journal = Journal(
        id: 'journal1',
        userId: 'user1',
        name: 'My Journal',
        notificationsEnabled: true,
        notificationDays: [
          true,
          false,
          false,
          false,
          false,
          false,
          false
        ], // Monday only
        notificationTimes: ['09:00'],
        notificationPhrase: 'Time to write!',
        createdAt: Timestamp.now(),
        lastUpdatedAt: Timestamp.now(),
        palette:
            Palette(id: 'p1', name: 'Default', colors: [], userId: 'user1'),
      );

      when(mockPlugin.cancel(any)).thenAnswer((_) async => null);
      when(mockPlugin.zonedSchedule(any, any, any, any, any,
              androidScheduleMode: anyNamed('androidScheduleMode'),
              matchDateTimeComponents: anyNamed('matchDateTimeComponents')))
          .thenAnswer((_) async => null);

      // Act
      await service.scheduleJournalNotifications(journal);

      // Assert
      // 1. Logs should be cancelled first (7 days * 12 potential slots = many cancels)
      // We just verify at least some were cancelled or the specific logic
      verify(mockPlugin.cancel(any)).called(greaterThan(0));

      // 2. Notification should be scheduled
      // We expect 1 notification (Monday 09:00 matches)
      verify(mockPlugin.zonedSchedule(
              any, 'My Journal', 'Time to write!', any, any,
              androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
              matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime))
          .called(1);
    });

    test('scheduleJournalNotifications does nothing if disabled', () async {
      // Arrange
      final journal = Journal(
        id: 'journal1',
        userId: 'user1',
        name: 'My Journal',
        notificationsEnabled: false, // DISABLED
        notificationDays: [true, false, false, false, false, false, false],
        notificationTimes: ['09:00'],
        notificationPhrase: 'Time to write!',
        createdAt: Timestamp.now(),
        lastUpdatedAt: Timestamp.now(),
        palette:
            Palette(id: 'p1', name: 'Default', colors: [], userId: 'user1'),
      );

      when(mockPlugin.cancel(any)).thenAnswer((_) async => null);

      // Act
      await service.scheduleJournalNotifications(journal);

      // Assert
      verify(mockPlugin.cancel(any))
          .called(greaterThan(0)); // Cleaning up is expected

      // Verify NO scheduling happen
      verifyNever(mockPlugin.zonedSchedule(any, any, any, any, any,
          androidScheduleMode: anyNamed('androidScheduleMode'),
          matchDateTimeComponents: anyNamed('matchDateTimeComponents')));
    });

    test('cancelJournalNotifications calls cancel on plugin', () async {
      // Act
      await service.cancelJournalNotifications('journal1');

      // Assert
      // 7 days * 12 times = 84 cancels
      verify(mockPlugin.cancel(any)).called(84);
    });
  });
}
