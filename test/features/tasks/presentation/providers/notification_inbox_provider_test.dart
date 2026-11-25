import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:task_flow_v2/core/notifications/notification_inbox_store.dart';
import 'package:task_flow_v2/core/time/app_time_zone.dart';
import 'package:task_flow_v2/features/tasks/presentation/providers/notification_inbox_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeAppTimeZone);

  const storageChannel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );
  const badgeChannel = MethodChannel('task_flow/notification_badge');
  const timezoneChannel = MethodChannel('flutter_timezone');
  const notificationsChannel = MethodChannel(
    'dexterous.com/flutter/local_notifications',
  );
  String? storedValue;
  Object? readError;
  Object? badgeError;
  final badgeCounts = <int>[];

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    IOSFlutterLocalNotificationsPlugin.registerWith();
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
    messenger.setMockMethodCallHandler(timezoneChannel, (call) async {
      return 'Asia/Ho_Chi_Minh';
    });
    messenger.setMockMethodCallHandler(notificationsChannel, (call) async {
      if (call.method == 'initialize') {
        return false;
      }
      if (call.method == 'getNotificationAppLaunchDetails') {
        return {'notificationLaunchedApp': false};
      }
      if (call.method == 'pendingNotificationRequests' ||
          call.method == 'getActiveNotifications') {
        return <Object?>[];
      }
      if (call.method == 'zonedSchedule') return null;
      fail('Unexpected notification method: ${call.method}');
    });
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger
      ..setMockMethodCallHandler(storageChannel, null)
      ..setMockMethodCallHandler(badgeChannel, null)
      ..setMockMethodCallHandler(timezoneChannel, null)
      ..setMockMethodCallHandler(notificationsChannel, null);
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

  void writeItems(List<NotificationInboxItem> items) {
    storedValue = jsonEncode(items.map((value) => value.toJson()).toList());
  }

  test('refresh reads state and delegates badge sync once', () async {
    final now = nowInAppTime();
    writeItems([
      item('future', scheduledAt: now.add(const Duration(minutes: 5))),
      item('unread', scheduledAt: now),
      item('read', scheduledAt: now, readAt: now),
    ]);
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(notificationInboxProvider.notifier).refresh();

    final state = container.read(notificationInboxProvider);
    expect(state.isLoading, isFalse);
    expect(state.items, hasLength(3));
    expect(state.deliveredItems, hasLength(2));
    expect(state.unreadCount, 1);
    expect(badgeCounts, [1]);
  });

  test('empty inbox refreshes state and syncs an absolute zero', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(notificationInboxProvider.notifier).refresh();

    final state = container.read(notificationInboxProvider);
    expect(state.items, isEmpty);
    expect(state.unreadCount, 0);
    expect(badgeCounts, [0]);
  });

  test(
    'inbox read failure preserves previous state and skips badge sync',
    () async {
      final now = nowInAppTime();
      writeItems([item('unread', scheduledAt: now)]);
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(notificationInboxProvider.notifier);

      await notifier.refresh();
      readError = StateError('storage unavailable');
      badgeCounts.clear();

      await notifier.refresh();

      final state = container.read(notificationInboxProvider);
      expect(state.items, hasLength(1));
      expect(state.unreadCount, 1);
      expect(badgeCounts, isEmpty);
    },
  );

  test('native badge failure does not discard inbox state', () async {
    final now = nowInAppTime();
    writeItems([item('unread', scheduledAt: now)]);
    badgeError = PlatformException(code: 'badge-unavailable');
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(notificationInboxProvider.notifier).refresh();

    final state = container.read(notificationInboxProvider);
    expect(state.isLoading, isFalse);
    expect(state.items, hasLength(1));
    expect(state.unreadCount, 1);
  });

  test(
    'mark one read updates state and keeps future notification unread',
    () async {
      final now = nowInAppTime();
      writeItems([
        item('delivered', scheduledAt: now),
        item('future', scheduledAt: now.add(const Duration(minutes: 5))),
      ]);
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(notificationInboxProvider.notifier);

      await notifier.refresh();
      badgeCounts.clear();
      await notifier.markRead('delivered');

      final state = container.read(notificationInboxProvider);
      expect(state.unreadCount, 0);
      expect(
        state.items
            .firstWhere((notification) => notification.taskId == 'delivered')
            .isRead,
        isTrue,
      );
      expect(
        state.items
            .firstWhere((notification) => notification.taskId == 'future')
            .isRead,
        isFalse,
      );
      expect(badgeCounts, [0]);
    },
  );

  test(
    'mark all read updates state and keeps future notification unread',
    () async {
      final now = nowInAppTime();
      writeItems([
        item('delivered', scheduledAt: now),
        item('future', scheduledAt: now.add(const Duration(minutes: 5))),
      ]);
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(notificationInboxProvider.notifier);

      await notifier.refresh();
      badgeCounts.clear();
      await notifier.markAllRead();

      final state = container.read(notificationInboxProvider);
      expect(state.unreadCount, 0);
      expect(
        state.items
            .firstWhere((notification) => notification.taskId == 'delivered')
            .isRead,
        isTrue,
      );
      expect(
        state.items
            .firstWhere((notification) => notification.taskId == 'future')
            .isRead,
        isFalse,
      );
      expect(badgeCounts, [0]);
    },
  );

  test('marking a future notification directly leaves it unread', () async {
    final now = nowInAppTime();
    writeItems([
      item('future', scheduledAt: now.add(const Duration(minutes: 5))),
    ]);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(notificationInboxProvider.notifier);

    await notifier.refresh();
    badgeCounts.clear();
    await notifier.markRead('future');

    final state = container.read(notificationInboxProvider);
    expect(state.unreadCount, 0);
    expect(state.items.single.isRead, isFalse);
    expect(badgeCounts, [0]);
  });
}
