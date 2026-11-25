import '../../data/models/task_model.dart';

final class TaskDetailsState {
  final TaskModel? task;
  final bool isLoading;
  final bool isNotFound;
  final String? errorMessage;

  const TaskDetailsState({
    this.task,
    this.isLoading = false,
    this.isNotFound = false,
    this.errorMessage,
  });

  TaskDetailsState copyWith({
    TaskModel? task,
    bool? isLoading,
    bool? isNotFound,
    String? errorMessage,
    bool clearError = false,
    bool clearTask = false,
  }) {
    return TaskDetailsState(
      task: clearTask ? null : task ?? this.task,
      isLoading: isLoading ?? this.isLoading,
      isNotFound: isNotFound ?? this.isNotFound,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}
