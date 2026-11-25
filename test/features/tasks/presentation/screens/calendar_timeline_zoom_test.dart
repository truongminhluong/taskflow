import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task_flow_v2/core/theme/app_theme.dart';
import 'package:task_flow_v2/features/tasks/data/models/task_model.dart';
import 'package:task_flow_v2/features/tasks/data/models/task_overview_model.dart';
import 'package:task_flow_v2/features/tasks/data/models/task_page_model.dart';
import 'package:task_flow_v2/features/tasks/domain/repositories/task_repository.dart';
import 'package:task_flow_v2/features/tasks/presentation/providers/task_provider.dart';
import 'package:task_flow_v2/features/tasks/presentation/screens/calendar_screen.dart';
import 'package:task_flow_v2/features/tasks/presentation/screens/task_details_screen.dart';

void main() {
  testWidgets('initial auto-scroll waits for a laid out empty timeline', (
    tester,
  ) async {
    final loadCompleter = Completer<List<TaskModel>>();
    final now = DateTime.now();
    final repository = _CalendarRepository(
      tasks: const [],
      taskLoad: loadCompleter.future,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [taskRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: CalendarScreen()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    final scrollController = tester
        .widget<CustomScrollView>(find.byType(CustomScrollView))
        .controller!;
    expect(scrollController.offset, 0);

    loadCompleter.complete(const []);
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('00:00'), findsOneWidget);
    expect(tester.takeException(), isNull);
    final position = scrollController.position;
    expect(position.hasContentDimensions, isTrue);
    final markerCenter =
        ((now.hour * 60 + now.minute) / 60) * 72 + AppSpace.sm + 4;
    final expectedOffset = (markerCenter - position.viewportDimension / 2)
        .clamp(0.0, position.maxScrollExtent);
    expect(scrollController.offset, closeTo(expectedOffset, 3));
  });

  testWidgets('pinch zoom preserves task times and avoids layout overflow', (
    tester,
  ) async {
    final dueDate = DateTime.now().add(const Duration(hours: 1));
    final repository = _CalendarRepository(
      tasks: [
        TaskModel(
          id: 'zoom-task',
          title: 'Zoom task',
          description: '',
          dueDate: dueDate,
          priority: TaskPriority.medium,
          category: 'Cá nhân',
          isCompleted: false,
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [taskRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: CalendarScreen()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    await _pinchTimeline(tester, 0.5);
    expect(repository.tasks.single.dueDate, dueDate);
    expect(tester.takeException(), isNull);

    await _pinchTimeline(tester, 4);
    expect(repository.tasks.single.dueDate, dueDate);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'timeline cards adapt details to zoom while preserving hit area',
    (tester) async {
      final now = DateTime.now();
      final dueDate = DateTime(now.year, now.month, now.day, 9, 15);
      final repository = _CalendarRepository(
        tasks: [
          TaskModel(
            id: 'adaptive-task',
            title: 'Adaptive timeline task',
            description: 'A short task description',
            dueDate: dueDate,
            priority: TaskPriority.high,
            category: 'Cá nhân',
            isCompleted: false,
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [taskRepositoryProvider.overrideWithValue(repository)],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const Scaffold(body: CalendarScreen()),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      final card = find.text('Adaptive timeline task');
      final singleCard = find
          .ancestor(of: card, matching: find.byType(Card))
          .first;
      final completionIndicator = find.descendant(
        of: singleCard,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Icon &&
              (widget.icon == Icons.check_circle ||
                  widget.icon == Icons.radio_button_unchecked),
        ),
      );
      void expectIndicatorCentered() {
        expect(completionIndicator, findsOneWidget);
        expect(
          tester.getRect(completionIndicator).center.dy,
          closeTo(tester.getRect(singleCard).center.dy, .01),
        );
      }

      final cardRectAt100 = tester.getRect(card);
      expect(card, findsOneWidget);
      expect(find.text('A short task description'), findsNothing);
      Positioned placement() => tester.widget(
        find.ancestor(of: card, matching: find.byType(Positioned)).first,
      );
      final hourLine = find
          .descendant(
            of: find
                .ancestor(
                  of: find.text('09:00').first,
                  matching: find.byType(Row),
                )
                .first,
            matching: find.byType(Divider),
          )
          .first;
      expect(
        tester.getRect(singleCard).top - tester.getRect(hourLine).bottom,
        4,
      );
      expect(placement().top, dueDate.hour * 72 + 5);
      expect(placement().height, 62);
      expectIndicatorCentered();
      final scrollController = tester
          .widget<CustomScrollView>(find.byType(CustomScrollView))
          .controller!;
      scrollController.jumpTo(dueDate.hour * 72);
      await tester.pumpAndSettle();
      await tester.tap(completionIndicator);
      await tester.pumpAndSettle();
      expect(repository.toggledTaskIds, ['adaptive-task']);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(find.byType(TaskDetailsScreen), findsNothing);

      await _pinchTimeline(tester, 0.5);
      expect(
        tester.getRect(singleCard).top - tester.getRect(hourLine).bottom,
        4,
      );
      expect(placement().top, dueDate.hour * 36 + 5);
      expect(placement().height, 26);
      expectIndicatorCentered();
      expect(find.text('A short task description'), findsNothing);
      expect(tester.takeException(), isNull);

      await _pinchTimeline(tester, 1.5);
      expect(placement().height, 44);
      expectIndicatorCentered();

      await _pinchTimeline(tester, 4 / 3);
      expect(placement().height, 62);
      expectIndicatorCentered();

      await _pinchTimeline(tester, 1.5);
      expect(placement().height, 98);
      expectIndicatorCentered();
      expect(find.text('A short task description'), findsOneWidget);

      await _pinchTimeline(tester, 4 / 3);
      expect(
        tester.getRect(singleCard).top - tester.getRect(hourLine).bottom,
        4,
      );
      expect(placement().top, dueDate.hour * 144 + 5);
      expect(placement().height, 134);
      expectIndicatorCentered();
      expect(find.text('Adaptive timeline task'), findsOneWidget);
      expect(tester.takeException(), isNull);

      expect(tester.getRect(card).height, cardRectAt100.height);
    },
  );

  testWidgets(
    'groups tasks by hour and preserves the priority representative across zoom',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final now = DateTime.now();
      final dueDates = [0, 15, 30, 55]
          .map(
            (minutes) => DateTime(
              now.year,
              now.month,
              now.day,
              9,
            ).add(Duration(minutes: minutes)),
          )
          .toList();
      final repository = _CalendarRepository(
        tasks: List.generate(
          4,
          (index) => TaskModel(
            id: 'group-$index',
            title: 'Grouped task $index',
            description: 'Mô tả cho công việc $index',
            dueDate: dueDates[index],
            priority: index == 1 ? TaskPriority.high : TaskPriority.medium,
            category: 'Cá nhân',
            isCompleted: index == 3,
          ),
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [taskRepositoryProvider.overrideWithValue(repository)],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const Scaffold(body: CalendarScreen()),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('3 lời nhắc khác'), findsOneWidget);
      expect(find.text('Grouped task 1'), findsOneWidget);
      expect(find.text('Grouped task 0'), findsNothing);

      await tester.ensureVisible(find.text('3 lời nhắc khác'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('3 lời nhắc khác'));
      await tester.pumpAndSettle();
      expect(find.text('Grouped task 0'), findsOneWidget);
      expect(find.text('Grouped task 1'), findsNWidgets(2));
      expect(find.text('Grouped task 2'), findsOneWidget);
      expect(find.text('Grouped task 3'), findsOneWidget);
      expect(find.text('Các công việc trong khung giờ này'), findsOneWidget);
      expect(find.text('Mô tả cho công việc 0'), findsOneWidget);
      expect(find.text('Mô tả cho công việc 1'), findsOneWidget);
      expect(find.text('09:00'), findsNWidgets(2));
      expect(find.text('09:15'), findsOneWidget);
      expect(find.text('09:30'), findsOneWidget);
      expect(find.text('09:55'), findsOneWidget);
      expect(find.text('Ưu tiên cao'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();
      expect(repository.toggledTaskIds, ['group-0']);
      expect(
        tester
            .widgetList<Checkbox>(find.byType(Checkbox))
            .map((box) => box.value),
        [true, false, false, true],
      );

      await tester.tap(find.text('Grouped task 1').last);
      await tester.pumpAndSettle();
      expect(find.byType(TaskDetailsScreen), findsOneWidget);
      expect(find.text('Mô tả cho công việc 1'), findsOneWidget);
      Navigator.of(tester.element(find.byType(TaskDetailsScreen))).pop();
      await tester.pumpAndSettle();
      final groupLabel = find.text('3 lời nhắc khác');
      final groupCard = find
          .ancestor(of: groupLabel, matching: find.byType(Card))
          .first;
      final groupPlacement = find
          .ancestor(of: groupLabel, matching: find.byType(Positioned))
          .first;
      expect(
        find.descendant(
          of: groupCard,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Icon &&
                (widget.icon == Icons.check_circle ||
                    widget.icon == Icons.radio_button_unchecked),
          ),
        ),
        findsNothing,
      );
      expect(
        find.descendant(of: groupCard, matching: find.byType(Checkbox)),
        findsNothing,
      );
      final hourLine = find
          .descendant(
            of: find
                .ancestor(
                  of: find.text('09:00').first,
                  matching: find.byType(Row),
                )
                .first,
            matching: find.byType(Divider),
          )
          .first;
      final heightAt100 = tester.getSize(groupCard).height;
      expect(tester.widget<Positioned>(groupPlacement).top!, 9 * 72 + 5);
      expect(heightAt100, 72 - 10);
      expect(
        tester.getRect(groupCard).top - tester.getRect(hourLine).bottom,
        4,
      );
      await _pinchTimeline(tester, 2);
      expect(tester.widget<Positioned>(groupPlacement).top!, 9 * 144 + 5);
      expect(
        tester.getRect(groupCard).top - tester.getRect(hourLine).bottom,
        4,
      );
      expect(tester.getSize(groupCard).height, closeTo(144 - 10, .1));
      expect(heightAt100, closeTo(72 - 10, .1));
      expect(find.text('3 lời nhắc khác'), findsOneWidget);
      expect(find.text('Grouped task 1'), findsOneWidget);
      expect(find.text('Grouped task 0'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('dense tasks stay within narrow cards at minimum zoom', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final dueDate = DateTime.now().add(const Duration(hours: 1));
    final repository = _CalendarRepository(
      tasks: List.generate(
        6,
        (index) => TaskModel(
          id: 'task-$index',
          title: 'Dense task $index',
          description: '',
          dueDate: dueDate,
          priority: TaskPriority.medium,
          category: 'Cá nhân',
          isCompleted: false,
        ),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [taskRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: CalendarScreen()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('5 lời nhắc khác'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

var _nextPointer = 10;

Future<void> _pinchTimeline(WidgetTester tester, double scale) async {
  final firstPointer = _nextPointer++;
  final secondPointer = _nextPointer++;
  final scrollRect = tester.getRect(find.byType(CustomScrollView));
  final focalPoint = scrollRect.center;
  const startOffset = 30.0;
  final endOffset = startOffset * scale;
  final first = await tester.startGesture(
    focalPoint - const Offset(0, startOffset),
    pointer: firstPointer,
  );
  final second = await tester.startGesture(
    focalPoint + const Offset(0, startOffset),
    pointer: secondPointer,
  );
  await first.moveTo(focalPoint - Offset(0, endOffset));
  await second.moveTo(focalPoint + Offset(0, endOffset));
  await tester.pump();
  await first.up();
  await second.up();
  await tester.pumpAndSettle();
}

final class _CalendarRepository implements TaskRepository {
  _CalendarRepository({required this.tasks, this.taskLoad});

  final List<TaskModel> tasks;
  final Future<List<TaskModel>>? taskLoad;
  final List<String> toggledTaskIds = [];

  @override
  Future<List<TaskModel>> getTasks() => taskLoad ?? Future.value(tasks);

  @override
  Future<TaskPageModel> getTaskPage({
    int page = 1,
    int limit = 20,
    String? search,
    bool? isCompleted,
    String? priority,
    String? dueFrom,
    String? dueBefore,
    String sort = 'createdAtDesc',
  }) async => TaskPageModel(
    items: tasks,
    page: 1,
    limit: 20,
    totalItems: tasks.length,
    totalPages: 1,
    hasNextPage: false,
  );

  @override
  Future<TaskOverviewModel> getTaskOverview({
    String? date,
    String timeZone = 'Asia/Ho_Chi_Minh',
  }) async => throw UnimplementedError();

  @override
  Future<TaskModel> createTask(TaskModel task) async => task;

  @override
  Future<TaskAttachment> uploadTaskAttachment({
    required String path,
    required String name,
  }) async => throw UnimplementedError();

  @override
  Future<TaskModel> updateTask(TaskModel task) async => task;

  @override
  Future<void> updateTaskCompletion(String taskId, bool isCompleted) async {
    toggledTaskIds.add(taskId);
  }

  @override
  Future<void> deleteTask(String taskId) async {}

  @override
  Future<Map<String, dynamic>> getRecurringSeries() async => {};
  @override
  Future<Map<String, dynamic>> getRecurringSeriesById(String id) async => {};
  @override
  Future<Map<String, dynamic>> updateRecurringSeries(
    String id,
    TaskRepeatConfig repeat,
  ) async => {};
  @override
  Future<Map<String, dynamic>> stopRecurringSeries(String id) async => {};

  @override
  Future<TaskModel> getTaskById(String taskId) async => tasks.first;
}
