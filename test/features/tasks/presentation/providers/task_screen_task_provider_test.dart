import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task_flow_v2/features/tasks/data/models/task_model.dart';
import 'package:task_flow_v2/features/tasks/data/models/task_page_model.dart';
import 'package:task_flow_v2/features/tasks/data/models/task_overview_model.dart';
import 'package:task_flow_v2/features/tasks/domain/repositories/task_repository.dart';
import 'package:task_flow_v2/features/tasks/presentation/providers/task_provider.dart';
import 'package:task_flow_v2/features/tasks/presentation/providers/task_screen_task_provider.dart';

void main() {
  group('TaskScreenTaskNotifier', () {
    late _FakeRepository repository;
    late ProviderContainer container;

    setUp(() {
      repository = _FakeRepository();
      container = ProviderContainer(
        overrides: [taskRepositoryProvider.overrideWithValue(repository)],
      );
      container.listen(taskScreenTaskProvider, (_, _) {});
    });

    tearDown(() => container.dispose());

    test('loads the first page then appends the next page', () async {
      repository.pageHandler = (request) async {
        if (request.isCompleted == true) {
          return _page(
            [],
            page: 1,
            totalItems: 0,
            totalPages: 0,
            hasNext: false,
          );
        }
        if (request.page == 1) {
          return _page(
            ['a', 'b'],
            page: 1,
            totalItems: 3,
            totalPages: 2,
            hasNext: true,
          );
        }
        return _page(
          ['c'],
          page: 2,
          totalItems: 3,
          totalPages: 2,
          hasNext: false,
        );
      };
      final notifier = container.read(taskScreenTaskProvider.notifier);

      await notifier.loadInitial();
      expect(
        container.read(taskScreenTaskProvider).items.map((task) => task.id),
        ['a', 'b'],
      );
      expect(container.read(taskScreenTaskProvider).hasNextPage, isTrue);

      await notifier.loadMore();
      final state = container.read(taskScreenTaskProvider);
      expect(state.items.map((task) => task.id), ['a', 'b', 'c']);
      expect(state.totalItems, 3);
      expect(state.hasNextPage, isFalse);
      expect(
        repository.requests
            .map((request) => (request.isCompleted, request.page))
            .toList(),
        [(false, 1), (true, 1), (false, 2)],
      );
    });

    test(
      'keeps a task visible and marked complete in the current query',
      () async {
        repository.pageHandler = (request) async => _page(
          ['today-task', 'another-task'],
          page: 1,
          totalItems: 3,
          totalPages: 2,
          hasNext: request.isCompleted != true,
        );
        final notifier = container.read(taskScreenTaskProvider.notifier);

        await notifier.loadInitial(
          dueFrom: '2026-11-10T00:00:00+07:00',
          dueBefore: '2026-11-11T00:00:00+07:00',
        );
        notifier.updateTaskCompletionInPlace('today-task', true);

        var state = container.read(taskScreenTaskProvider);
        expect(state.items.map((task) => task.id), [
          'today-task',
          'another-task',
        ]);
        expect(state.items.first.isCompleted, isTrue);

        repository.pageHandler = (request) async => _page(
          ['next-task'],
          page: request.page,
          totalItems: 3,
          totalPages: 2,
          hasNext: false,
        );
        await notifier.loadMore();
        state = container.read(taskScreenTaskProvider);
        expect(state.items.map((task) => task.id), [
          'today-task',
          'another-task',
          'next-task',
        ]);
        expect(state.items.first.isCompleted, isTrue);
      },
    );

    test('deduplicates concurrent loadMore calls', () async {
      final secondPage = Completer<TaskPageModel>();
      repository.pageHandler = (request) => request.isCompleted == true
          ? Future.value(
              _page([], page: 1, totalItems: 0, totalPages: 0, hasNext: false),
            )
          : request.page == 2
          ? secondPage.future
          : Future.value(
              _page(
                ['a'],
                page: 1,
                totalItems: 2,
                totalPages: 2,
                hasNext: true,
              ),
            );
      final notifier = container.read(taskScreenTaskProvider.notifier);

      await notifier.loadInitial();
      final firstLoad = notifier.loadMore();
      final duplicateLoad = notifier.loadMore();

      expect(
        repository.requests.where((request) => request.page == 2),
        hasLength(1),
      );
      secondPage.complete(
        _page(['b'], page: 2, totalItems: 2, totalPages: 2, hasNext: false),
      );
      await Future.wait([firstLoad, duplicateLoad]);

      expect(
        container.read(taskScreenTaskProvider).items.map((task) => task.id),
        ['a', 'b'],
      );
    });

    test('does not request another page after the last page', () async {
      repository.pageHandler = (request) async => _page(
        request.isCompleted == true ? [] : ['a'],
        page: 1,
        totalItems: request.isCompleted == true ? 0 : 1,
        totalPages: request.isCompleted == true ? 0 : 1,
        hasNext: false,
      );
      final notifier = container.read(taskScreenTaskProvider.notifier);

      await notifier.loadInitial();
      await notifier.loadMore();

      expect(repository.requests, hasLength(2));
      expect(repository.requests.every((request) => request.page == 1), isTrue);
      expect(container.read(taskScreenTaskProvider).isLoadingMore, isFalse);
    });

    test(
      'keeps loaded items and retries the same page after loadMore failure',
      () async {
        repository.pageHandler = (request) async {
          if (request.isCompleted == true) {
            return _page(
              [],
              page: 1,
              totalItems: 0,
              totalPages: 0,
              hasNext: false,
            );
          }
          if (request.page == 1) {
            return _page(
              ['a'],
              page: 1,
              totalItems: 2,
              totalPages: 2,
              hasNext: true,
            );
          }
          if (repository.failNextPage) {
            repository.failNextPage = false;
            throw StateError('page failed');
          }
          return _page(
            ['b'],
            page: 2,
            totalItems: 2,
            totalPages: 2,
            hasNext: false,
          );
        };
        repository.failNextPage = true;
        final notifier = container.read(taskScreenTaskProvider.notifier);

        await notifier.loadInitial();
        await notifier.loadMore();
        var state = container.read(taskScreenTaskProvider);
        expect(state.items.map((task) => task.id), ['a']);
        expect(state.loadMoreErrorMessage, isNotNull);
        expect(state.hasNextPage, isTrue);

        await notifier.loadMore();
        state = container.read(taskScreenTaskProvider);
        expect(state.items.map((task) => task.id), ['a', 'b']);
        expect(state.loadMoreErrorMessage, isNull);
        expect(
          repository.requests.where((request) => request.page == 2),
          hasLength(2),
        );
      },
    );

    test(
      'query change resets pages and sends search and date filters',
      () async {
        repository.pageHandler = (request) async => _page(
          request.isCompleted == true ? [] : [request.search ?? 'all'],
          page: request.page,
          totalItems: request.isCompleted == true ? 0 : 1,
          totalPages: request.isCompleted == true ? 0 : 1,
          hasNext: false,
        );
        final notifier = container.read(taskScreenTaskProvider.notifier);

        await notifier.loadInitial();
        await notifier.loadMore();
        await notifier.loadInitial(
          search: 'báo cáo',
          dueFrom: '2026-11-01T00:00:00+07:00',
          dueBefore: '2026-12-01T00:00:00+07:00',
        );

        final state = container.read(taskScreenTaskProvider);
        final lastRequest = repository.requests.last;
        expect(state.items.single.id, 'báo cáo');
        expect(state.hasNextPage, isFalse);
        expect(lastRequest.page, 1);
        expect(lastRequest.search, 'báo cáo');
        expect(lastRequest.dueFrom, '2026-11-01T00:00:00+07:00');
        expect(lastRequest.dueBefore, '2026-12-01T00:00:00+07:00');
      },
    );

    test(
      'keeps incomplete tasks before completed tasks across the page boundary',
      () async {
        repository.pageHandler = (request) async {
          if (request.isCompleted == false) {
            return _page(
              request.page == 1 ? ['pending-1'] : ['pending-2'],
              page: request.page,
              totalItems: 2,
              totalPages: 2,
              hasNext: request.page == 1,
            );
          }
          return _page(
            ['completed-1'],
            page: 1,
            totalItems: 1,
            totalPages: 1,
            hasNext: false,
          );
        };
        final notifier = container.read(taskScreenTaskProvider.notifier);

        await notifier.loadInitial();
        expect(
          container.read(taskScreenTaskProvider).items.map((task) => task.id),
          ['pending-1'],
        );

        await notifier.loadMore();
        expect(
          container.read(taskScreenTaskProvider).items.map((task) => task.id),
          ['pending-1', 'pending-2'],
        );

        await notifier.loadMore();
        final state = container.read(taskScreenTaskProvider);
        expect(state.items.map((task) => task.id), [
          'pending-1',
          'pending-2',
          'completed-1',
        ]);
        expect(state.totalItems, 3);
        expect(state.hasNextPage, isFalse);
        expect(
          repository.requests
              .where((request) => request.isCompleted == true)
              .map((request) => request.page),
          [1],
        );
      },
    );
  });
}

TaskPageModel _page(
  List<String> ids, {
  required int page,
  required int totalItems,
  required int totalPages,
  required bool hasNext,
}) => TaskPageModel(
  items: ids
      .map((id) => _task(id, isCompleted: id.startsWith('completed')))
      .toList(),
  page: page,
  limit: 20,
  totalItems: totalItems,
  totalPages: totalPages,
  hasNextPage: hasNext,
);

TaskModel _task(String id, {bool isCompleted = false}) => TaskModel(
  id: id,
  title: id,
  description: '',
  dueDate: null,
  priority: TaskPriority.medium,
  category: 'Cá nhân',
  isCompleted: isCompleted,
);

final class _PageRequest {
  const _PageRequest({
    required this.page,
    required this.limit,
    required this.search,
    required this.isCompleted,
    required this.dueFrom,
    required this.dueBefore,
    required this.sort,
  });

  final int page;
  final int limit;
  final String? search;
  final bool? isCompleted;
  final String? dueFrom;
  final String? dueBefore;
  final String sort;
}

final class _FakeRepository implements TaskRepository {
  final requests = <_PageRequest>[];
  final responses = <TaskPageModel>[];
  Future<TaskPageModel> Function(_PageRequest request)? pageHandler;
  bool failNextPage = false;

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
    final request = _PageRequest(
      page: page,
      limit: limit,
      search: search,
      isCompleted: isCompleted,
      dueFrom: dueFrom,
      dueBefore: dueBefore,
      sort: sort,
    );
    requests.add(request);
    final handler = pageHandler;
    if (handler != null) return handler(request);
    return responses.removeAt(0);
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
