import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task_flow_v2/core/theme/app_theme.dart';
import 'package:task_flow_v2/features/tasks/data/models/task_model.dart';
import 'package:task_flow_v2/features/tasks/data/models/task_page_model.dart';
import 'package:task_flow_v2/features/tasks/data/models/task_overview_model.dart';
import 'package:task_flow_v2/features/tasks/domain/repositories/task_repository.dart';
import 'package:task_flow_v2/features/tasks/presentation/providers/task_provider.dart';
import 'package:task_flow_v2/features/tasks/presentation/screens/task_screen.dart';

void main() {
  testWidgets(
    'loads the next page when the task list is scrolled near its end',
    (tester) async {
      final repository = _FakeRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [taskRepositoryProvider.overrideWithValue(repository)],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const Scaffold(body: TaskScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Task 1'), findsOneWidget);
      expect(
        repository.requests.where(
          (request) => request.page == 2 && request.isCompleted == false,
        ),
        isEmpty,
      );

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -2400));
      await tester.pumpAndSettle();

      expect(find.text('Task 21'), findsOneWidget);
      expect(
        repository.requests.where(
          (request) => request.page == 2 && request.isCompleted == false,
        ),
        hasLength(1),
      );
    },
  );
}

final class _FakeRepository implements TaskRepository {
  final requests = <({int page, bool? isCompleted})>[];

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
  }) async {
    requests.add((page: page, isCompleted: isCompleted));

    if (isCompleted == true) {
      return _page(const [], page: 1, totalItems: 0, hasNext: false);
    }

    if (page == 1) {
      return _page(
        List.generate(20, (index) => _task('Task ${index + 1}')),
        page: 1,
        totalItems: 21,
        hasNext: true,
      );
    }

    return _page([_task('Task 21')], page: 2, totalItems: 21, hasNext: false);
  }

  @override
  Future<List<TaskModel>> getTasks() async => const [];

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
  Future<void> updateTaskCompletion(String taskId, bool isCompleted) async {}

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
  Future<TaskModel> getTaskById(String taskId) async =>
      throw UnimplementedError();

  @override
  Future<TaskOverviewModel> getTaskOverview({
    String? date,
    String timeZone = 'Asia/Ho_Chi_Minh',
  }) async => throw UnimplementedError();
}

TaskPageModel _page(
  List<TaskModel> items, {
  required int page,
  required int totalItems,
  required bool hasNext,
}) => TaskPageModel(
  items: items,
  page: page,
  limit: 20,
  totalItems: totalItems,
  totalPages: hasNext ? 2 : (totalItems == 0 ? 0 : 1),
  hasNextPage: hasNext,
);

TaskModel _task(String title) => TaskModel(
  id: title,
  title: title,
  description: '',
  dueDate: null,
  priority: TaskPriority.medium,
  category: 'Cá nhân',
  isCompleted: false,
);
