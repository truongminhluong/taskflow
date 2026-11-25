import '../data/models/task_model.dart';

/// Tìm task có cùng ngày và cùng phút bắt đầu theo giờ địa phương.
List<TaskModel> findTaskStartConflicts(
  TaskModel candidate,
  Iterable<TaskModel> existingTasks, {
  String? excludedTaskId,
}) {
  final candidateDate = candidate.dueDate;
  if (candidateDate == null) return const [];

  return [
    for (final task in existingTasks)
      if (task.id != excludedTaskId && _hasSameLocalStart(candidateDate, task))
        task,
  ];
}

bool _hasSameLocalStart(DateTime candidateDate, TaskModel task) {
  final taskDate = task.dueDate;

  return taskDate != null &&
      taskDate.year == candidateDate.year &&
      taskDate.month == candidateDate.month &&
      taskDate.day == candidateDate.day &&
      taskDate.hour == candidateDate.hour &&
      taskDate.minute == candidateDate.minute;
}
