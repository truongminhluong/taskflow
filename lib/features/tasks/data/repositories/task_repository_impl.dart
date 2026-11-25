import 'package:task_flow_v2/features/tasks/data/datasources/task_remote_data_source.dart';
import 'package:task_flow_v2/features/tasks/data/models/task_model.dart';
import 'package:task_flow_v2/features/tasks/data/models/task_page_model.dart';
import 'package:task_flow_v2/features/tasks/data/models/task_overview_model.dart';
import 'package:task_flow_v2/features/tasks/domain/repositories/task_repository.dart';

final class TaskRepositoryImpl implements TaskRepository {
  TaskRepositoryImpl({TaskRemoteDataSource? remoteDataSource})
    : _remoteDataSource = remoteDataSource ?? TaskRemoteDataSource();

  final TaskRemoteDataSource _remoteDataSource;
  Future<List<TaskModel>>? _getTasksInFlight;

  @override
  Future<List<TaskModel>> getTasks() {
    final inFlight = _getTasksInFlight;
    if (inFlight != null) return inFlight;

    final request = _remoteDataSource.getTasks();
    _getTasksInFlight = request;
    return request.whenComplete(() {
      if (identical(_getTasksInFlight, request)) {
        _getTasksInFlight = null;
      }
    });
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
  }) {
    return _remoteDataSource.getTaskPage(
      page: page,
      limit: limit,
      search: search,
      isCompleted: isCompleted,
      priority: priority,
      dueFrom: dueFrom,
      dueBefore: dueBefore,
      sort: sort,
    );
  }

  @override
  Future<TaskOverviewModel> getTaskOverview({
    String? date,
    String timeZone = 'Asia/Ho_Chi_Minh',
  }) {
    return _remoteDataSource.getTaskOverview(date: date, timeZone: timeZone);
  }

  @override
  Future<TaskModel> getTaskById(String taskId) {
    return _remoteDataSource.getTaskById(taskId);
  }

  @override
  Future<TaskModel> createTask(TaskModel task) {
    return _remoteDataSource.createTask(task);
  }

  @override
  Future<TaskAttachment> uploadTaskAttachment({
    required String path,
    required String name,
  }) {
    return _remoteDataSource.uploadTaskAttachment(path: path, name: name);
  }

  @override
  Future<void> updateTaskCompletion(String taskId, bool isCompleted) {
    return _remoteDataSource.updateTaskCompletion(taskId, isCompleted);
  }

  @override
  Future<TaskModel> updateTask(TaskModel task) {
    return _remoteDataSource.updateTask(task);
  }

  @override
  Future<void> deleteTask(String taskId) {
    return _remoteDataSource.deleteTask(taskId);
  }

  @override
  Future<Map<String, dynamic>> getRecurringSeries() {
    return _remoteDataSource.getRecurringSeries();
  }

  @override
  Future<Map<String, dynamic>> getRecurringSeriesById(String recurrenceId) {
    return _remoteDataSource.getRecurringSeriesById(recurrenceId);
  }

  @override
  Future<Map<String, dynamic>> updateRecurringSeries(
    String recurrenceId,
    TaskRepeatConfig repeat,
  ) {
    return _remoteDataSource.updateRecurringSeries(recurrenceId, repeat);
  }

  @override
  Future<Map<String, dynamic>> stopRecurringSeries(String recurrenceId) {
    return _remoteDataSource.stopRecurringSeries(recurrenceId);
  }
}
