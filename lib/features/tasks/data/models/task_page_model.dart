import 'task_model.dart';

final class TaskPageModel {
  const TaskPageModel({
    required this.items,
    required this.page,
    required this.limit,
    required this.totalItems,
    required this.totalPages,
    required this.hasNextPage,
  });

  final List<TaskModel> items;
  final int page;
  final int limit;
  final int totalItems;
  final int totalPages;
  final bool hasNextPage;

  factory TaskPageModel.fromApiResponse(Object? response) {
    if (response is! Map || response['data'] is! Map) {
      throw const FormatException('Task page response is invalid.');
    }

    final data = Map<String, dynamic>.from(response['data'] as Map);
    final rawItems = data['items'];
    final rawPagination = data['pagination'];

    if (rawItems is! List || rawPagination is! Map) {
      throw const FormatException('Task page data is incomplete.');
    }

    final pagination = Map<String, dynamic>.from(rawPagination);
    final page = pagination['page'];
    final limit = pagination['limit'];
    final totalItems = pagination['totalItems'];
    final totalPages = pagination['totalPages'];
    final hasNextPage = pagination['hasNextPage'];

    if (page is! int ||
        limit is! int ||
        totalItems is! int ||
        totalPages is! int ||
        hasNextPage is! bool ||
        page < 1 ||
        limit < 1 ||
        totalItems < 0 ||
        totalPages < 0) {
      throw const FormatException('Task pagination metadata is invalid.');
    }

    final items = <TaskModel>[];
    for (var index = 0; index < rawItems.length; index++) {
      final item = rawItems[index];
      if (item is! Map) {
        throw FormatException(
          'Task item at index $index is not a JSON object. '
          'Received ${item.runtimeType}.',
        );
      }

      final taskJson = Map<String, dynamic>.from(item);
      final rawId = taskJson['_id'] ?? taskJson['id'];
      final taskId = rawId is String && rawId.isNotEmpty ? rawId : '<unknown>';
      try {
        items.add(TaskModel.fromJson(taskJson));
      } on FormatException catch (error) {
        throw FormatException(
          'Unable to parse task at index $index (id: $taskId): '
          '${error.message}',
        );
      }
    }

    return TaskPageModel(
      items: items,
      page: page,
      limit: limit,
      totalItems: totalItems,
      totalPages: totalPages,
      hasNextPage: hasNextPage,
    );
  }
}
