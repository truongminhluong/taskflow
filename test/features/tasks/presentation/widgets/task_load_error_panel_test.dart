import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task_flow_v2/features/tasks/presentation/widgets/tasks/task_load_error_panel.dart';

void main() {
  testWidgets('shows the message and invokes the retry callback', (
    tester,
  ) async {
    var retryCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TaskLoadErrorPanel(
            message: 'Không thể tải danh sách công việc.',
            onRetry: () => retryCount++,
          ),
        ),
      ),
    );

    expect(find.text('Không thể tải danh sách công việc.'), findsOneWidget);
    expect(find.text('Thử lại'), findsOneWidget);

    await tester.tap(find.text('Thử lại'));
    expect(retryCount, 1);
  });

  testWidgets('hides retry when no callback is provided', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TaskLoadErrorPanel(message: 'Không thể tải công việc.'),
        ),
      ),
    );

    expect(find.text('Không thể tải công việc.'), findsOneWidget);
    expect(find.text('Thử lại'), findsNothing);
  });
}
