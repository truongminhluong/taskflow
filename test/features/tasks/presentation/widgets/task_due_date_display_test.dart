import 'package:flutter_test/flutter_test.dart';
import 'package:task_flow_v2/features/tasks/data/models/task_model.dart';
import 'package:task_flow_v2/features/tasks/presentation/widgets/common/task_due_date_display.dart';

TaskModel _task({
  TaskDueDateType type = TaskDueDateType.none,
  DateTime? dueDate,
  String? dueDateDate,
}) => TaskModel(
  id: 'task-1',
  title: 'Task',
  description: '',
  dueDate: dueDate,
  dueDateType: type,
  dueDateDate: dueDateDate,
  priority: TaskPriority.medium,
  category: 'Cá nhân',
  isCompleted: false,
);

void main() {
  test('none has no calendar date', () {
    expect(taskCalendarDate(_task()), isNull);
    expect(taskDateLabel(_task()), isNull);
  });

  test('date-only preserves the calendar date without UTC conversion', () {
    final task = _task(type: TaskDueDateType.date, dueDateDate: '2026-11-25');
    final date = taskCalendarDate(task);
    expect(date, DateTime(2026, 11, 25));
    expect(date!.hour, 0);
    expect(taskDateLabel(task), '25/11/2026');
  });

  test('dateTime uses the local calendar date', () {
    final task = _task(
      type: TaskDueDateType.dateTime,
      dueDate: DateTime.parse('2026-11-25T07:30:00.000Z').toLocal(),
    );
    expect(taskCalendarDate(task), task.dueDate!.toLocal());
    expect(taskHasDate(task), isTrue);
  });
}
