import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task_flow_v2/features/tasks/presentation/widgets/tasks/task_due_date_reminder_section.dart';

void main() {
  testWidgets('without a due date hides reminder controls and disables time', (
    tester,
  ) async {
    bool? dateEnabled;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: TaskDueDateReminderSection(
              dueDate: null,
              selectedTime: const TimeOfDay(hour: 9, minute: 0),
              isUrgent: false,
              onDateToggled: (enabled) => dateEnabled = enabled,
              onDateSelected: (_) {},
              onTimeChanged: (_) {},
              onUrgencyChanged: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(find.byType(InlineCalendar), findsNothing);

    await tester.tap(find.byKey(const ValueKey('choose-task-date')));
    expect(dateEnabled, isTrue);
  });

  testWidgets('with a due date shows values and forwards section callbacks', (
    tester,
  ) async {
    DateTime? selectedDate;
    TimeOfDay? selectedTime;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: TaskDueDateReminderSection(
              dueDate: DateTime(2026, 4, 3, 9, 30),
              selectedTime: const TimeOfDay(hour: 9, minute: 30),
              isUrgent: false,
              onDateToggled: (_) {},
              onDateSelected: (value) => selectedDate = value,
              onTimeChanged: (value) => selectedTime = value,
              onUrgencyChanged: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('03/04/2026'), findsOneWidget);
    expect(find.byType(InlineCalendar), findsOneWidget);

    await tester.tap(find.text('12').last);
    expect(selectedDate, DateTime(2026, 4, 12));

    await tester.tap(find.text('Thời gian'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CupertinoPicker).first, const Offset(0, -36));
    await tester.pumpAndSettle();
    expect(selectedTime, isNotNull);
  });
}
