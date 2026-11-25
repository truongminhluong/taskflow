import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task_flow_v2/core/notifications/task_reminder_coordinator.dart';
import 'package:task_flow_v2/features/tasks/data/models/task_model.dart';
import 'package:task_flow_v2/features/tasks/data/models/task_page_model.dart';
import 'package:task_flow_v2/features/tasks/data/models/task_overview_model.dart';
import 'package:task_flow_v2/features/tasks/domain/repositories/task_repository.dart';
import 'package:task_flow_v2/features/tasks/presentation/providers/notification_settings_provider.dart';
import 'package:task_flow_v2/features/tasks/presentation/providers/task_provider.dart';
import 'package:task_flow_v2/features/tasks/presentation/providers/task_reminder_coordinator_provider.dart';

void main() {
  group('NotificationSettingsNotifier', () {
    late _FakeRepository repository;
    late _FakeCoordinator coordinator;
    late ProviderContainer container;

    setUp(() {
      repository = _FakeRepository();
      coordinator = _FakeCoordinator();
      container = ProviderContainer(
        overrides: [
          taskRepositoryProvider.overrideWithValue(repository),
          taskReminderCoordinatorProvider.overrideWithValue(coordinator),
        ],
      );
    });

    tearDown(() => container.dispose());

    test(
      'loads current enabled state and detected permission revocation',
      () async {
        coordinator.readResult = const NotificationSettingsSnapshot(
          enabled: false,
          permissionGranted: false,
          permissionRevoked: true,
        );

        await _waitForInitialLoad(container);

        final state = container.read(notificationSettingsProvider);
        expect(state.enabled, isFalse);
        expect(state.permissionGranted, isFalse);
        expect(state.requiresSettingsHelp, isTrue);
        expect(state.errorMessage, contains('Cài đặt thiết bị'));
      },
    );

    test('enables immediately and restores task reminders afterward', () async {
      repository.tasks.add(_task('saved-task'));
      await _waitForInitialLoad(container);

      await container
          .read(notificationSettingsProvider.notifier)
          .setEnabled(true);

      final state = container.read(notificationSettingsProvider);
      expect(repository.getTasksCount, 1);
      expect(coordinator.enableCalls, 1);
      expect(coordinator.syncTasksCount, 1);
      expect(state.enabled, isTrue);
      expect(state.permissionGranted, isTrue);
      expect(state.isUpdating, isFalse);
    });

    test(
      'permission denial leaves switch off and provides settings recovery',
      () async {
        coordinator.enableResult = const NotificationSettingsSnapshot(
          enabled: true,
          permissionGranted: false,
          permissionRevoked: true,
        );
        await _waitForInitialLoad(container);

        await container
            .read(notificationSettingsProvider.notifier)
            .setEnabled(true);

        final state = container.read(notificationSettingsProvider);
        expect(state.enabled, isTrue);
        expect(state.permissionGranted, isFalse);
        expect(state.requiresSettingsHelp, isTrue);
        expect(state.errorMessage, contains('quyền thông báo'));
      },
    );

    test('scheduler failure never displays the setting as enabled', () async {
      coordinator.failEnable = true;
      await _waitForInitialLoad(container);

      await container
          .read(notificationSettingsProvider.notifier)
          .setEnabled(true);

      final state = container.read(notificationSettingsProvider);
      expect(state.enabled, isFalse);
      expect(state.errorMessage, contains('Không thể bật thông báo'));
    });

    test('turning notifications off cancels all app schedules', () async {
      coordinator.readResult = const NotificationSettingsSnapshot(
        enabled: true,
        permissionGranted: true,
      );
      await _waitForInitialLoad(container);

      await container
          .read(notificationSettingsProvider.notifier)
          .setEnabled(false);

      expect(coordinator.disableCount, 1);
      expect(container.read(notificationSettingsProvider).enabled, isFalse);
    });

    test(
      'app preference can be turned off while OS permission is missing',
      () async {
        coordinator.readResult = const NotificationSettingsSnapshot(
          enabled: true,
          permissionGranted: false,
          permissionRevoked: true,
        );
        await _waitForInitialLoad(container);

        await container
            .read(notificationSettingsProvider.notifier)
            .setEnabled(false);

        final state = container.read(notificationSettingsProvider);
        expect(coordinator.disableCount, 1);
        expect(state.enabled, isFalse);
        expect(state.requiresSettingsHelp, isFalse);
      },
    );

    test('failed task loading prevents enabling reminders', () async {
      repository.failGetTasks = true;
      await _waitForInitialLoad(container);

      await container
          .read(notificationSettingsProvider.notifier)
          .setEnabled(true);

      expect(coordinator.enableCalls, 1);
      expect(container.read(notificationSettingsProvider).enabled, isFalse);
    });

    test(
      'startup restoration failure preserves schedules and can retry',
      () async {
        coordinator.readResult = const NotificationSettingsSnapshot(
          enabled: true,
          permissionGranted: true,
        );
        repository.failGetTasks = true;

        await _waitForInitialLoad(container);

        expect(coordinator.syncTasksCount, 0);
        expect(
          container.read(notificationSettingsProvider).errorMessage,
          contains('khôi phục nhắc việc'),
        );

        repository.failGetTasks = false;
        await container.read(notificationSettingsProvider.notifier).refresh();

        expect(coordinator.syncTasksCount, 1);
        expect(
          container.read(notificationSettingsProvider).errorMessage,
          isNull,
        );
      },
    );

    test('enable failure does not pass partial data to restoration', () async {
      await _waitForInitialLoad(container);
      repository.failGetTasks = true;

      await container
          .read(notificationSettingsProvider.notifier)
          .setEnabled(true);

      expect(coordinator.enableCalls, 1);
      expect(coordinator.syncTasksCount, 0);
      expect(
        container.read(notificationSettingsProvider).errorMessage,
        contains('Không tải được công việc'),
      );
    });

    test('settings recovery action delegates to operating system', () async {
      await _waitForInitialLoad(container);

      await container
          .read(notificationSettingsProvider.notifier)
          .openSettings();

      expect(coordinator.openSettingsCount, 1);
    });

    test(
      'initial permission grant enables reminders and restores loaded tasks',
      () async {
        repository.tasks.add(_task('first-launch-task'));
        coordinator.initialPermissionResult =
            const NotificationSettingsSnapshot(
              enabled: true,
              permissionGranted: true,
            );

        await _waitForInitialLoad(container);

        final state = container.read(notificationSettingsProvider);
        expect(coordinator.initialPermissionCalls, 1);
        expect(repository.getTasksCount, 1);
        expect(state.enabled, isTrue);
        expect(state.permissionGranted, isTrue);
        expect(coordinator.syncTasksCount, 1);
      },
    );

    test(
      'initial permission denial keeps switch inactive and offers Settings',
      () async {
        coordinator.initialPermissionResult =
            const NotificationSettingsSnapshot(
              enabled: false,
              permissionGranted: false,
            );

        await _waitForInitialLoad(container);

        final state = container.read(notificationSettingsProvider);
        expect(state.enabled, isFalse);
        expect(state.permissionGranted, isFalse);
        expect(state.requiresSettingsHelp, isTrue);
        expect(state.errorMessage, contains('Cài đặt thiết bị'));
        expect(coordinator.syncTasksCount, 0);
      },
    );

    test(
      'refresh after OS permission is granted restores task reminders',
      () async {
        repository.tasks.add(_task('restored-task'));
        await _waitForInitialLoad(container);
        coordinator.readResult = const NotificationSettingsSnapshot(
          enabled: true,
          permissionGranted: true,
        );

        await container.read(notificationSettingsProvider.notifier).refresh();

        final state = container.read(notificationSettingsProvider);
        expect(state.enabled, isTrue);
        expect(state.permissionGranted, isTrue);
        expect(repository.getTasksCount, 1);
        expect(coordinator.syncTasksCount, 1);
      },
    );

    test(
      'permission revocation hides active switch without clearing app choice',
      () async {
        coordinator.readResult = const NotificationSettingsSnapshot(
          enabled: true,
          permissionGranted: false,
          permissionRevoked: true,
        );

        await _waitForInitialLoad(container);

        final state = container.read(notificationSettingsProvider);
        expect(state.enabled, isTrue);
        expect(state.permissionGranted, isFalse);
        expect(state.requiresSettingsHelp, isTrue);
      },
    );
  });
}

Future<void> _waitForInitialLoad(ProviderContainer container) async {
  container.read(notificationSettingsProvider);
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

TaskModel _task(String id) => TaskModel(
  id: id,
  title: 'Task $id',
  description: '',
  dueDate: DateTime(2026, 11, 3, 12),
  priority: TaskPriority.medium,
  category: 'Cá nhân',
  isCompleted: false,
  reminderMinutesBefore: 0,
);

final class _FakeRepository implements TaskRepository {
  final tasks = <TaskModel>[];
  int getTasksCount = 0;
  bool failGetTasks = false;

  @override
  Future<List<TaskModel>> getTasks() async {
    getTasksCount++;
    if (failGetTasks) throw StateError('load failed');
    return List.of(tasks);
  }

  @override
  Future<TaskPageModel> getTaskPage({
    int page = 1,
    int limit = 20,
    String? search,
    bool? isCompleted,
    String? priority,
    String? dueFrom,
    String? dueBefore,
    String sort = 'createdAtDesc',
  }) async => const TaskPageModel(
    items: [],
    page: 1,
    limit: 20,
    totalItems: 0,
    totalPages: 0,
    hasNextPage: false,
  );

  @override
  Future<TaskModel> createTask(TaskModel task) async => task;

  @override
  Future<TaskAttachment> uploadTaskAttachment({
    required String path,
    required String name,
  }) async => throw UnimplementedError();

  @override
  Future<void> updateTaskCompletion(String taskId, bool isCompleted) async {}

  @override
  Future<TaskModel> updateTask(TaskModel task) async => task;

  @override
  Future<void> deleteTask(String taskId) async {}

  @override
  Future<Map<String, dynamic>> getRecurringSeries() async => {};
  @override
  Future<Map<String, dynamic>> getRecurringSeriesById(String id) async => {};
  @override
  Future<Map<String, dynamic>> updateRecurringSeries(
    String id,
    TaskRepeatConfig repeat,
  ) async => {};
  @override
  Future<Map<String, dynamic>> stopRecurringSeries(String id) async => {};

  @override
  Future<TaskModel> getTaskById(String taskId) async =>
      throw UnimplementedError();

  @override
  Future<TaskOverviewModel> getTaskOverview({
    String? date,
    String timeZone = 'Asia/Ho_Chi_Minh',
  }) async => throw UnimplementedError();
}

final class _FakeCoordinator implements TaskReminderCoordinatorContract {
  NotificationSettingsSnapshot readResult = const NotificationSettingsSnapshot(
    enabled: false,
    permissionGranted: true,
  );
  NotificationSettingsSnapshot enableResult =
      const NotificationSettingsSnapshot(
        enabled: true,
        permissionGranted: true,
      );
  NotificationSettingsSnapshot? initialPermissionResult;
  bool failEnable = false;
  int enableCalls = 0;
  int initialPermissionCalls = 0;
  int disableCount = 0;
  int syncTasksCount = 0;
  int openSettingsCount = 0;
  final enabledWithTasks = <TaskModel>[];

  @override
  Future<NotificationSettingsSnapshot> readSettings() async => readResult;

  @override
  Future<NotificationSettingsSnapshot?>
  requestInitialPermissionIfNeeded() async {
    initialPermissionCalls++;
    return initialPermissionResult;
  }

  @override
  Future<NotificationSettingsSnapshot> enable() async {
    enableCalls++;
    if (failEnable) throw StateError('enable failed');
    return enableResult;
  }

  @override
  Future<NotificationSettingsSnapshot> enableForTasks(
    List<TaskModel> tasks,
  ) async {
    enableCalls++;
    enabledWithTasks.addAll(tasks);
    if (failEnable) throw StateError('schedule failed');
    return enableResult;
  }

  @override
  Future<void> disable() async => disableCount++;

  @override
  Future<void> syncTask(TaskModel task) async {}

  @override
  int captureRestoreRevision() => 0;

  @override
  Future<void> syncTasks(List<TaskModel> tasks, {int? restoreRevision}) async =>
      syncTasksCount++;

  @override
  Future<void> cancelTask(String taskId) async {}

  @override
  Future<void> openSettings() async => openSettingsCount++;
}
