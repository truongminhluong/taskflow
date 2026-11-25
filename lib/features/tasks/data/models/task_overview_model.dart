import 'task_model.dart';

final class TaskOverviewSummaryModel {
  const TaskOverviewSummaryModel({
    required this.total,
    required this.completed,
    required this.pending,
  });

  final int total;
  final int completed;
  final int pending;

  factory TaskOverviewSummaryModel.fromJson(Object? json) {
    if (json is! Map) {
      throw const FormatException('Task overview summary is invalid.');
    }
    final value = Map<String, dynamic>.from(json);
    final total = value['total'];
    final completed = value['completed'];
    final pending = value['pending'];
    if (total is! int ||
        completed is! int ||
        pending is! int ||
        total < 0 ||
        completed < 0 ||
        pending < 0) {
      throw const FormatException(
        'Task overview summary contains invalid values.',
      );
    }
    return TaskOverviewSummaryModel(
      total: total,
      completed: completed,
      pending: pending,
    );
  }
}

final class TaskOverviewModel {
  const TaskOverviewModel({
    required this.date,
    required this.summary,
    required this.todayTasks,
    required this.upcomingTasks,
  });

  final String date;
  final TaskOverviewSummaryModel summary;
  final List<TaskModel> todayTasks;
  final List<TaskModel> upcomingTasks;

  factory TaskOverviewModel.fromApiResponse(Object? response) {
    if (response is! Map || response['data'] is! Map) {
      throw const FormatException('Task overview response is invalid.');
    }
    final data = Map<String, dynamic>.from(response['data'] as Map);
    final date = data['date'];
    final todayTasks = _parseTasks(data['todayTasks'], 'todayTasks');
    final upcomingTasks = _parseTasks(data['upcomingTasks'], 'upcomingTasks');
    if (date is! String || date.isEmpty) {
      throw const FormatException('Task overview date is invalid.');
    }
    return TaskOverviewModel(
      date: date,
      summary: TaskOverviewSummaryModel.fromJson(data['summary']),
      todayTasks: todayTasks,
      upcomingTasks: upcomingTasks,
    );
  }
}

List<TaskModel> _parseTasks(Object? raw, String field) {
  if (raw is! List) {
    throw FormatException('Task overview field "$field" is invalid.');
  }
  return [
    for (var index = 0; index < raw.length; index++)
      _parseTask(raw[index], field, index),
  ];
}

TaskModel _parseTask(Object? raw, String field, int index) {
  if (raw is! Map) {
    throw FormatException('Task overview $field[$index] is not an object.');
  }
  try {
    return TaskModel.fromJson(Map<String, dynamic>.from(raw));
  } on FormatException catch (error) {
    throw FormatException(
      'Unable to parse overview task $field[$index]: ${error.message}',
    );
  }
}
