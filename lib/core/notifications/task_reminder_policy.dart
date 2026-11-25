import '../../features/tasks/data/models/task_model.dart';

abstract final class TaskReminderPolicy {
  static const supportedOffsets = {0, 5, 10, 15, 30, 60, 1440};

  /// Returns the reminder time only when the task should still be scheduled.
  static DateTime? scheduledAt(TaskModel task, {required DateTime now}) {
    final dueDate = task.dueDate;
    final minutesBefore = task.reminderMinutesBefore;

    if (dueDate == null || minutesBefore == null || task.isCompleted) {
      return null;
    }

    if (!supportedOffsets.contains(minutesBefore)) {
      throw FormatException(
        'Thời gian nhắc không hợp lệ: $minutesBefore phút.',
      );
    }

    final reminderTime = dueDate.subtract(Duration(minutes: minutesBefore));
    return reminderTime.isAfter(now) ? reminderTime : null;
  }
}
