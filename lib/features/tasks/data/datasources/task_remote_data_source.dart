import 'dart:io';

import 'package:dio/dio.dart';
import 'package:task_flow_v2/core/network/api_client.dart';
import 'package:task_flow_v2/features/tasks/data/models/task_page_model.dart';
import 'package:task_flow_v2/features/tasks/data/models/task_model.dart';
import 'package:task_flow_v2/features/tasks/data/models/task_overview_model.dart';
import 'package:task_flow_v2/features/tasks/data/validation/task_attachment_file_validator.dart';

final class TaskRemoteDataSource {
  TaskRemoteDataSource({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  // Lấy danh sách công việc từ backend.
  Future<List<TaskModel>> getTasks() async {
    const limit = 50;
    final tasks = <TaskModel>[];
    var page = 1;

    while (true) {
      final result = await getTaskPage(
        page: page,
        limit: limit,
        sort: 'createdAtDesc',
      );
      tasks.addAll(result.items);

      if (!result.hasNextPage || result.items.isEmpty) return tasks;
      page++;
    }
  }

  Future<TaskPageModel> getTaskPage({
    int page = 1,
    int limit = 20,
    String? search,
    bool? isCompleted,
    String? priority,
    String? dueFrom,
    String? dueBefore,
    String sort = 'createdAtDesc',
  }) async {
    final queryParameters = <String, dynamic>{
      'page': page,
      'limit': limit,
      'sort': sort,
    };

    if (search != null && search.trim().isNotEmpty) {
      queryParameters['search'] = search.trim();
    }
    if (isCompleted != null) queryParameters['isCompleted'] = isCompleted;
    if (priority != null) queryParameters['priority'] = priority;
    if (dueFrom != null) queryParameters['dueFrom'] = dueFrom;
    if (dueBefore != null) queryParameters['dueBefore'] = dueBefore;

    final response = await _apiClient.dio.get(
      '/tasks',
      queryParameters: queryParameters,
    );
    return TaskPageModel.fromApiResponse(response.data);
  }

  Future<TaskOverviewModel> getTaskOverview({
    String? date,
    String timeZone = 'Asia/Ho_Chi_Minh',
  }) async {
    final response = await _apiClient.dio.get(
      '/tasks/overview',
      queryParameters: {
        // ignore: use_null_aware_elements
        if (date case final value?) 'date': value,
        'timeZone': timeZone,
      },
    );
    return TaskOverviewModel.fromApiResponse(response.data);
  }

  Future<TaskModel> getTaskById(String taskId) async {
    final response = await _apiClient.dio.get('/tasks/$taskId');
    final body = response.data;

    if (body is Map && body['data'] is Map) {
      return TaskModel.fromJson(Map<String, dynamic>.from(body['data'] as Map));
    }

    throw const FormatException('API không trả về dữ liệu công việc hợp lệ.');
  }

  // Tạo công việc mới trên backend.
  Future<TaskModel> createTask(TaskModel task) async {
    final response = await _apiClient.dio.post(
      '/tasks',
      data: task.toApiJson(),
    );

    final body = response.data;

    if (body is Map && body['data'] is Map) {
      return TaskModel.fromJson(Map<String, dynamic>.from(body['data'] as Map));
    }

    throw const FormatException(
      'API tạo công việc không trả về dữ liệu công việc.',
    );
  }

  Future<TaskAttachment> uploadTaskAttachment({
    required String path,
    required String name,
  }) async {
    final file = File(path);
    final sizeBytes = await file.length();
    final handle = await file.open();
    late final List<int> header;
    try {
      header = await handle.read(16);
    } finally {
      await handle.close();
    }

    final mimeType = TaskAttachmentFileValidator.validate(
      sizeBytes: sizeBytes,
      header: header,
    );
    final multipartFile = await MultipartFile.fromFile(
      path,
      filename: name,
      contentType: DioMediaType.parse(mimeType),
    );
    final response = await _apiClient.dio.post(
      '/uploads/task-attachments',
      data: FormData.fromMap({'file': multipartFile}),
      options: Options(contentType: Headers.multipartFormDataContentType),
    );
    final body = response.data;

    if (body is! Map || body['data'] is! Map) {
      throw const FormatException(
        'API tải ảnh không trả về metadata hợp lệ.',
      );
    }

    final attachment = TaskAttachment.fromJson(
      Map<String, dynamic>.from(body['data'] as Map),
    );
    if (attachment.publicId == null ||
        attachment.mimeType != mimeType ||
        attachment.sizeBytes != sizeBytes) {
      throw const FormatException(
        'Metadata ảnh tải lên không khớp với tệp đã chọn.',
      );
    }
    return attachment;
  }

  // Cập nhật trạng thái hoàn thành của công việc.
  Future<void> updateTaskCompletion(String taskId, bool isCompleted) async {
    if (isCompleted) {
      await _apiClient.dio.patch('/tasks/$taskId/complete');
      return;
    }

    await _apiClient.dio.patch('/tasks/$taskId', data: {'isCompleted': false});
  }

  // Sửa toàn bộ thông tin công việc.
  Future<TaskModel> updateTask(TaskModel task) async {
    if (task.recurrenceId != null && !task.isCompleted) {
      if (task.repeat.enabled) {
        await updateRecurringSeries(task.recurrenceId!, task.repeat);
      } else {
        await stopRecurringSeries(task.recurrenceId!);
      }
    }

    final response = await _apiClient.dio.patch(
      '/tasks/${task.id}',
      data: task.toApiJson(
        includeRepeat: task.recurrenceId == null,
        includeDateTimeFields: !task.legacyDateTime,
      ),
    );

    final body = response.data;

    // Nếu backend trả về công việc đã cập nhật trong data,
    // dùng dữ liệu thực tế từ backend.
    if (body is Map && body['data'] is Map) {
      return TaskModel.fromJson(Map<String, dynamic>.from(body['data'] as Map));
    }

    // Một số API chỉ trả thông báo thành công.
    // Khi đó sử dụng dữ liệu vừa gửi lên.
    return task;
  }

  // Xoá công việc theo ID.
  Future<void> deleteTask(String taskId) async {
    await _apiClient.dio.delete('/tasks/$taskId');
  }

  Future<Map<String, dynamic>> getRecurringSeries() async {
    final response = await _apiClient.dio.get('/tasks/recurring-series');
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> getRecurringSeriesById(
    String recurrenceId,
  ) async {
    final response = await _apiClient.dio.get(
      '/tasks/recurring-series/$recurrenceId',
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> updateRecurringSeries(
    String recurrenceId,
    TaskRepeatConfig repeat,
  ) async {
    final response = await _apiClient.dio.patch(
      '/tasks/recurring-series/$recurrenceId',
      data: {'repeat': repeat.toJson()},
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> stopRecurringSeries(String recurrenceId) async {
    final response = await _apiClient.dio.delete(
      '/tasks/recurring-series/$recurrenceId',
    );
    return Map<String, dynamic>.from(response.data as Map);
  }
}
