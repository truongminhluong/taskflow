import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task_flow_v2/core/notifications/task_notification_service.dart';
import 'package:task_flow_v2/core/notifications/task_reminder_coordinator.dart';
import 'package:task_flow_v2/core/notifications/task_reminder_policy.dart';
import 'package:task_flow_v2/features/tasks/data/models/task_model.dart';

void main() {
  final now = DateTime(2026, 11, 2, 10);

  group('TaskReminderPolicy', () {
    test('notification IDs are stable and positive for MongoDB task IDs', () {
      const taskId = '6723f1c0a2b4c5d6e7f80123';

      final first = TaskNotificationService.notificationIdFor(taskId);
      final second = TaskNotificationService.notificationIdFor(taskId);

      expect(first, second);
      expect(first, inInclusiveRange(1, 0x7fffffff));
      expect(
        TaskNotificationService.notificationIdFor('6723f1c0a2b4c5d6e7f80124'),
        isNot(first),
      );
    });

    test('calculates every supported reminder offset', () {
      for (final minutes in [0, 5, 10, 15, 30, 60, 1440]) {
        final dueDate = DateTime(2026, 11, 4, 10);
        final scheduled = TaskReminderPolicy.scheduledAt(
          _task('task-$minutes', dueDate: dueDate, reminder: minutes),
          now: now,
        );

        expect(scheduled, dueDate.subtract(Duration(minutes: minutes)));
      }
    });

    test('handles reminder calculation across a day and month boundary', () {
      final dueDate = DateTime(2026, 12, 1, 0, 5);
      final scheduled = TaskReminderPolicy.scheduledAt(
        _task('rollover', dueDate: dueDate, reminder: 15),
        now: DateTime(2026, 11, 30, 23, 40),
      );

      expect(scheduled, DateTime(2026, 11, 30, 23, 50));
    });

    test('does not schedule without a due date', () {
      expect(
        TaskReminderPolicy.scheduledAt(_task('no-date', reminder: 0), now: now),
        isNull,
      );
    });

    test('does not schedule when reminders are disabled', () {
      expect(
        TaskReminderPolicy.scheduledAt(
          _task('no-reminder', dueDate: now.add(const Duration(hours: 1))),
          now: now,
        ),
        isNull,
      );
    });

    test('does not schedule completed tasks', () {
      expect(
        TaskReminderPolicy.scheduledAt(
          _task(
            'completed',
            dueDate: now.add(const Duration(hours: 1)),
            reminder: 0,
            completed: true,
          ),
          now: now,
        ),
        isNull,
      );
    });

    test('does not send late reminders when the reminder time has passed', () {
      expect(
        TaskReminderPolicy.scheduledAt(
          _task(
            'past',
            dueDate: now.add(const Duration(minutes: 5)),
            reminder: 15,
          ),
          now: now,
        ),
        isNull,
      );
    });

    test('rejects unsupported reminder offsets', () {
      expect(
        () => TaskReminderPolicy.scheduledAt(
          _task(
            'invalid',
            dueDate: now.add(const Duration(hours: 2)),
            reminder: 20,
          ),
          now: now,
        ),
        throwsFormatException,
      );
    });
  });

  group('TaskReminderCoordinator', () {
    late _FakeDriver driver;
    late _MemorySettingsStore store;
    late TaskReminderCoordinator coordinator;

    setUp(() {
      driver = _FakeDriver(now: now);
      store = _MemorySettingsStore();
      coordinator = TaskReminderCoordinator(
        driver: driver,
        settingsStore: store,
      );
    });

    tearDown(() => debugDefaultTargetPlatformOverride = null);

    test('initial iOS permission request is made only once', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      driver.permissionGranted = false;

      final first = await coordinator.requestInitialPermissionIfNeeded();
      final second = await coordinator.requestInitialPermissionIfNeeded();

      expect(first?.enabled, isTrue);
      expect(first?.permissionGranted, isTrue);
      expect(second, isNull);
      expect(driver.requestPermissionCount, 1);
      expect(await store.readEnabled(), isTrue);
      expect(await store.readInitialPermissionRequested(), isTrue);
    });

    test(
      'initial iOS permission denial stays disabled and is not repeated',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        driver.permissionGranted = false;
        driver.requestResult = false;

        final first = await coordinator.requestInitialPermissionIfNeeded();
        final second = await coordinator.requestInitialPermissionIfNeeded();

        expect(first?.enabled, isFalse);
        expect(first?.permissionGranted, isFalse);
        expect(second, isNull);
        expect(driver.requestPermissionCount, 1);
        expect(await store.readEnabled(), isFalse);
        expect(await store.readInitialPermissionRequested(), isTrue);
        expect(driver.pending, isEmpty);
      },
    );

    test(
      'permission revocation cancels schedules without clearing app choice',
      () async {
        store.enabled = true;
        driver.permissionGranted = false;

        final result = await coordinator.readSettings();

        expect(result.enabled, isTrue);
        expect(result.permissionGranted, isFalse);
        expect(result.permissionRevoked, isTrue);
        expect(await store.readEnabled(), isTrue);
        expect(driver.cancelAllCount, 1);
      },
    );

    test('enables and schedules eligible tasks only', () async {
      final tasks = [
        _task(
          'valid',
          dueDate: now.add(const Duration(hours: 1)),
          reminder: 15,
        ),
        _task('no-date', reminder: 0),
        _task('no-reminder', dueDate: now.add(const Duration(hours: 1))),
        _task(
          'completed',
          dueDate: now.add(const Duration(hours: 1)),
          reminder: 0,
          completed: true,
        ),
        _task(
          'past',
          dueDate: now.add(const Duration(minutes: 5)),
          reminder: 15,
        ),
      ];

      final result = await coordinator.enableForTasks(tasks);

      expect(result.enabled, isTrue);
      expect(result.permissionGranted, isTrue);
      expect(await store.readEnabled(), isTrue);
      expect(driver.pending.values.map((task) => task.id), ['valid']);
    });

    test('successful empty restoration clears stale reminders', () async {
      store.enabled = true;
      final staleTask = _task(
        'stale-before-empty-restore',
        dueDate: now.add(const Duration(hours: 2)),
        reminder: 0,
      );
      await coordinator.syncTasks([staleTask]);
      expect(driver.pending, hasLength(1));

      await coordinator.syncTasks(const []);

      expect(driver.cancelAllCount, 2);
      expect(driver.pending, isEmpty);
    });

    test(
      'permission denial remembers app choice but creates no schedules',
      () async {
        driver.permissionGranted = false;
        driver.requestResult = false;

        final result = await coordinator.enableForTasks([
          _task(
            'task',
            dueDate: now.add(const Duration(hours: 1)),
            reminder: 0,
          ),
        ]);

        expect(result.enabled, isTrue);
        expect(result.permissionGranted, isFalse);
        expect(await store.readEnabled(), isTrue);
        expect(driver.pending, isEmpty);
        expect(driver.cancelAllCount, 1);
      },
    );

    test(
      'scheduling failure rolls back partial schedules and preference',
      () async {
        driver.failOnTaskId = 'second';

        await expectLater(
          coordinator.enableForTasks([
            _task(
              'first',
              dueDate: now.add(const Duration(hours: 1)),
              reminder: 0,
            ),
            _task(
              'second',
              dueDate: now.add(const Duration(hours: 2)),
              reminder: 0,
            ),
          ]),
          throwsStateError,
        );

        expect(await store.readEnabled(), isFalse);
        expect(driver.pending, isEmpty);
        expect(driver.cancelAllCount, 1);
      },
    );

    test(
      'disabling cancels all pending reminders before saving disabled state',
      () async {
        await coordinator.enableForTasks([
          _task('one', dueDate: now.add(const Duration(hours: 1)), reminder: 0),
        ]);

        await coordinator.disable();

        expect(driver.pending, isEmpty);
        expect(await store.readEnabled(), isFalse);
      },
    );

    test('sync replaces a task schedule without duplicating it', () async {
      await coordinator.enableForTasks([
        _task('one', dueDate: now.add(const Duration(hours: 1)), reminder: 0),
      ]);

      await coordinator.syncTask(
        _task('one', dueDate: now.add(const Duration(hours: 2)), reminder: 15),
      );

      expect(driver.pending.length, 1);
      expect(
        driver.pending.values.single.dueDate,
        now.add(const Duration(hours: 2)),
      );
    });

    test('concurrent schedules for different tasks remain distinct', () async {
      store.enabled = true;
      const firstTaskId = '5dafcd276759210fbc5a3895';
      const secondTaskId = 'df83230e6f50d0044a7d3b9b';
      expect(
        TaskNotificationService.notificationIdFor(firstTaskId),
        TaskNotificationService.notificationIdFor(secondTaskId),
      );
      final firstTask = _task(
        firstTaskId,
        dueDate: now.add(const Duration(hours: 1)),
        reminder: 0,
      );
      final secondTask = _task(
        secondTaskId,
        dueDate: now.add(const Duration(hours: 2)),
        reminder: 15,
      );
      final firstSchedule = Completer<void>();
      driver.scheduleHandler = (task) =>
          task.id == firstTask.id ? firstSchedule.future : Future<void>.value();

      final first = coordinator.syncTask(firstTask);
      await _waitUntil(() => driver.scheduleStarted.contains(firstTask.id));
      final second = coordinator.syncTask(secondTask);
      await Future<void>.delayed(Duration.zero);
      expect(driver.scheduleStarted, [firstTask.id]);

      firstSchedule.complete();
      await first;
      await second;

      expect(driver.pending.length, 2);
      expect(driver.pending.values.map((task) => task.id).toSet(), {
        firstTask.id,
        secondTask.id,
      });
      expect(driver.pending.keys.toSet(), hasLength(2));
    });

    test(
      'disable waits for an in-flight schedule before cancelling all',
      () async {
        store.enabled = true;
        final task = _task(
          'schedule-disable',
          dueDate: now.add(const Duration(hours: 2)),
          reminder: 0,
        );
        final scheduleGate = Completer<void>();
        driver.scheduleHandler = (_) => scheduleGate.future;

        final scheduling = coordinator.syncTask(task);
        await _waitUntil(() => driver.scheduleStarted.contains(task.id));
        final disabling = coordinator.disable();
        await Future<void>.delayed(Duration.zero);
        expect(driver.cancelAllCount, 0);
        expect(await store.readEnabled(), isTrue);

        scheduleGate.complete();
        await scheduling;
        await disabling;

        expect(driver.cancelAllCount, 1);
        expect(driver.pending, isEmpty);
        expect(await store.readEnabled(), isFalse);
      },
    );

    test(
      'tasks with the same reminder time keep separate IDs and payloads',
      () async {
        store.enabled = true;
        final sameTime = now.add(const Duration(hours: 3));

        await coordinator.syncTasks([
          _task('same-time-a', dueDate: sameTime, reminder: 15),
          _task('same-time-b', dueDate: sameTime, reminder: 15),
        ]);

        expect(driver.pending, hasLength(2));
        expect(driver.pending.keys.toSet(), hasLength(2));
        expect(driver.pending.values.map((task) => task.id).toSet(), {
          'same-time-a',
          'same-time-b',
        });
        expect(driver.pending.values.map((task) => task.dueDate).toSet(), {
          sameTime,
        });
      },
    );

    test(
      'repeated schedules for one task leave one pending reminder',
      () async {
        store.enabled = true;
        final task = _task(
          'repeat-schedule',
          dueDate: now.add(const Duration(hours: 2)),
          reminder: 15,
        );

        await coordinator.syncTask(task);
        await coordinator.syncTask(
          _task(
            task.id,
            dueDate: now.add(const Duration(hours: 4)),
            reminder: 60,
          ),
        );

        expect(driver.pending, hasLength(1));
        expect(driver.pending.values.single.id, task.id);
        expect(
          driver.pending.values.single.dueDate,
          now.add(const Duration(hours: 4)),
        );
      },
    );

    test(
      'cancel queued during schedule leaves no reminder for that task',
      () async {
        store.enabled = true;
        final task = _task(
          'schedule-cancel',
          dueDate: now.add(const Duration(hours: 2)),
          reminder: 0,
        );
        final scheduleGate = Completer<void>();
        driver.scheduleHandler = (_) => scheduleGate.future;

        final scheduling = coordinator.syncTask(task);
        await _waitUntil(() => driver.scheduleStarted.contains(task.id));
        final cancelling = coordinator.cancelTask(task.id);
        await Future<void>.delayed(Duration.zero);
        expect(driver.cancelStarted, isEmpty);

        scheduleGate.complete();
        await scheduling;
        await cancelling;

        expect(
          driver.pending.values.where((item) => item.id == task.id),
          isEmpty,
        );
        expect(driver.cancelStarted, [task.id]);
      },
    );

    test(
      'new reminder time wins when update arrives during old schedule',
      () async {
        store.enabled = true;
        final oldTask = _task(
          'updated-during-schedule',
          dueDate: now.add(const Duration(hours: 2)),
          reminder: 15,
        );
        final newTask = _task(
          oldTask.id,
          dueDate: now.add(const Duration(hours: 5)),
          reminder: 60,
        );
        final oldSchedule = Completer<void>();
        driver.scheduleHandler = (task) => task.dueDate == oldTask.dueDate
            ? oldSchedule.future
            : Future<void>.value();

        final oldOperation = coordinator.syncTask(oldTask);
        await _waitUntil(() => driver.scheduleStarted.length == 1);
        final newOperation = coordinator.syncTask(newTask);
        await Future<void>.delayed(Duration.zero);
        expect(driver.scheduleStarted, [oldTask.id]);

        oldSchedule.complete();
        await oldOperation;
        await newOperation;

        expect(driver.pending, hasLength(1));
        expect(driver.pending.values.single.dueDate, newTask.dueDate);
      },
    );

    test('syncTasks does not overwrite a newer task update', () async {
      store.enabled = true;
      final oldTask = _task(
        'sync-snapshot-race',
        dueDate: now.add(const Duration(hours: 2)),
        reminder: 0,
      );
      final newTask = _task(
        oldTask.id,
        dueDate: now.add(const Duration(hours: 6)),
        reminder: 15,
      );
      final oldSchedule = Completer<void>();
      driver.scheduleHandler = (task) => task.dueDate == oldTask.dueDate
          ? oldSchedule.future
          : Future<void>.value();

      final restoring = coordinator.syncTasks([oldTask]);
      await _waitUntil(() => driver.scheduleStarted.length == 1);
      final updating = coordinator.syncTask(newTask);
      await Future<void>.delayed(Duration.zero);
      expect(driver.scheduleStarted, [oldTask.id]);

      oldSchedule.complete();
      await restoring;
      await updating;

      expect(driver.pending, hasLength(1));
      expect(driver.pending.values.single.dueDate, newTask.dueDate);
    });

    test(
      'stale restore does not recreate a task deleted during fetching',
      () async {
        store.enabled = true;
        final task = _task(
          'delete-during-restore',
          dueDate: now.add(const Duration(hours: 2)),
          reminder: 0,
        );
        await coordinator.syncTasks([task]);

        final restoreRevision = coordinator.captureRestoreRevision();
        await coordinator.cancelTask(task.id);
        await coordinator.syncTasks([task], restoreRevision: restoreRevision);

        expect(driver.pending, isEmpty);
      },
    );

    test(
      'stale restore does not overwrite an update during fetching',
      () async {
        store.enabled = true;
        final oldTask = _task(
          'update-during-restore',
          dueDate: now.add(const Duration(hours: 2)),
          reminder: 0,
        );
        final newTask = _task(
          oldTask.id,
          dueDate: now.add(const Duration(hours: 6)),
          reminder: 15,
        );
        await coordinator.syncTasks([oldTask]);

        final restoreRevision = coordinator.captureRestoreRevision();
        await coordinator.syncTask(newTask);
        await coordinator.syncTasks([
          oldTask,
        ], restoreRevision: restoreRevision);

        expect(driver.pending.values.single.dueDate, newTask.dueDate);
        expect(driver.pending.values.single.reminderMinutesBefore, 15);
      },
    );

    test('known hash collision receives separate notification IDs', () async {
      store.enabled = true;
      const firstId = '5dafcd276759210fbc5a3895';
      const secondId = 'df83230e6f50d0044a7d3b9b';
      expect(
        TaskNotificationService.notificationIdFor(firstId),
        TaskNotificationService.notificationIdFor(secondId),
      );

      final reminderTime = now.add(const Duration(hours: 2));
      await coordinator.syncTasks([
        _task(firstId, dueDate: reminderTime, reminder: 0),
        _task(secondId, dueDate: reminderTime, reminder: 0),
      ]);

      expect(driver.pending, hasLength(2));
      expect(driver.pending.keys.toSet(), hasLength(2));
      expect(driver.pending.values.map((task) => task.id).toSet(), {
        firstId,
        secondId,
      });
      expect(
        TaskNotificationService.selectNotificationId(
          secondId,
          occupiedIds: {TaskNotificationService.notificationIdFor(firstId)},
        ),
        isNot(TaskNotificationService.notificationIdFor(firstId)),
      );
    });

    test(
      'cancelling one task leaves the other task and payload intact',
      () async {
        store.enabled = true;
        await coordinator.syncTasks([
          _task(
            'cancel-only-a',
            dueDate: now.add(const Duration(hours: 2)),
            reminder: 0,
          ),
          _task(
            'cancel-only-b',
            dueDate: now.add(const Duration(hours: 2)),
            reminder: 0,
          ),
        ]);

        await coordinator.cancelTask('cancel-only-a');

        expect(driver.pending, hasLength(1));
        expect(driver.pending.values.single.id, 'cancel-only-b');
        expect(
          driver.pending.keys.single,
          isNot(TaskNotificationService.notificationIdFor('cancel-only-a')),
        );
      },
    );

    test('queue continues after a schedule error', () async {
      store.enabled = true;
      final failedTask = _task(
        'schedule-error',
        dueDate: now.add(const Duration(hours: 2)),
        reminder: 0,
      );
      final followingTask = _task(
        'schedule-after-error',
        dueDate: now.add(const Duration(hours: 3)),
        reminder: 15,
      );
      final failedSchedule = Completer<void>();
      driver.scheduleHandler = (task) => task.id == failedTask.id
          ? failedSchedule.future
          : Future<void>.value();

      final failedOperation = coordinator.syncTask(failedTask);
      await _waitUntil(() => driver.scheduleStarted.contains(failedTask.id));
      final nextOperation = coordinator.syncTask(followingTask);

      failedSchedule.completeError(
        StateError('schedule failed'),
        StackTrace.current,
      );
      await expectLater(failedOperation, throwsStateError);
      await nextOperation;

      expect(driver.scheduleStarted, [failedTask.id, followingTask.id]);
      expect(driver.pending, hasLength(1));
      expect(driver.pending.values.single.id, followingTask.id);
    });

    test(
      'syncing a task without an eligible reminder cancels only its schedule',
      () async {
        await coordinator.enableForTasks([
          _task('one', dueDate: now.add(const Duration(hours: 1)), reminder: 0),
          _task('two', dueDate: now.add(const Duration(hours: 2)), reminder: 0),
        ]);

        await coordinator.syncTask(_task('one'));

        expect(driver.pending.values.map((task) => task.id), ['two']);
      },
    );

    test(
      'restores pending reminders after task reload without duplicates',
      () async {
        final task = _task(
          'one',
          dueDate: now.add(const Duration(hours: 1)),
          reminder: 0,
        );
        await coordinator.enableForTasks([task]);

        await coordinator.syncTasks([task]);
        await coordinator.syncTasks([task]);

        expect(driver.pending.length, 1);
        expect(driver.scheduleCount, 3);
      },
    );

    test('permission revoked in system settings preserves app choice and cancels schedules', () async {
      await coordinator.enableForTasks([
        _task('one', dueDate: now.add(const Duration(hours: 1)), reminder: 0),
      ]);
      driver.permissionGranted = false;

      final result = await coordinator.readSettings();

      expect(result.enabled, isTrue);
      expect(result.permissionGranted, isFalse);
      expect(result.permissionRevoked, isTrue);
      expect(await store.readEnabled(), isTrue);
      expect(driver.pending, isEmpty);
    });

    test(
      'a task API lifecycle sync does not schedule when app setting is off',
      () async {
        await coordinator.syncTask(
          _task('one', dueDate: now.add(const Duration(hours: 1)), reminder: 0),
        );

        expect(driver.pending, isEmpty);
        expect(await store.readEnabled(), isFalse);
      },
    );
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
    reason: 'Timed out waiting for notification operation.',
  );
}

TaskModel _task(
  String id, {
  DateTime? dueDate,
  int? reminder,
  bool completed = false,
}) {
  return TaskModel(
    id: id,
    title: 'Task $id',
    description: '',
    dueDate: dueDate,
    priority: TaskPriority.medium,
    category: 'Cá nhân',
    isCompleted: completed,
    reminderMinutesBefore: reminder,
  );
}

final class _MemorySettingsStore implements NotificationSettingsStore {
  bool enabled = false;
  bool initialPermissionRequested = false;

  @override
  Future<bool> readEnabled() async => enabled;

  @override
  Future<void> writeEnabled(bool value) async => enabled = value;

  @override
  Future<bool> readInitialPermissionRequested() async =>
      initialPermissionRequested;

  @override
  Future<void> writeInitialPermissionRequested(bool requested) async =>
      initialPermissionRequested = requested;
}

final class _FakeDriver implements TaskNotificationDriver {
  _FakeDriver({required this.now});

  final DateTime now;
  final Map<int, TaskModel> pending = {};
  bool permissionGranted = true;
  bool requestResult = true;
  String? failOnTaskId;
  int scheduleCount = 0;
  int requestPermissionCount = 0;
  int cancelAllCount = 0;
  final scheduleStarted = <String>[];
  final cancelStarted = <String>[];
  Future<void> Function(TaskModel task)? scheduleHandler;

  @override
  Future<void> initialize({TaskNotificationTapHandler? onTaskTap}) async {}

  @override
  Future<bool> hasPermission() async => permissionGranted;

  @override
  Future<bool> requestPermission() async {
    requestPermissionCount++;
    permissionGranted = requestResult;
    return requestResult;
  }

  @override
  Future<void> openNotificationSettings() async {}

  @override
  Future<void> scheduleTaskReminder(TaskModel task) async {
    scheduleCount++;
    scheduleStarted.add(task.id);
    await scheduleHandler?.call(task);
    if (task.id == failOnTaskId) throw StateError('mock schedule failure');

    final existingTaskIds = pending.entries
        .where((entry) => entry.value.id == task.id)
        .map((entry) => entry.key)
        .toSet();
    final occupiedIds = pending.entries
        .where((entry) => entry.value.id != task.id)
        .map((entry) => entry.key)
        .toSet();
    final id = TaskNotificationService.selectNotificationId(
      task.id,
      occupiedIds: occupiedIds,
      existingTaskIds: existingTaskIds,
    );
    pending.removeWhere((_, existingTask) => existingTask.id == task.id);

    if (TaskReminderPolicy.scheduledAt(task, now: now) == null) {
      return;
    }
    pending[id] = task;
  }

  @override
  Future<void> cancelTaskReminder(String taskId) async {
    cancelStarted.add(taskId);
    final ids = pending.entries
        .where((entry) => entry.value.id == taskId)
        .map((entry) => entry.key)
        .toSet();
    pending.removeWhere((id, _) => ids.contains(id));
  }

  @override
  Future<void> cancelAllReminders() async {
    cancelAllCount++;
    pending.clear();
  }
}
