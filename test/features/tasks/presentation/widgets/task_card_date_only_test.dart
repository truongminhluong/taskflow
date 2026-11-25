import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task_flow_v2/features/tasks/data/models/task_model.dart';
import 'package:task_flow_v2/features/tasks/presentation/widgets/tasks/task_card.dart';

TaskModel _task(TaskDueDateType type, {DateTime? dueDate, String? date}) =>
    TaskModel(
      id: 'task-1',
      title: 'Task date',
      description: '',
      dueDate: dueDate,
      dueDateType: type,
      dueDateDate: date,
      priority: TaskPriority.medium,
      category: 'Cá nhân',
      isCompleted: false,
    );

Future<void> _pump(WidgetTester tester, TaskModel task) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: TaskCard(task: task, onTap: () {}, onToggle: () {}),
      ),
    ),
  );
}

void main() {
  testWidgets('date-only shows date but no time', (tester) async {
    await _pump(tester, _task(TaskDueDateType.date, date: '2026-11-25'));
    expect(find.text('25/11/2026'), findsOneWidget);
    expect(find.text('00:00'), findsNothing);
  });

  testWidgets('none shows no due date metadata', (tester) async {
    await _pump(tester, _task(TaskDueDateType.none));
    expect(find.text('25/11/2026'), findsNothing);
    expect(find.text('00:00'), findsNothing);
  });
}
