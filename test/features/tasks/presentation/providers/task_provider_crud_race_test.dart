import 'dart:async';

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
  group('TaskNotifier CRUD race conditions', () {
    late _ControlledTaskRepository repository;
    late _FakeCoordinator coordinator;
    late ProviderContainer container;
    late TaskNotifier notifier;

    setUp(() async {
      repository = _ControlledTaskRepository([
        _task('a', 'Task A'),
        _task('b', 'Task B'),
      ]);
      coordinator = _FakeCoordinator();
      container = ProviderContainer(
        overrides: [
          taskRepositoryProvider.overrideWithValue(repository),
          taskReminderCoordinatorProvider.overrideWithValue(coordinator),
        ],
      );
      notifier = container.read(taskProvider.notifier);
      expect(await notifier.loadTasks(), isTrue);
    });

    tearDown(() => container.dispose());

    test(
      'serializes updates for one task and preserves the last edit',
      () async {
        final firstResponse = Completer<TaskModel>();
        final secondResponse = Completer<TaskModel>();
        var firstCompleted = false;
        var secondStartedBeforeFirstCompleted = false;

        repository.updateHandler = (task) {
          if (task.title == 'Task A edit 1') {
            return firstResponse.future.then((saved) {
              firstCompleted = true;
              return saved;
            });
          }

          secondStartedBeforeFirstCompleted = !firstCompleted;
          return secondResponse.future;
        };

        final firstUpdate = notifier.updateTask(_task('a', 'Task A edit 1'));
        await _waitUntil(() => repository.updateRequests.length == 1);

        final secondUpdate = notifier.updateTask(_task('a', 'Task A edit 2'));
        await Future<void>.delayed(Duration.zero);

        if (repository.updateRequests.length == 2) {
          // Simulate the old race: the later request responds first.
          secondResponse.complete(_task('a', 'Task A edit 2'));
          await Future<void>.delayed(Duration.zero);
          firstResponse.complete(_task('a', 'Task A edit 1'));
        } else {
          firstResponse.complete(_task('a', 'Task A edit 1'));
          await _waitUntil(() => repository.updateRequests.length == 2);
          secondResponse.complete(_task('a', 'Task A edit 2'));
        }

        expect(await firstUpdate, isTrue);
        expect(await secondUpdate, isTrue);
        expect(secondStartedBeforeFirstCompleted, isFalse);
        expect(_currentTask(container, 'a').title, 'Task A edit 2');
        expect(_currentTask(container, 'b').title, 'Task B');
      },
    );

    test(
      'delete waits for an in-flight update and does not restore the task',
      () async {
        final updateResponse = Completer<TaskModel>();
        final deleteResponse = Completer<void>();
        var deleteStarted = false;
        repository.updateHandler = (_) => updateResponse.future;
        repository.deleteHandler = (_) {
          deleteStarted = true;
          return deleteResponse.future;
        };

        final update = notifier.updateTask(_task('a', 'Updated A'));
        await _waitUntil(() => repository.updateRequests.isNotEmpty);
        final delete = notifier.deleteTask('a');
        await Future<void>.delayed(Duration.zero);

        final deleteStartedBeforeUpdateCompleted = deleteStarted;
        if (deleteStartedBeforeUpdateCompleted) {
          // Complete deletion first to reproduce the stale-index overwrite.
          deleteResponse.complete();
          expect(await delete, isTrue);
          updateResponse.complete(_task('a', 'Updated A'));
        } else {
          updateResponse.complete(_task('a', 'Updated A'));
          await _waitUntil(() => deleteStarted);
          deleteResponse.complete();
        }

        expect(await update, isTrue);
        expect(await delete, isTrue);
        expect(deleteStartedBeforeUpdateCompleted, isFalse);
        expect(container.read(taskProvider).tasks.map((task) => task.id), [
          'b',
        ]);
        expect(_currentTask(container, 'b').title, 'Task B');
      },
    );

    test('two queued toggles apply opposite states in tap order', () async {
      final firstResponse = Completer<void>();
      final secondResponse = Completer<void>();
      repository.toggleHandler = (taskId, isCompleted) {
        final requestIndex = repository.toggleRequests.length - 1;
        return requestIndex == 0 ? firstResponse.future : secondResponse.future;
      };

      final firstToggle = notifier.toggleTask('a');
      await _waitUntil(() => repository.toggleRequests.length == 1);
      final secondToggle = notifier.toggleTask('a');
      await Future<void>.delayed(Duration.zero);

      if (repository.toggleRequests.length == 2) {
        // The old implementation reads the same false value twice.
        secondResponse.complete();
        await Future<void>.delayed(Duration.zero);
        firstResponse.complete();
      } else {
        firstResponse.complete();
        await _waitUntil(() => repository.toggleRequests.length == 2);
        secondResponse.complete();
      }

      await Future.wait([firstToggle, secondToggle]);
      expect(repository.toggleRequests, [true, false]);
      expect(_currentTask(container, 'a').isCompleted, isFalse);
      expect(_currentTask(container, 'b').isCompleted, isFalse);
    });

    test('update for A and delete for B proceed independently', () async {
      final updateResponse = Completer<TaskModel>();
      final deleteResponse = Completer<void>();
      repository.updateHandler = (_) => updateResponse.future;
      repository.deleteHandler = (_) => deleteResponse.future;

      final update = notifier.updateTask(_task('a', 'Updated A'));
      final delete = notifier.deleteTask('b');
      await _waitUntil(
        () =>
            repository.updateRequests.isNotEmpty &&
            repository.deleteRequests.isNotEmpty,
      );

      deleteResponse.complete();
      await _waitUntil(() => coordinator.cancelledTaskIds.contains('b'));
      updateResponse.complete(_task('a', 'Updated A'));

      expect(await update, isTrue);
      expect(await delete, isTrue);
      expect(container.read(taskProvider).tasks.map((task) => task.id), ['a']);
      expect(_currentTask(container, 'a').title, 'Updated A');
    });

    test(
      'stale list response cannot overwrite a successful mutation',
      () async {
        final staleListResponse = Completer<List<TaskModel>>();
        repository.getTasksHandler = () => staleListResponse.future;

        final loading = notifier.loadTasks();
        final update = notifier.updateTask(_task('a', 'Updated A'));
        expect(await update, isTrue);

        staleListResponse.complete([
          _task('a', 'Task A'),
          _task('b', 'Task B'),
        ]);
        expect(await loading, isTrue);

        expect(_currentTask(container, 'a').title, 'Updated A');
        expect(_currentTask(container, 'b').title, 'Task B');
        expect(container.read(taskProvider).isLoading, isFalse);
      },
    );

    test(
      'stale list failure does not add an error after a mutation succeeds',
      () async {
        final staleListResponse = Completer<List<TaskModel>>();
        repository.getTasksHandler = () => staleListResponse.future;

        final loading = notifier.loadTasks();
        expect(await notifier.updateTask(_task('a', 'Updated A')), isTrue);

        staleListResponse.completeError(
          StateError('stale load failed'),
          StackTrace.current,
        );

        expect(await loading, isFalse);
        final state = container.read(taskProvider);
        expect(state.errorMessage, isNull);
        expect(state.isLoading, isFalse);
        expect(_currentTask(container, 'a').title, 'Updated A');
        expect(_currentTask(container, 'b').title, 'Task B');
      },
    );

    test('current list failure still reports the load error', () async {
      repository.getTasksHandler = () async =>
          throw StateError('current load failed');

      expect(await notifier.loadTasks(), isFalse);

      final state = container.read(taskProvider);
      expect(state.errorMessage, 'Không thể tải danh sách công việc.');
      expect(state.isLoading, isFalse);
      expect(_currentTask(container, 'a').title, 'Task A');
      expect(_currentTask(container, 'b').title, 'Task B');
    });

    test('queued update runs after the previous update fails', () async {
      final firstResponse = Completer<TaskModel>();
      final secondResponse = Completer<TaskModel>();
      repository.updateHandler = (task) => repository.updateRequests.length == 1
          ? firstResponse.future
          : secondResponse.future;

      final firstUpdate = notifier.updateTask(_task('a', 'Failed edit'));
      await _waitUntil(() => repository.updateRequests.length == 1);
      final secondUpdate = notifier.updateTask(_task('a', 'Successful edit'));

      firstResponse.completeError(
        StateError('first update failed'),
        StackTrace.current,
      );
      expect(await firstUpdate, isFalse);
      await _waitUntil(() => repository.updateRequests.length == 2);
      secondResponse.complete(_task('a', 'Successful edit'));

      expect(await secondUpdate, isTrue);
      expect(repository.updateRequests, hasLength(2));
      expect(_currentTask(container, 'a').title, 'Successful edit');
      expect(_currentTask(container, 'b').title, 'Task B');
    });

    test('queued update runs after the previous delete fails', () async {
      final deleteResponse = Completer<void>();
      final updateResponse = Completer<TaskModel>();
      repository.deleteHandler = (_) => deleteResponse.future;
      repository.updateHandler = (_) => updateResponse.future;

      final deletion = notifier.deleteTask('a');
      await _waitUntil(() => repository.deleteRequests.length == 1);
      final update = notifier.updateTask(_task('a', 'Updated after failure'));

      deleteResponse.completeError(
        StateError('delete failed'),
        StackTrace.current,
      );
      expect(await deletion, isFalse);
      await _waitUntil(() => repository.updateRequests.length == 1);
      updateResponse.complete(_task('a', 'Updated after failure'));

      expect(await update, isTrue);
      expect(repository.deleteRequests, ['a']);
      expect(repository.updateRequests, hasLength(1));
      expect(container.read(taskProvider).tasks.map((task) => task.id), [
        'a',
        'b',
      ]);
      expect(_currentTask(container, 'a').title, 'Updated after failure');
      expect(_currentTask(container, 'b').title, 'Task B');
    });

    test('queued toggle runs after the previous toggle fails', () async {
      final firstResponse = Completer<void>();
      final secondResponse = Completer<void>();
      repository.toggleHandler = (taskId, isCompleted) {
        final requestIndex = repository.toggleRequests.length - 1;
        return requestIndex == 0 ? firstResponse.future : secondResponse.future;
      };

      final firstToggle = notifier.toggleTask('a');
      await _waitUntil(() => repository.toggleRequests.length == 1);
      final secondToggle = notifier.toggleTask('a');

      firstResponse.completeError(
        StateError('first toggle failed'),
        StackTrace.current,
      );
      await firstToggle;
      await _waitUntil(() => repository.toggleRequests.length == 2);
      secondResponse.complete();

      await secondToggle;
      expect(repository.toggleRequests, [true, true]);
      expect(_currentTask(container, 'a').isCompleted, isTrue);
      expect(_currentTask(container, 'b').isCompleted, isFalse);
    });

    test('failed update leaves both tasks unchanged', () async {
      repository.updateHandler = (_) async => throw StateError('update failed');

      expect(await notifier.updateTask(_task('a', 'Wrong A')), isFalse);

      expect(_currentTask(container, 'a').title, 'Task A');
      expect(_currentTask(container, 'b').title, 'Task B');
    });

    test(
      'updates an independently fetched task without inserting it',
      () async {
        repository.updateHandler = (task) async => task;

        expect(
          await notifier.updateTask(
            _task('independent', 'Updated'),
            allowMissingFromSharedState: true,
          ),
          isTrue,
        );

        expect(repository.updateRequests.single.id, 'independent');
        expect(
          container
              .read(taskProvider)
              .tasks
              .any((task) => task.id == 'independent'),
          isFalse,
        );
      },
    );

    test(
      'toggles an independently fetched task without inserting it',
      () async {
        final independent = _task('independent', 'Independent');

        await notifier.toggleTask('independent', knownTask: independent);

        expect(repository.toggleRequests, [true]);
        expect(
          container
              .read(taskProvider)
              .tasks
              .any((task) => task.id == 'independent'),
          isFalse,
        );
      },
    );

    test(
      'deletes an independently fetched task without requiring shared state',
      () async {
        expect(
          await notifier.deleteTask(
            'independent',
            allowMissingFromSharedState: true,
          ),
          isTrue,
        );

        expect(repository.deleteRequests, ['independent']);
        expect(container.read(taskProvider).hasLoaded, isTrue);
      },
    );

    test('failed delete leaves task and reminder intact', () async {
      repository.deleteHandler = (_) async => throw StateError('delete failed');

      expect(await notifier.deleteTask('a'), isFalse);

      expect(container.read(taskProvider).tasks.map((task) => task.id), [
        'a',
        'b',
      ]);
      expect(coordinator.cancelledTaskIds, isEmpty);
      expect(_currentTask(container, 'a').title, 'Task A');
    });

    test('failed toggle keeps the prior completion state', () async {
      repository.toggleHandler = (_, _) async =>
          throw StateError('toggle failed');

      await notifier.toggleTask('a');

      expect(_currentTask(container, 'a').isCompleted, isFalse);
      expect(_currentTask(container, 'b').isCompleted, isFalse);
    });
  });
}

Future<void> _waitUntil(bool Function() condition) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    if (condition()) return;
    await Future<void>.delayed(Duration.zero);
  }
  expect(
    condition(),
    isTrue,
    reason: 'Timed out waiting for controlled API call.',
  );
}

TaskModel _task(String id, String title, {bool isCompleted = false}) =>
    TaskModel(
      id: id,
      title: title,
      description: '',
      dueDate: null,
      priority: TaskPriority.medium,
      category: 'Cá nhân',
      isCompleted: isCompleted,
    );

final class _ControlledTaskRepository implements TaskRepository {
  _ControlledTaskRepository(this.tasks);

  final List<TaskModel> tasks;
  final updateRequests = <TaskModel>[];
  final deleteRequests = <String>[];
  final toggleRequests = <bool>[];

  Future<List<TaskModel>> Function()? getTasksHandler;
  Future<TaskModel> Function(TaskModel task)? updateHandler;
  Future<void> Function(String taskId, bool isCompleted)? toggleHandler;
  Future<void> Function(String taskId)? deleteHandler;

  @override
  Future<List<TaskModel>> getTasks() async {
    final handler = getTasksHandler;
    return List.of(handler == null ? tasks : await handler());
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
  Future<void> updateTaskCompletion(String taskId, bool isCompleted) async {
    toggleRequests.add(isCompleted);
    await toggleHandler?.call(taskId, isCompleted);

    final index = tasks.indexWhere((task) => task.id == taskId);
    if (index >= 0) {
      tasks[index] = tasks[index].copyWith(isCompleted: isCompleted);
    }
  }

  @override
  Future<TaskModel> updateTask(TaskModel task) async {
    updateRequests.add(task);
    final savedTask = await updateHandler?.call(task) ?? task;

    final index = tasks.indexWhere((item) => item.id == task.id);
    if (index >= 0) tasks[index] = savedTask;
    return savedTask;
  }

  @override
  Future<void> deleteTask(String taskId) async {
    deleteRequests.add(taskId);
    await deleteHandler?.call(taskId);
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
  final cancelledTaskIds = <String>[];

  @override
  Future<NotificationSettingsSnapshot> readSettings() async =>
      const NotificationSettingsSnapshot(
        enabled: false,
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
  Future<void> syncTask(TaskModel task) async {}

  @override
  int captureRestoreRevision() => 0;

  @override
  Future<void> syncTasks(List<TaskModel> tasks, {int? restoreRevision}) async {}

  @override
  Future<void> cancelTask(String taskId) async {
    cancelledTaskIds.add(taskId);
  }

  @override
  Future<void> openSettings() async {}
}

TaskModel _currentTask(ProviderContainer container, String id) {
  return container.read(taskProvider).tasks.firstWhere((task) => task.id == id);
}
