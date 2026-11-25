import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task_flow_v2/core/theme/app_theme.dart';
import 'package:task_flow_v2/features/tasks/data/models/task_model.dart';
import 'package:task_flow_v2/features/tasks/presentation/widgets/calendar/calendar_month_grid.dart';
import 'package:task_flow_v2/features/tasks/presentation/widgets/common/vietnamese_date.dart';

void main() {
  testWidgets('shows weekday labels and always renders 42 date cells', (
    tester,
  ) async {
    await _pumpGrid(tester, visibleMonth: DateTime(2026, 2));

    expect(find.text('T2'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            const [
              'T2',
              'T3',
              'T4',
              'T5',
              'T6',
              'T7',
              'CN',
            ].contains(widget.data),
      ),
      findsNWidgets(7),
    );
    expect(
      find.descendant(of: find.byType(GridView), matching: find.byType(Text)),
      findsNWidgets(42),
    );
  });

  testWidgets('places the first day in its Monday-based weekday column', (
    tester,
  ) async {
    await _pumpGrid(tester, visibleMonth: DateTime(2026, 2));

    final saturdayCell = _cell(DateTime(2026, 1, 31));
    final sundayCell = _cell(DateTime(2026, 2, 1));
    expect(
      tester.getTopLeft(sundayCell).dx,
      greaterThan(tester.getTopLeft(saturdayCell).dx),
    );

    await _pumpGrid(tester, visibleMonth: DateTime(2026, 6));
    final mondayCell = _cell(DateTime(2026, 6, 1));
    final tuesdayCell = _cell(DateTime(2026, 6, 2));
    expect(
      tester.getTopLeft(mondayCell).dx,
      lessThan(tester.getTopLeft(tuesdayCell).dx),
    );
  });

  testWidgets('shows and selects dates outside the visible month', (
    tester,
  ) async {
    DateTime? selected;
    await _pumpGrid(
      tester,
      visibleMonth: DateTime(2026, 2),
      onSelect: (date) => selected = date,
    );

    final previousMonthDate = _cell(DateTime(2026, 1, 31));
    expect(previousMonthDate, findsOneWidget);
    await tester.tap(previousMonthDate);
    expect(selected, DateTime(2026, 1, 31));

    final nextMonthDate = _cell(DateTime(2026, 3, 1));
    expect(nextMonthDate, findsOneWidget);
    await tester.tap(nextMonthDate);
    expect(selected, DateTime(2026, 3, 1));
  });

  testWidgets('marks today and selected date in semantics and appearance', (
    tester,
  ) async {
    final today = DateTime(2026, 2, 12);
    final selectedDate = DateTime(2026, 2, 13);
    await _pumpGrid(
      tester,
      visibleMonth: DateTime(2026, 2),
      today: today,
      selectedDate: selectedDate,
    );

    final todayFinder = _cell(today);
    final todaySemantics = tester.widget<Semantics>(todayFinder);
    expect(todaySemantics.properties.label, startsWith('Hôm nay, '));
    expect(todaySemantics.properties.selected, isFalse);
    final todayDecoration =
        tester
                .widget<Container>(
                  find
                      .descendant(
                        of: todayFinder,
                        matching: find.byType(Container),
                      )
                      .first,
                )
                .decoration!
            as BoxDecoration;
    expect(todayDecoration.border, isA<Border>());

    final selectedFinder = _cell(selectedDate);
    final selectedSemantics = tester.widget<Semantics>(selectedFinder);
    expect(selectedSemantics.properties.selected, isTrue);
    final selectedDecoration =
        tester
                .widget<Container>(
                  find
                      .descendant(
                        of: selectedFinder,
                        matching: find.byType(Container),
                      )
                      .first,
                )
                .decoration!
            as BoxDecoration;
    expect(selectedDecoration.color, AppTheme.light.colorScheme.primary);
  });

  testWidgets('marks dates with any due task, including completed tasks', (
    tester,
  ) async {
    final dueDate = DateTime(2026, 2, 12, 17);
    await _pumpGrid(
      tester,
      visibleMonth: DateTime(2026, 2),
      selectedDate: DateTime(2026, 2, 13),
      tasks: [
        _task(id: 'completed', dueDate: dueDate, isCompleted: true),
        _task(id: 'no-date', dueDate: null),
      ],
    );

    final cell = _cell(DateTime(2026, 2, 12));
    expect(
      tester.widget<Semantics>(cell).properties.label,
      contains('có công việc'),
    );
    final containers = tester.widgetList<Container>(
      find.descendant(of: cell, matching: find.byType(Container)),
    );
    final dotDecoration = containers.last.decoration! as BoxDecoration;
    expect(dotDecoration.color, AppTheme.light.colorScheme.secondary);

    final dateWithoutTask = _cell(DateTime(2026, 2, 13));
    expect(
      tester.widget<Semantics>(dateWithoutTask).properties.label,
      contains('không có công việc'),
    );
  });

  testWidgets('renders correct final days for 28, 29, 30, and 31 day months', (
    tester,
  ) async {
    final cases = [
      (DateTime(2021, 2), DateTime(2021, 2, 28)),
      (DateTime(2024, 2), DateTime(2024, 2, 29)),
      (DateTime(2026, 4), DateTime(2026, 4, 30)),
      (DateTime(2026, 1), DateTime(2026, 1, 31)),
    ];

    for (final (month, lastDay) in cases) {
      await _pumpGrid(tester, visibleMonth: month);
      expect(_cell(lastDay), findsOneWidget);
      expect(
        find.descendant(of: find.byType(GridView), matching: find.byType(Text)),
        findsNWidgets(42),
      );
    }
  });
}

Finder _cell(DateTime date) {
  final dateLabel = VietnameseDate.full(date);
  return find.byWidgetPredicate(
    (widget) =>
        widget is Semantics &&
        widget.properties.button == true &&
        widget.properties.label?.contains(dateLabel) == true,
  );
}

Future<void> _pumpGrid(
  WidgetTester tester, {
  required DateTime visibleMonth,
  DateTime? selectedDate,
  DateTime? today,
  List<TaskModel> tasks = const [],
  ValueChanged<DateTime>? onSelect,
}) {
  final currentDay = today ?? DateTime(2026, 2, 12);
  return tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 360,
            child: CalendarMonthGrid(
              visibleMonth: visibleMonth,
              selectedDate: selectedDate ?? currentDay,
              today: currentDay,
              tasks: tasks,
              onSelect: onSelect ?? (_) {},
            ),
          ),
        ),
      ),
    ),
  );
}

TaskModel _task({
  required String id,
  required DateTime? dueDate,
  bool isCompleted = false,
}) {
  return TaskModel(
    id: id,
    title: id,
    description: '',
    dueDate: dueDate,
    priority: TaskPriority.medium,
    category: 'Cá nhân',
    isCompleted: isCompleted,
  );
}
