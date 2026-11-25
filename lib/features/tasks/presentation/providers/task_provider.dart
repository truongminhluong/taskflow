import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:task_flow_v2/core/notifications/task_reminder_coordinator.dart';
import 'package:task_flow_v2/features/tasks/data/repositories/task_repository_impl.dart';
import 'package:task_flow_v2/features/tasks/domain/repositories/task_repository.dart';
import 'package:task_flow_v2/features/tasks/presentation/state/task_state.dart';

import '../../domain/task_schedule_conflict.dart';
import 'notification_inbox_provider.dart';

import '../../data/models/task_model.dart';
import 'task_reminder_coordinator_provider.dart';

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  return TaskRepositoryImpl();
});

class TaskNotifier extends Notifier<TaskState> {
  Future<bool>? _loadInFlight;
  final Map<String, Future<void>> _taskMutationTails = {};
  int _taskListRevision = 0;

  @override
  TaskState build() {
    ref.watch(taskRepositoryProvider);
    return const TaskState();
  }

  Future<bool> loadTasks() {
    final inFlight = _loadInFlight;
    if (inFlight != null) return inFlight;

    final load = _performLoadTasks();
    _loadInFlight = load;
    return load.whenComplete(() => _loadInFlight = null);
  }

  /// Trả về danh sách task trùng giờ.
  /// Trả về null nếu không tải được danh sách để kiểm tra an toàn.
  Future<List<TaskModel>?> findScheduleConflicts(TaskModel candidate) async {
    if (candidate.dueDate == null) return const [];

    if (!state.hasLoaded) {
      final loaded = await loadTasks();

      if (!loaded || !state.hasLoaded) {
        return null;
      }
    }

    return findTaskStartConflicts(
      candidate,
      state.tasks,
      excludedTaskId: candidate.id.isEmpty ? null : candidate.id,
    );
  }

  Future<bool> loadOverview({String? date}) async {
    state = state.copyWith(isOverviewLoading: true, clearOverviewError: true);
    try {
      final overview = await ref
          .read(taskRepositoryProvider)
          .getTaskOverview(date: date, timeZone: 'Asia/Ho_Chi_Minh');

      state = state.copyWith(isOverviewLoading: false, overview: overview);
      return true;
    } catch (error, stackTrace) {
      debugPrint('Load task overview failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      state = state.copyWith(
        isOverviewLoading: false,
        overviewErrorMessage: 'Không thể tải tổng quan công việc.',
      );
      return false;
    }
  }

  Future<bool> _performLoadTasks() async {
    final revisionAtStart = _taskListRevision;
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final repository = ref.read(taskRepositoryProvider);
      final tasks = await repository.getTasks();

      if (revisionAtStart != _taskListRevision) {
        state = state.copyWith(isLoading: false, clearError: true);
        return true;
      }

      state = state.copyWith(
        tasks: tasks,
        isLoading: false,
        hasLoaded: true,
        clearError: true,
      );

      return true;
    } catch (error, stackTrace) {
      if (revisionAtStart != _taskListRevision) {
        state = state.copyWith(isLoading: false);
        return false;
      }

      debugPrint('Load tasks failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Không thể tải danh sách công việc.',
      );
      return false;
    }
  }

  Future<bool> createTask(TaskModel task) async {
    try {
      final repository = ref.read(taskRepositoryProvider);

      // Chỉ thêm vào danh sách sau khi backend tạo thành công.
      final createdTask = await repository.createTask(task);

      _taskListRevision++;
      state = state.copyWith(
        tasks: [...state.tasks, createdTask],
        clearError: true,
      );

      await _syncReminderSafely(createdTask);
      await _refreshOverviewSafely();

      return true;
    } catch (error, stackTrace) {
      debugPrint('Create task failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      state = state.copyWith(errorMessage: 'Không thể tạo công việc.');

      return false;
    }
  }

  Future<TaskAttachment> uploadTaskAttachment({
    required String path,
    required String name,
  }) {
    return ref
        .read(taskRepositoryProvider)
        .uploadTaskAttachment(path: path, name: name);
  }

  /// Thay đổi trạng thái hoàn thành của một công việc.
  Future<bool> toggleTask(String taskId, {TaskModel? knownTask}) =>
      _serializeTaskMutation(taskId, () async {
        final taskIndex = state.tasks.indexWhere((task) => task.id == taskId);
        final task = taskIndex == -1 ? knownTask : state.tasks[taskIndex];
        if (task == null) return false;
        final newIsCompleted = !task.isCompleted;

        try {
          final repository = ref.read(taskRepositoryProvider);
          await repository.updateTaskCompletion(taskId, newIsCompleted);

          _taskListRevision++;
          if (newIsCompleted) {
            // Completing a recurring task creates the next occurrence on the
            // server; reload instead of fabricating it locally.
            await loadTasks();
            await _syncReminderSafely(
              task.copyWith(isCompleted: newIsCompleted),
            );
            for (final nextTask in state.tasks) {
              if (nextTask.id != task.id &&
                  nextTask.recurrenceId == task.recurrenceId &&
                  !nextTask.isCompleted) {
                await _syncReminderSafely(nextTask);
                break;
              }
            }
            await _refreshOverviewSafely();
            return true;
          }

          final updatedTask = task.copyWith(isCompleted: newIsCompleted);
          final updatedTasks = state.tasks
              .map((item) => item.id == taskId ? updatedTask : item)
              .toList();

          state = state.copyWith(
            tasks: taskIndex == -1 ? state.tasks : updatedTasks,
            clearError: true,
          );
          await _syncReminderSafely(updatedTask);
          await _refreshOverviewSafely();
          return true;
        } catch (error, stackTrace) {
          debugPrint('Update task completion failed: $error');
          debugPrintStack(stackTrace: stackTrace);

          state = state.copyWith(
            errorMessage: 'Không thể cập nhật trạng thái công việc.',
          );
          return false;
        }
      });

  // Sửa thông tin một công việc.
  Future<bool> updateTask(
    TaskModel updatedTask, {
    bool allowMissingFromSharedState = false,
  }) => _serializeTaskMutation(updatedTask.id, () async {
    if (!_containsTask(updatedTask.id) && !allowMissingFromSharedState) {
      state = state.copyWith(errorMessage: 'Không tìm thấy công việc cần sửa.');
      return false;
    }

    try {
      final updateTotalTimer = Stopwatch()..start();
      final repository = ref.read(taskRepositoryProvider);
      final patchTimer = Stopwatch()..start();
      final savedTask = await repository.updateTask(updatedTask);
      debugPrint('updateTask PATCH: ${patchTimer.elapsedMilliseconds} ms');

      _taskListRevision++;
      if (_containsTask(updatedTask.id)) {
        final updatedTasks = state.tasks
            .map((task) => task.id == updatedTask.id ? savedTask : task)
            .toList();
        state = state.copyWith(tasks: updatedTasks, clearError: true);
      }

      // Updating a recurring series can move several future reminders.
      if (savedTask.recurrenceId != null) {
        await loadTasks();
        for (final task in state.tasks.where(
          (item) => item.recurrenceId == savedTask.recurrenceId,
        )) {
          unawaited(_syncReminderSafely(task));
        }
      } else {
        unawaited(_syncReminderSafely(savedTask));
      }

      final overviewTimer = Stopwatch()..start();
      await _refreshOverviewSafely();
      debugPrint(
        'updateTask overview refresh: ${overviewTimer.elapsedMilliseconds} ms',
      );
      debugPrint(
        'updateTask total before reminder sync: '
        '${updateTotalTimer.elapsedMilliseconds} ms',
      );

      return true;
    } catch (error, stackTrace) {
      debugPrint('Update task failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      state = state.copyWith(errorMessage: 'Không thể cập nhật công việc.');
      return false;
    }
  });

  // Xoá một công việc.
  Future<bool> deleteTask(
    String taskId, {
    bool allowMissingFromSharedState = false,
  }) => _serializeTaskMutation(taskId, () async {
    if (!_containsTask(taskId) && !allowMissingFromSharedState) {
      state = state.copyWith(errorMessage: 'Không tìm thấy công việc cần xoá.');
      return false;
    }

    try {
      final repository = ref.read(taskRepositoryProvider);
      await repository.deleteTask(taskId);

      _taskListRevision++;
      await _cancelReminderSafely(taskId);

      state = state.copyWith(
        tasks: state.tasks.where((task) => task.id != taskId).toList(),
        clearError: true,
      );
      await _refreshOverviewSafely();
      return true;
    } catch (error, stackTrace) {
      debugPrint('Delete task failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      state = state.copyWith(errorMessage: 'Không thể xoá công việc.');
      return false;
    }
  });

  Future<bool> stopRecurringSeries(String recurrenceId) async {
    try {
      await ref.read(taskRepositoryProvider).stopRecurringSeries(recurrenceId);
      await loadTasks();
      for (final task in state.tasks.where(
        (item) => item.recurrenceId == recurrenceId,
      )) {
        await _syncReminderSafely(task);
      }
      await _refreshOverviewSafely();
      return true;
    } catch (error, stackTrace) {
      debugPrint('Stop recurring series failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      state = state.copyWith(errorMessage: 'Không thể dừng chuỗi lặp.');
      return false;
    }
  }

  bool _containsTask(String taskId) =>
      state.tasks.any((task) => task.id == taskId);

  Future<T> _serializeTaskMutation<T>(
    String taskId,
    Future<T> Function() action,
  ) async {
    final previous = _taskMutationTails[taskId] ?? Future<void>.value();
    final release = Completer<void>();
    final tail = release.future;
    _taskMutationTails[taskId] = tail;

    await previous;
    try {
      return await action();
    } finally {
      release.complete();
      if (identical(_taskMutationTails[taskId], tail)) {
        _taskMutationTails.remove(taskId);
      }
    }
  }

  void setLoading(bool value) {
    state = state.copyWith(isLoading: value);
  }

  void setError(String message) {
    state = state.copyWith(errorMessage: message);
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  void clearNotificationError() {
    state = state.copyWith(clearNotificationError: true);
  }

  Future<void> _syncReminderSafely(TaskModel task) async {
    try {
      await ref.read(taskReminderCoordinatorProvider).syncTask(task);
      state = state.copyWith(clearNotificationError: true);
    } catch (error, stackTrace) {
      _recordReminderFailure(error, stackTrace);
    }
    unawaited(ref.read(notificationInboxProvider.notifier).refresh());
  }

  Future<void> _cancelReminderSafely(String taskId) async {
    try {
      await ref.read(taskReminderCoordinatorProvider).cancelTask(taskId);
      state = state.copyWith(clearNotificationError: true);
    } catch (error, stackTrace) {
      _recordReminderFailure(error, stackTrace);
    }
    unawaited(ref.read(notificationInboxProvider.notifier).refresh());
  }

  void _recordReminderFailure(Object error, StackTrace stackTrace) {
    debugPrint('Task reminder synchronization failed: $error');
    debugPrintStack(stackTrace: stackTrace);

    final message = error is NotificationPermissionException
        ? 'Công việc đã lưu nhưng quyền thông báo đã bị tắt. Hãy bật lại trong Cài đặt.'
        : 'Công việc đã lưu nhưng không thể đồng bộ lời nhắc. Hãy thử bật lại thông báo.';
    state = state.copyWith(notificationErrorMessage: message);
  }

  Future<void> _refreshOverviewSafely() async {
    if (state.overview == null) return;
    await loadOverview(date: state.overview!.date);
  }
}

final taskProvider = NotifierProvider<TaskNotifier, TaskState>(
  TaskNotifier.new,
);
