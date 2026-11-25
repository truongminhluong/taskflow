import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task_flow_v2/core/notifications/task_reminder_coordinator.dart';
import 'package:task_flow_v2/features/tasks/data/models/task_model.dart';
import 'package:task_flow_v2/features/tasks/data/models/task_page_model.dart';
import 'package:task_flow_v2/features/tasks/data/models/task_overview_model.dart';
import 'package:task_flow_v2/features/tasks/domain/repositories/task_repository.dart';
import 'package:task_flow_v2/features/tasks/presentation/providers/task_provider.dart';
import 'package:task_flow_v2/features/tasks/presentation/providers/task_reminder_coordinator_provider.dart';

void main() {
  group('TaskNotifier reminder lifecycle', () {
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

    test('schedules a reminder only after task creation succeeds', () async {
      final succeeded = await container
          .read(taskProvider.notifier)
          .createTask(_task(''));

      expect(succeeded, isTrue);
      expect(repository.calls, ['create']);
      expect(coordinator.calls, ['sync:created']);
      expect(container.read(taskProvider).tasks.single.id, 'created');
    });

    test('does not schedule a task when create API fails', () async {
      repository.failCreate = true;

      final succeeded = await container
          .read(taskProvider.notifier)
          .createTask(_task(''));

      expect(succeeded, isFalse);
      expect(coordinator.calls, isEmpty);
      expect(container.read(taskProvider).tasks, isEmpty);
    });

    test('syncs saved task after update succeeds', () async {
      await container.read(taskProvider.notifier).createTask(_task(''));
      coordinator.calls.clear();
      final updated = _task('created').copyWith(title: 'Updated');

      final succeeded = await container
          .read(taskProvider.notifier)
          .updateTask(updated);

      expect(succeeded, isTrue);
      expect(coordinator.calls, ['sync:created']);
      expect(container.read(taskProvider).tasks.single.title, 'Updated');
    });

    test('reschedules when completion is toggled', () async {
      await container.read(taskProvider.notifier).createTask(_task(''));
      coordinator.calls.clear();

      await container.read(taskProvider.notifier).toggleTask('created');

      expect(coordinator.calls, ['sync:created']);
      expect(container.read(taskProvider).tasks.single.isCompleted, isTrue);
    });

    test('cancels the task reminder after delete API succeeds', () async {
      await container.read(taskProvider.notifier).createTask(_task(''));
      coordinator.calls.clear();

      final succeeded = await container
          .read(taskProvider.notifier)
          .deleteTask('created');

      expect(succeeded, isTrue);
      expect(coordinator.calls, ['cancel:created']);
      expect(container.read(taskProvider).tasks, isEmpty);
    });

    test('does not cancel a reminder when delete API fails', () async {
      await container.read(taskProvider.notifier).createTask(_task(''));
      coordinator.calls.clear();
      repository.failDelete = true;

      final succeeded = await container
          .read(taskProvider.notifier)
          .deleteTask('created');

      expect(succeeded, isFalse);
      expect(coordinator.calls, isEmpty);
      expect(container.read(taskProvider).tasks, hasLength(1));
    });

    test('keeps API success if reminder scheduling fails', () async {
      coordinator.failSync = true;

      final succeeded = await container
          .read(taskProvider.notifier)
          .createTask(_task(''));

      expect(succeeded, isTrue);
      expect(container.read(taskProvider).tasks, hasLength(1));
      expect(container.read(taskProvider).notificationErrorMessage, isNotNull);
    });
  });
}

TaskModel _task(String id) => TaskModel(
  id: id,
  title: 'Reminder test',
  description: '',
  dueDate: DateTime(2026, 11, 3, 12),
  priority: TaskPriority.medium,
  category: 'Cá nhân',
  isCompleted: false,
  reminderMinutesBefore: 15,
);

final class _FakeRepository implements TaskRepository {
  final calls = <String>[];
  bool failCreate = false;
  bool failDelete = false;
  final tasks = <TaskModel>[];

  @override
  Future<List<TaskModel>> getTasks() async => List.of(tasks);

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
  Future<TaskModel> createTask(TaskModel task) async {
    calls.add('create');
    if (failCreate) throw StateError('create failed');
    final created = task.copyWith(id: 'created');
    tasks.add(created);
    return created;
  }

  @override
  Future<TaskAttachment> uploadTaskAttachment({
    required String path,
    required String name,
  }) async => throw UnimplementedError();

  @override
  Future<void> updateTaskCompletion(String taskId, bool isCompleted) async {
    calls.add('toggle');
  }

  @override
  Future<TaskModel> updateTask(TaskModel task) async {
    calls.add('update');
    final index = tasks.indexWhere((item) => item.id == task.id);
    tasks[index] = task;
    return task;
  }

  @override
  Future<void> deleteTask(String taskId) async {
    calls.add('delete');
    if (failDelete) throw StateError('delete failed');
    tasks.removeWhere((task) => task.id == taskId);
  }

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
  final calls = <String>[];
  bool failSync = false;

  @override
  Future<NotificationSettingsSnapshot> readSettings() async =>
      const NotificationSettingsSnapshot(
        enabled: true,
        permissionGranted: true,
      );

  @override
  Future<NotificationSettingsSnapshot?>
  requestInitialPermissionIfNeeded() async => null;

  @override
  Future<NotificationSettingsSnapshot> enable() async =>
      const NotificationSettingsSnapshot(
        enabled: true,
        permissionGranted: true,
      );

  @override
  Future<NotificationSettingsSnapshot> enableForTasks(
    List<TaskModel> tasks,
  ) async => const NotificationSettingsSnapshot(
    enabled: true,
    permissionGranted: true,
  );

  @override
  Future<void> disable() async {}

  @override
  Future<void> syncTask(TaskModel task) async {
    calls.add('sync:${task.id}');
    if (failSync) throw StateError('schedule failed');
  }

  @override
  int captureRestoreRevision() => 0;

  @override
  Future<void> syncTasks(List<TaskModel> tasks, {int? restoreRevision}) async {
    calls.add('sync-all');
  }

  @override
  Future<void> cancelTask(String taskId) async {
    calls.add('cancel:$taskId');
  }

  @override
  Future<void> openSettings() async {}
}
