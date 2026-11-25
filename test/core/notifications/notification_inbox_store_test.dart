import 'package:flutter_test/flutter_test.dart';
import 'package:task_flow_v2/core/notifications/notification_inbox_store.dart';
import 'package:task_flow_v2/core/time/app_time_zone.dart';

void main() {
  setUpAll(initializeAppTimeZone);

  test('delivery status compares absolute instants in the app timezone', () {
    final now = nowInAppTime();
    final delivered = NotificationInboxItem(
      taskId: 'task-1',
      notificationId: 1,
      title: 'Task',
      body: 'Reminder',
      scheduledAt: now.subtract(const Duration(minutes: 1)).toUtc(),
    );
    final pending = NotificationInboxItem(
      taskId: 'task-2',
      notificationId: 2,
      title: 'Task',
      body: 'Reminder',
      scheduledAt: now.add(const Duration(minutes: 1)).toUtc(),
    );

    expect(delivered.isDelivered, isTrue);
    expect(pending.isDelivered, isFalse);
  });
}
