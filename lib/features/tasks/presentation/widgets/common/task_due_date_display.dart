import 'package:task_flow_v2/features/tasks/data/models/task_model.dart';

DateTime? taskCalendarDate(TaskModel task) {
  if (task.dueDateType == TaskDueDateType.none) return null;
  if (task.dueDateType == TaskDueDateType.date) {
    final value = task.dueDateDate;
    if (value == null) return null;
    final parts = value.split('-').map(int.parse).toList();
    return DateTime(parts[0], parts[1], parts[2]);
  }
  return task.dueDate;
}

String? taskDateLabel(TaskModel task) {
  final date = taskCalendarDate(task);
  if (date == null) return null;
  return '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';
}

bool taskHasDate(TaskModel task) => taskCalendarDate(task) != null;
