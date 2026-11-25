import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:task_flow_v2/core/notifications/task_notification_service.dart';
import 'package:task_flow_v2/core/notifications/task_reminder_coordinator.dart';

final taskNotificationDriverProvider = Provider<TaskNotificationDriver>(
  (ref) => TaskNotificationService.instance,
);

final notificationSettingsStoreProvider = Provider<NotificationSettingsStore>(
  (ref) => SecureNotificationSettingsStore(),
);

final taskReminderCoordinatorProvider =
    Provider<TaskReminderCoordinatorContract>(
      (ref) => TaskReminderCoordinator(
        driver: ref.watch(taskNotificationDriverProvider),
        settingsStore: ref.watch(notificationSettingsStoreProvider),
      ),
    );
