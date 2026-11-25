import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:task_flow_v2/features/tasks/presentation/providers/task_provider.dart';
import 'package:task_flow_v2/features/tasks/presentation/state/task_details_state.dart';

import '../../data/models/task_model.dart';

final taskDetailsProvider =
NotifierProvider<TaskDetailsNotifier, TaskDetailsState>(
  TaskDetailsNotifier.new,
);

final class TaskDetailsNotifier extends Notifier<TaskDetailsState> {
  String? _loadTaskId;
  Future<void>? _loadInFlight;

  @override
  TaskDetailsState build() => const TaskDetailsState();

  void setTask(TaskModel task) {
    _loadTaskId = task.id;
    state = state.copyWith(
      task: task,
      isLoading: false,
      isNotFound: false,
      clearError: true,
    );
  }

  Future<void> loadTask(String taskId, {bool forceRefresh = false}) async {
    if (!forceRefresh && taskId == _loadTaskId && state.task != null) {
      return Future<void>.value();
    }

    final inFlight = _loadInFlight;

    if (!forceRefresh && inFlight != null) {
      return inFlight;
    }

    final future = _fetch(taskId);
    _loadInFlight = future;

    return future.whenComplete(() {
      if (identical(_loadInFlight, future)) {
        _loadInFlight = null;
      }
    });
  }

  Future<void> _fetch(String taskId) async {
    state = state.copyWith(
        isLoading: true,
        isNotFound: false,
        clearError: true,
        clearTask: true,
    );

    try {
      final task = await ref
          .read(taskRepositoryProvider)
          .getTaskById(taskId);

      _loadTaskId = taskId;

      state = state.copyWith(
        task: task,
        isLoading: false,
        isNotFound: false,
        clearError: true
      );

    } on DioException catch (error) {
      final isNotFound = error.response?.statusCode == 404;
      _loadTaskId = null;

      state = state.copyWith(
        isLoading: false,
        isNotFound: isNotFound,
        errorMessage: isNotFound
            ? null
            : 'Không thể tải công việc. Vui lòng thử lại.',
        clearError: isNotFound
      );

    } catch (_) {
      _loadTaskId = null;

      state = state.copyWith(
        isLoading: false,
        isNotFound: false,
        errorMessage: 'Không thể tải công việc. Vui lòng thử lại.'
      );
    }
  }

}
