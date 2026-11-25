import '../../data/models/task_model.dart';
import '../../data/models/task_overview_model.dart';

class TaskState {
  const TaskState({
    this.isLoading = false,
    this.errorMessage,
    this.notificationErrorMessage,
    this.hasLoaded = false,
    this.tasks = const [],
    this.overview,
    this.isOverviewLoading = false,
    this.overviewErrorMessage,
  });

  final List<TaskModel> tasks;
  final bool isLoading;
  final String? errorMessage;
  final String? notificationErrorMessage;
  final bool hasLoaded;
  final TaskOverviewModel? overview;
  final bool isOverviewLoading;
  final String? overviewErrorMessage;

  TaskState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    String? notificationErrorMessage,
    bool clearNotificationError = false,
    bool? hasLoaded,
    List<TaskModel>? tasks,
    TaskOverviewModel? overview,
    bool clearOverview = false,
    bool? isOverviewLoading,
    String? overviewErrorMessage,
    bool clearOverviewError = false,
  }) {
    return TaskState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      notificationErrorMessage: clearNotificationError
          ? null
          : notificationErrorMessage ?? this.notificationErrorMessage,
      hasLoaded: hasLoaded ?? this.hasLoaded,
      tasks: tasks ?? this.tasks,
      overview: clearOverview ? null : overview ?? this.overview,
      isOverviewLoading: isOverviewLoading ?? this.isOverviewLoading,
      overviewErrorMessage: clearOverviewError
          ? null
          : overviewErrorMessage ?? this.overviewErrorMessage,
    );
  }
}
