import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task_flow_v2/features/tasks/presentation/widgets/tasks/home_progress_overview.dart';

void main() {
  testWidgets('shows progress and opens tasks when tapped', (tester) async {
    var openTasksCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeProgressOverview(
            completed: 2,
            total: 3,
            progress: 2 / 3,
            onOpenTasks: () => openTasksCount++,
          ),
        ),
      ),
    );

    expect(find.text('Tiến độ hôm nay'), findsOneWidget);
    expect(find.text('2/3'), findsOneWidget);
    expect(find.text('Cố lên! Bạn làm được mà!'), findsOneWidget);
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      2 / 3,
    );

    await tester.tap(find.byIcon(Icons.chevron_right_rounded));
    expect(openTasksCount, 1);
  });

  for (final scenario in const [
    (total: 0, completed: 0, expected: 0.0),
    (total: 3, completed: 0, expected: 0.0),
    (total: 4, completed: 2, expected: 0.5),
    (total: 5, completed: 3, expected: 0.6),
    (total: 5, completed: 5, expected: 1.0),
  ]) {
    testWidgets(
      'renders progress for ${scenario.completed}/${scenario.total}',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: HomeProgressOverview(
                completed: scenario.completed,
                total: scenario.total,
                progress: scenario.expected,
                onOpenTasks: _ignoreTap,
              ),
            ),
          ),
        );

        final indicator = tester.widget<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator),
        );
        expect(indicator.value, scenario.expected);
        expect(
          find.text('${scenario.completed}/${scenario.total}'),
          findsOneWidget,
        );
      },
    );
  }

  testWidgets('shows status in place of progress while loading or failing', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: HomeProgressOverview(
            completed: 0,
            total: 0,
            progress: 0,
            statusMessage: 'Đang tải tiến độ hôm nay.',
            onOpenTasks: _ignoreTap,
          ),
        ),
      ),
    );

    expect(find.text('Đang tải tiến độ hôm nay.'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.text('0/0'), findsNothing);
  });
}

void _ignoreTap() {}
