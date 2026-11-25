import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task_flow_v2/features/tasks/data/models/task_model.dart';
import 'package:task_flow_v2/features/tasks/data/models/task_page_model.dart';
import 'package:task_flow_v2/features/tasks/data/models/task_overview_model.dart';
import 'package:task_flow_v2/features/tasks/domain/repositories/task_repository.dart';
import 'package:task_flow_v2/features/tasks/presentation/navigation/task_notification_router.dart';
import 'package:task_flow_v2/features/tasks/presentation/providers/task_provider.dart';

void main() {
  testWidgets(
    'notification tap opens its task after authenticated shell is ready',
    (tester) async {
      TaskNotificationRouter.authenticatedShellClosed();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            taskRepositoryProvider.overrideWithValue(_FakeRepository()),
          ],
          child: MaterialApp(
            navigatorKey: TaskNotificationRouter.navigatorKey,
            home: const Scaffold(body: Text('Home')),
          ),
        ),
      );

      TaskNotificationRouter.openTask('task-from-notification');
      expect(find.text('Home'), findsOneWidget);

      TaskNotificationRouter.authenticatedShellReady();
      await tester.pumpAndSettle();

      expect(find.text('Chi tiết công việc'), findsOneWidget);

      TaskNotificationRouter.authenticatedShellClosed();
    },
  );
}

final class _FakeRepository implements TaskRepository {
  @override
  Future<List<TaskModel>> getTasks() async => const [];

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
  }) async => const TaskPageModel(
    items: [],
    page: 1,
    limit: 20,
    totalItems: 0,
    totalPages: 0,
    hasNextPage: false,
  );

  @override
  Future<TaskModel> createTask(TaskModel task) async => task;

  @override
  Future<TaskAttachment> uploadTaskAttachment({
    required String path,
    required String name,
  }) async => throw UnimplementedError();

  @override
  Future<void> updateTaskCompletion(String taskId, bool isCompleted) async {}

  @override
  Future<TaskModel> updateTask(TaskModel task) async => task;

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
