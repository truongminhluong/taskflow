import 'package:flutter_test/flutter_test.dart';
import 'package:task_flow_v2/features/tasks/data/models/task_model.dart';
import 'package:task_flow_v2/features/tasks/data/models/task_page_model.dart';

void main() {
  group('TaskModel.fromJson', () {
    test('parses a task with every supported field', () {
      final task = TaskModel.fromJson(_taskJson());

      expect(task.id, 'task-1');
      expect(task.title, 'Hoàn thành báo cáo');
      expect(task.description, 'Kiểm tra số liệu cuối cùng.');
      expect(
        task.dueDate,
        DateTime.parse('2026-11-04T03:00:00.000Z').toLocal(),
      );
      expect(task.priority, TaskPriority.high);
      expect(task.category, 'Công việc');
      expect(task.isCompleted, isFalse);
      expect(task.reminderMinutesBefore, 15);
    });

    test('accepts null optional fields', () {
      final task = TaskModel.fromJson(
        _taskJson(
          description: null,
          dueDate: null,
          reminderMinutesBefore: null,
        ),
      );

      expect(task.description, isEmpty);
      expect(task.dueDate, isNull);
      expect(task.reminderMinutesBefore, isNull);
      expect(task.dueDateType, TaskDueDateType.none);
    });

    test('parses attachment metadata returned by the backend', () {
      final task = TaskModel.fromJson(
        _taskJson(
          attachments: [
            {
              'name': 'photo.png',
              'url': 'https://cdn.example.test/photo.png',
              'publicId': 'taskflow/users/user/photo',
              'mimeType': 'image/png',
              'sizeBytes': 123,
            },
          ],
        ),
      );

      expect(task.attachments, hasLength(1));
      expect(task.attachments.single.name, 'photo.png');
      expect(task.attachments.single.publicId, 'taskflow/users/user/photo');
      expect(task.attachments.single.mimeType, 'image/png');
      expect(task.attachments.single.sizeBytes, 123);
    });

    test('preserves legacy HEIC attachment metadata for existing tasks', () {
      final task = TaskModel.fromJson(
        _taskJson(
          attachments: [
            {
              'name': 'legacy.heic',
              'url': 'https://cdn.example.test/legacy.heic',
              'mimeType': 'image/heic',
              'sizeBytes': 6 * 1024 * 1024,
            },
          ],
        ),
      );

      expect(task.attachments.single.mimeType, 'image/heic');
      expect(task.attachments.single.sizeBytes, 6 * 1024 * 1024);
    });

    test('rejects malformed attachment metadata', () {
      expect(
        () => TaskModel.fromJson(
          _taskJson(attachments: [{'name': 'not-an-attachment'}]),
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('supports date-only contract without timezone conversion', () {
      final task = TaskModel.fromJson(
        _taskJson(
          dueDate: null,
          dueDateType: 'date',
          dueDateDate: '2026-12-31',
        ),
      );
      expect(task.dueDateType, TaskDueDateType.date);
      expect(task.dueDate, isNull);
      expect(task.dueDateDate, '2026-12-31');
      expect(task.toApiJson()['dueDate'], isNull);
      expect(task.toApiJson()['dueDateDate'], '2026-12-31');
    });

    test('infers legacy timestamp as dateTime, including midnight', () {
      final task = TaskModel.fromJson(
        _taskJson(dueDate: '2026-11-04T00:00:00.000Z'),
      );
      expect(task.dueDateType, TaskDueDateType.dateTime);
    });

    test('legacy dateTime omits date fields from unchanged update payload', () {
      final task = TaskModel.fromJson(
        _taskJson(dueDate: '2026-11-04T03:00:00.000Z'),
      );
      final payload = task
          .copyWith(title: 'Đổi tiêu đề')
          .toApiJson(includeDateTimeFields: false);
      expect(payload.containsKey('dueDateType'), isFalse);
      expect(payload.containsKey('dueDate'), isFalse);
      expect(payload.containsKey('dueDateDate'), isFalse);
      expect(payload.containsKey('timeZoneId'), isFalse);
      expect(payload['title'], 'Đổi tiêu đề');
    });

    test(
      'legacy dateTime sends the full contract after an intentional change',
      () {
        final task = TaskModel.fromJson(
          _taskJson(dueDate: '2026-11-04T03:00:00.000Z'),
        );
        final changed = task.copyWith(
          dueDate: DateTime.utc(2026, 12, 1, 4),
          timeZoneId: 'Asia/Ho_Chi_Minh',
          markDateTimeChanged: true,
        );
        expect(changed.legacyDateTime, isFalse);
        expect(changed.toApiJson()['dueDateType'], 'dateTime');
        expect(changed.toApiJson()['timeZoneId'], 'Asia/Ho_Chi_Minh');
      },
    );

    test(
      'rejects invalid explicit dueDateType and invalid timestamp timezone',
      () {
        expect(
          () => TaskModel.fromJson(_taskJson(dueDateType: 'bogus')),
          throwsA(isA<FormatException>()),
        );
        expect(
          () => TaskModel.fromJson(_taskJson(dueDate: '2026-11-04T03:00:00')),
          throwsA(isA<FormatException>()),
        );
        expect(
          () => TaskModel.fromJson(_taskJson(dueDate: '2026-02-30T03:00:00Z')),
          throwsA(isA<FormatException>()),
        );
        expect(
          () => TaskModel.fromJson(
            _taskJson(dueDate: '2026-11-04T03:00:00+25:00'),
          ),
          throwsA(isA<FormatException>()),
        );
      },
    );

    test('accepts every backend priority enum value', () {
      for (final priority in ['low', 'medium', 'high']) {
        final task = TaskModel.fromJson(_taskJson(priority: priority));
        expect(task.priority.name, priority);
      }
    });

    test('accepts legacy reminder offsets returned by the task API', () {
      for (final reminder in [5, 10, 30]) {
        final task = TaskModel.fromJson(
          _taskJson(reminderMinutesBefore: reminder),
        );
        expect(task.reminderMinutesBefore, reminder);
      }
    });

    test('rejects an unsupported priority enum', () {
      expect(
        () => TaskModel.fromJson(_taskJson(priority: 'urgent')),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects an invalid due date', () {
      expect(
        () => TaskModel.fromJson(_taskJson(dueDate: 'not-a-date')),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects a field with an invalid JSON type', () {
      expect(
        () => TaskModel.fromJson(_taskJson(isCompleted: 'false')),
        throwsA(isA<FormatException>()),
      );
    });
  });

  test('TaskPageModel identifies the malformed item and field', () {
    expect(
      () => TaskPageModel.fromApiResponse({
        'data': {
          'items': [
            _taskJson(id: 'valid-task'),
            _taskJson(id: 'invalid-task', reminderMinutesBefore: '15'),
          ],
          'pagination': {
            'page': 1,
            'limit': 20,
            'totalItems': 2,
            'totalPages': 1,
            'hasNextPage': false,
          },
        },
      }),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          allOf(
            contains('index 1'),
            contains('invalid-task'),
            contains('reminderMinutesBefore'),
          ),
        ),
      ),
    );
  });

  test('serializes all due date states and supports transitions', () {
    final base = TaskModel(
      id: 'task-1',
      title: 'T',
      description: '',
      dueDate: DateTime.utc(2026, 1, 2, 3),
      dueDateType: TaskDueDateType.dateTime,
      timeZoneId: 'Asia/Ho_Chi_Minh',
      priority: TaskPriority.medium,
      category: 'Cá nhân',
      isCompleted: false,
    );
    final date = base.copyWith(
      dueDateType: TaskDueDateType.date,
      dueDateDate: '2026-01-02',
    );
    expect(date.toApiJson()['dueDate'], isNull);
    expect(date.toApiJson()['timeZoneId'], isNull);
    expect(date.toApiJson()['dueDateDate'], '2026-01-02');
    final none = date.copyWith(dueDateType: TaskDueDateType.none);
    expect(none.toApiJson()['dueDateType'], 'none');
    expect(none.toApiJson()['dueDateDate'], isNull);
    expect(none.toApiJson()['dueDate'], isNull);
  });

  test('serializes and copies attachment metadata', () {
    const attachment = TaskAttachment(
      name: 'photo.webp',
      url: 'https://cdn.example.test/photo.webp',
      publicId: 'taskflow/users/user/photo',
      mimeType: 'image/webp',
      sizeBytes: 456,
    );
    final task = TaskModel(
      id: 'task-1',
      title: 'T',
      description: '',
      dueDate: null,
      priority: TaskPriority.medium,
      category: 'Cá nhân',
      isCompleted: false,
      attachments: const [attachment],
    );

    final payload = task.toApiJson();
    expect(payload['attachments'], [attachment.toJson()]);
    expect(task.copyWith(attachments: const []).attachments, isEmpty);
    expect(
      TaskModel.fromJson({
        ..._taskJson(),
        'attachments': payload['attachments'],
      }).attachments.single.toJson(),
      attachment.toJson(),
    );
  });
}

Map<String, dynamic> _taskJson({
  String id = 'task-1',
  String title = 'Hoàn thành báo cáo',
  Object? description = 'Kiểm tra số liệu cuối cùng.',
  Object? dueDate = '2026-11-04T03:00:00.000Z',
  Object? priority = 'high',
  Object? category = 'Công việc',
  Object? isCompleted = false,
  Object? reminderMinutesBefore = 15,
  Object? dueDateType,
  Object? dueDateDate,
  Object? timeZoneId,
  Object? attachments = const [],
}) => {
  '_id': id,
  'title': title,
  'description': description,
  'dueDate': dueDate,
  if (dueDateType != null) 'dueDateType': dueDateType,
  if (dueDateDate != null) 'dueDateDate': dueDateDate,
  if (timeZoneId != null) 'timeZoneId': timeZoneId,
  'priority': priority,
  'category': category,
  'isCompleted': isCompleted,
  'reminderMinutesBefore': reminderMinutesBefore,
  'attachments': attachments,
};
