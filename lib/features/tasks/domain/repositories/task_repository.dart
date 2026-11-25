import 'package:task_flow_v2/features/tasks/data/models/task_model.dart';
import 'package:task_flow_v2/features/tasks/data/models/task_page_model.dart';
import 'package:task_flow_v2/features/tasks/data/models/task_overview_model.dart';

abstract interface class TaskRepository {
  /// Lấy toàn bộ danh sách công việc từ nguồn dữ liệu.
  Future<List<TaskModel>> getTasks();

  /// Lấy một trang task đã được lọc và sắp xếp từ nguồn dữ liệu.
  Future<TaskPageModel> getTaskPage({
    int page = 1,
    int limit = 20,
    String? search,
    bool? isCompleted,
    String? priority,
    String? dueFrom,
    String? dueBefore,
    String sort = 'createdAtDesc',
  });

  Future<TaskOverviewModel> getTaskOverview({
    String? date,
    String timeZone = 'Asia/Ho_Chi_Minh',
  });

  Future<TaskModel> getTaskById(String taskId);

  /// Thêm công việc mới.
  Future<TaskModel> createTask(TaskModel task);

  /// Tải một ảnh đính kèm lên và trả về metadata do backend tạo.
  Future<TaskAttachment> uploadTaskAttachment({
    required String path,
    required String name,
  });

  /// Cập nhật trạng thái hoàn thành của một công việc.
  Future<void> updateTaskCompletion(String taskId, bool isCompleted);

  // Sửa thông tin công việc.
  Future<TaskModel> updateTask(TaskModel task);

  // Xoá công việc theo ID.
  Future<void> deleteTask(String taskId);

  Future<Map<String, dynamic>> getRecurringSeries();

  Future<Map<String, dynamic>> getRecurringSeriesById(String recurrenceId);

  Future<Map<String, dynamic>> updateRecurringSeries(
    String recurrenceId,
    TaskRepeatConfig repeat,
  );

  Future<Map<String, dynamic>> stopRecurringSeries(String recurrenceId);
}
