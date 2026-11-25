import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task_flow_v2/core/network/api_client.dart';
import 'package:task_flow_v2/features/tasks/data/datasources/task_remote_data_source.dart';
import 'package:task_flow_v2/features/tasks/data/repositories/task_repository_impl.dart';

void main() {
  test('fetches one task by ID from the detail endpoint', () async {
    final adapter = _FakeAdapter(
      (options) async => {
        'message': 'Lấy thông tin công việc thành công.',
        'data': _taskJson('task-42'),
      },
    );

    final task = await _dataSource(adapter).getTaskById('task-42');

    expect(task.id, 'task-42');
    expect(adapter.requests.single.path, '/tasks/task-42');
    expect(adapter.requests.single.method, 'GET');
  });

  test('parses a task page and sends all supplied query parameters', () async {
    final adapter = _FakeAdapter(
      (options) async => _response(
        items: [_taskJson('task-1')],
        page: 2,
        limit: 20,
        totalItems: 25,
        totalPages: 2,
        hasNextPage: false,
      ),
    );
    final dataSource = _dataSource(adapter);

    final result = await dataSource.getTaskPage(
      page: 2,
      limit: 20,
      search: '  báo cáo  ',
      isCompleted: false,
      dueFrom: '2026-11-01T00:00:00+07:00',
      dueBefore: '2026-12-01T00:00:00+07:00',
      sort: 'dueDateAsc',
    );

    expect(result.items.single.id, 'task-1');
    expect(result.page, 2);
    expect(result.limit, 20);
    expect(result.totalItems, 25);
    expect(result.totalPages, 2);
    expect(result.hasNextPage, isFalse);
    expect(adapter.requests.single.queryParameters, {
      'page': 2,
      'limit': 20,
      'sort': 'dueDateAsc',
      'search': 'báo cáo',
      'isCompleted': false,
      'dueFrom': '2026-11-01T00:00:00+07:00',
      'dueBefore': '2026-12-01T00:00:00+07:00',
    });
  });

  test(
    'getTasks walks all pages so Home and Calendar keep a complete list',
    () async {
      final adapter = _FakeAdapter((options) async {
        final page = options.queryParameters['page'] as int;
        return _response(
          items: [_taskJson('task-$page')],
          page: page,
          limit: 50,
          totalItems: 51,
          totalPages: 2,
          hasNextPage: page == 1,
        );
      });

      final tasks = await _dataSource(adapter).getTasks();

      expect(tasks.map((task) => task.id), ['task-1', 'task-2']);
      expect(
        adapter.requests.map((request) => request.queryParameters['page']),
        [1, 2],
      );
      expect(
        adapter.requests.every(
          (request) => request.queryParameters['limit'] == 50,
        ),
        isTrue,
      );
    },
  );

  test(
    'concurrent repository getTasks calls share one pagination sequence',
    () async {
      final pageOne = Completer<Map<String, Object?>>();
      final adapter = _FakeAdapter((options) async {
        final page = options.queryParameters['page'] as int;
        if (page == 1) return pageOne.future;
        return _response(
          items: [_taskJson('task-2')],
          page: 2,
          limit: 50,
          totalItems: 2,
          totalPages: 2,
          hasNextPage: false,
        );
      });
      final repository = TaskRepositoryImpl(
        remoteDataSource: _dataSource(adapter),
      );

      final first = repository.getTasks();
      final second = repository.getTasks();
      await _waitUntil(() => adapter.requests.length == 1);
      expect(adapter.requests.length, 1);

      pageOne.complete(
        _response(
          items: [_taskJson('task-1')],
          page: 1,
          limit: 50,
          totalItems: 2,
          totalPages: 2,
          hasNextPage: true,
        ),
      );

      expect((await first).map((task) => task.id), ['task-1', 'task-2']);
      expect((await second).map((task) => task.id), ['task-1', 'task-2']);
      expect(
        adapter.requests.map((request) => request.queryParameters['page']),
        [1, 2],
      );
    },
  );

  test(
    'failed repository getTasks is cleared so a later retry can succeed',
    () async {
      var attempt = 0;
      final adapter = _FakeAdapter((options) async {
        attempt++;
        if (attempt == 1) throw StateError('page failed');
        return _response(
          items: [_taskJson('retry-task')],
          page: 1,
          limit: 50,
          totalItems: 1,
          totalPages: 1,
          hasNextPage: false,
        );
      });
      final repository = TaskRepositoryImpl(
        remoteDataSource: _dataSource(adapter),
      );

      await expectLater(repository.getTasks(), throwsA(isA<DioException>()));
      final tasks = await repository.getTasks();

      expect(tasks.single.id, 'retry-task');
      expect(adapter.requests, hasLength(2));
    },
  );

  test(
    'mid-pagination failure never returns partial tasks and can be retried',
    () async {
      var shouldFailPageThree = true;
      final adapter = _FakeAdapter((options) async {
        final page = options.queryParameters['page'] as int;
        if (page == 3 && shouldFailPageThree) {
          throw StateError('page 3 failed');
        }
        return _response(
          items: [_taskJson('task-$page')],
          page: page,
          limit: 50,
          totalItems: 3,
          totalPages: 3,
          hasNextPage: page < 3,
        );
      });
      final repository = TaskRepositoryImpl(
        remoteDataSource: _dataSource(adapter),
      );

      await expectLater(repository.getTasks(), throwsA(isA<DioException>()));
      expect(
        adapter.requests.map((request) => request.queryParameters['page']),
        [1, 2, 3],
      );

      shouldFailPageThree = false;
      final tasks = await repository.getTasks();
      expect(tasks.map((task) => task.id), ['task-1', 'task-2', 'task-3']);
    },
  );
}

Future<void> _waitUntil(bool Function() condition) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    if (condition()) return;
    await Future<void>.delayed(Duration.zero);
  }
  expect(condition(), isTrue);
}

TaskRemoteDataSource _dataSource(_FakeAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'https://taskflow.test/api'))
    ..httpClientAdapter = adapter;
  final apiClient = ApiClient(dio: dio, storage: const FlutterSecureStorage());
  dio.interceptors.clear();
  return TaskRemoteDataSource(apiClient: apiClient);
}

Map<String, Object?> _response({
  required List<Map<String, Object?>> items,
  required int page,
  required int limit,
  required int totalItems,
  required int totalPages,
  required bool hasNextPage,
}) => {
  'message': 'Lấy danh sách công việc thành công.',
  'data': {
    'items': items,
    'pagination': {
      'page': page,
      'limit': limit,
      'totalItems': totalItems,
      'totalPages': totalPages,
      'hasNextPage': hasNextPage,
    },
  },
};

Map<String, Object?> _taskJson(String id) => {
  '_id': id,
  'title': id,
  'description': '',
  'dueDate': null,
  'priority': 'medium',
  'category': 'Cá nhân',
  'isCompleted': false,
};

final class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.respond);

  final Future<Map<String, Object?>> Function(RequestOptions options) respond;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final response = await respond(options);
    return ResponseBody.fromString(
      jsonEncode(response),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
