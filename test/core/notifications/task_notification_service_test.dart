import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:task_flow_v2/core/notifications/task_notification_service.dart';
import 'package:task_flow_v2/features/tasks/data/models/task_model.dart';

// ignore: implementation_imports
import 'package:flutter_local_notifications/src/platform_flutter_local_notifications.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const timezoneChannel = MethodChannel('flutter_timezone');
  const notificationsChannel = MethodChannel(
    'dexterous.com/flutter/local_notifications',
  );

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      ..setMockMethodCallHandler(timezoneChannel, null)
      ..setMockMethodCallHandler(notificationsChannel, null);
  });

  test('preserves plugin errors and accepts iOS permission=false', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    IOSFlutterLocalNotificationsPlugin.registerWith();
    var initializationAttempts = 0;
    Map<Object?, Object?>? scheduledArguments;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      ..setMockMethodCallHandler(
        timezoneChannel,
        (call) async => 'America/Los_Angeles',
      )
      ..setMockMethodCallHandler(notificationsChannel, (call) async {
        if (call.method == 'initialize') {
          initializationAttempts++;
          if (initializationAttempts == 1) {
            throw PlatformException(
              code: 'native-init-failed',
              message: 'original native error',
            );
          }

          final arguments = call.arguments as Map<Object?, Object?>;
          expect(arguments['requestAlertPermission'], false);
          expect(arguments['requestBadgePermission'], false);
          expect(arguments['requestSoundPermission'], false);
          return false;
        }

        if (call.method == 'getNotificationAppLaunchDetails') {
          return {'notificationLaunchedApp': false};
        }

        if (call.method == 'pendingNotificationRequests' ||
            call.method == 'getActiveNotifications') {
          return <Object?>[];
        }

        if (call.method == 'zonedSchedule') {
          scheduledArguments = call.arguments as Map<Object?, Object?>;
          return null;
        }

        fail('Unexpected notification method: ${call.method}');
      });

    final service = TaskNotificationService.instance;
    await expectLater(
      service.initialize(),
      throwsA(
        isA<PlatformException>()
            .having((error) => error.code, 'code', 'native-init-failed')
            .having(
              (error) => error.message,
              'message',
              'original native error',
            ),
      ),
    );

    await Future.wait([
      service.initialize(),
      service.initialize(),
      service.initialize(),
    ]);

    expect(initializationAttempts, 2);

    await service.scheduleTaskReminder(
      TaskModel(
        id: 'foreground-reminder',
        title: 'Foreground reminder',
        description: '',
        dueDate: DateTime.now().add(const Duration(minutes: 5)),
        priority: TaskPriority.medium,
        category: 'Work',
        isCompleted: false,
        reminderMinutesBefore: 0,
      ),
    );

    final platformSpecifics =
        scheduledArguments!['platformSpecifics'] as Map<Object?, Object?>;
    expect(platformSpecifics['presentAlert'], true);
    expect(platformSpecifics['presentBanner'], true);
    expect(platformSpecifics['presentList'], true);
    expect(platformSpecifics['presentSound'], true);
  });
}
