import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task_flow_v2/core/notifications/notification_inbox_store.dart';
import 'package:task_flow_v2/core/notifications/task_notification_service.dart';
import 'package:task_flow_v2/core/time/app_time_zone.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const storageChannel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );
  const badgeChannel = MethodChannel('task_flow/notification_badge');
  String? storedValue;
  Object? readError;
  Object? badgeError;
  final badgeCounts = <int>[];

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    storedValue = null;
    readError = null;
    badgeError = null;
    badgeCounts.clear();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(storageChannel, (call) async {
      if (call.method == 'read') {
        if (readError != null) throw readError!;
        return storedValue;
      }
      if (call.method == 'write') {
        storedValue = (call.arguments as Map)['value'] as String;
        return null;
      }
      fail('Unexpected storage method: ${call.method}');
    });
    messenger.setMockMethodCallHandler(badgeChannel, (call) async {
      if (call.method != 'setBadgeCount') {
        fail('Unexpected badge method: ${call.method}');
      }
      if (badgeError != null) throw badgeError!;
      badgeCounts.add(call.arguments as int);
      return null;
    });
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger
      ..setMockMethodCallHandler(storageChannel, null)
      ..setMockMethodCallHandler(badgeChannel, null);
  });

  NotificationInboxItem item(
    String id, {
    required DateTime scheduledAt,
    DateTime? readAt,
  }) => NotificationInboxItem(
    taskId: id,
    notificationId: id.hashCode,
    title: id,
    body: 'Reminder',
    scheduledAt: scheduledAt,
    readAt: readAt,
  );

  Future<void> writeItems(List<NotificationInboxItem> items) async {
    storedValue = jsonEncode(items.map((value) => value.toJson()).toList());
  }

  test('sync counts only delivered unread inbox items', () async {
    final now = nowInAppTime();
    await writeItems([
      item('future', scheduledAt: now.add(const Duration(minutes: 5))),
      item('unread', scheduledAt: now),
      item('read', scheduledAt: now, readAt: now),
    ]);

    final count = await TaskNotificationService.instance
        .syncIconBadgeFromInbox();

    expect(count, 1);
    expect(badgeCounts, [1]);
  });

  test('empty inbox sends an absolute zero badge count', () async {
    final count = await TaskNotificationService.instance
        .syncIconBadgeFromInbox();

    expect(count, 0);
    expect(badgeCounts, [0]);
  });

  test(
    'badge channel errors do not change the returned unread count',
    () async {
      final now = nowInAppTime();
      await writeItems([item('unread', scheduledAt: now)]);
      badgeError = PlatformException(code: 'badge-unavailable');

      await expectLater(
        TaskNotificationService.instance.syncIconBadgeFromInbox(),
        completion(1),
      );
      expect(storedValue, isNotNull);
      expect(badgeCounts, isEmpty);
    },
  );

  test('inbox read errors propagate without sending a zero badge', () async {
    readError = StateError('storage unavailable');

    await expectLater(
      TaskNotificationService.instance.syncIconBadgeFromInbox(),
      throwsA(isA<PlatformException>()),
    );
    expect(badgeCounts, isEmpty);

    readError = null;
    final count = await TaskNotificationService.instance
        .syncIconBadgeFromInbox();
    expect(count, 0);
    expect(badgeCounts, [0]);
  });
}
