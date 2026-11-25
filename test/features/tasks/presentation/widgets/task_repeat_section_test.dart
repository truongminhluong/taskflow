import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task_flow_v2/features/tasks/data/models/task_model.dart';
import 'package:task_flow_v2/features/tasks/presentation/widgets/tasks/task_due_date_reminder_section.dart';

void main() {
  testWidgets('repeat settings appear only after selecting a frequency', (
    tester,
  ) async {
    TaskRepeatFrequency? selectedFrequency;
    String? selectedEndType;
    Widget buildSection({
      required bool enabled,
      String endTypeLabel = 'Không',
      String? endDate,
    }) => MaterialApp(
      home: Scaffold(
        body: TaskRepeatReminderSection(
          repeatLabel: enabled ? 'Hằng tuần' : 'Không lặp lại',
          repeatEnabled: enabled,
          endTypeLabel: endTypeLabel,
          endDate: endDate,
          endDateValue: DateTime(2026, 11, 20),
          repeatConfig: enabled
              ? const TaskRepeatConfig(
                  enabled: true,
                  frequency: TaskRepeatFrequency.weekly,
                  weekdays: [5],
                )
              : const TaskRepeatConfig.disabled(),
          onRepeatChanged: (value) => selectedFrequency = value,
          onEndTypeChanged: (value) => selectedEndType = value,
          onEndDateSelected: (_) {},
          reminderSelection: 0,
          reminderEnabled: true,
          onReminderChanged: (_) {},
        ),
      ),
    );

    await tester.pumpWidget(buildSection(enabled: false));
    expect(find.text('Lặp lại'), findsOneWidget);
    expect(find.text('Kết thúc lặp lại'), findsNothing);
    final noRepeatText = tester.widget<Text>(find.text('Không lặp lại'));
    expect(
      noRepeatText.style?.color,
      Theme.of(tester.element(find.text('Không lặp lại')))
          .colorScheme
          .onSurface,
    );

    await tester.tap(find.text('Lặp lại'));
    await tester.pumpAndSettle();
    expect(find.text('Hằng tuần'), findsOneWidget);
    expect(find.text('Tùy chỉnh'), findsNothing);

    await tester.tap(find.text('Hằng tuần'));
    await tester.pumpAndSettle();
    expect(selectedFrequency, TaskRepeatFrequency.weekly);

    await tester.pumpWidget(buildSection(enabled: true));
    expect(find.text('Hằng tuần'), findsOneWidget);
    expect(find.text('Kết thúc lặp lại'), findsOneWidget);
    expect(find.text('Ngày kết thúc'), findsNothing);
    await tester.tap(find.text('Kết thúc lặp lại'));
    await tester.pumpAndSettle();
    expect(find.text('Vào ngày'), findsOneWidget);
    await tester.tap(find.text('Vào ngày'));
    await tester.pumpAndSettle();
    expect(selectedEndType, 'Vào ngày');

    await tester.pumpWidget(
      buildSection(enabled: true, endTypeLabel: 'Vào ngày'),
    );
    expect(find.text('Ngày kết thúc'), findsOneWidget);
    expect(find.text('Chọn ngày'), findsOneWidget);
    await tester.tap(find.text('Chọn ngày'));
    await tester.pumpAndSettle();
    expect(find.text('Tháng 11 năm 2026'), findsOneWidget);

    await tester.pumpWidget(
      buildSection(
        enabled: true,
        endTypeLabel: 'Vào ngày',
        endDate: '19/11/2026',
      ),
    );
    expect(find.text('Ngày kết thúc'), findsOneWidget);
    expect(find.text('Ngày 19/11/2026'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
