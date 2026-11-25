import 'package:task_flow_v2/core/time/app_time_zone.dart';

enum TaskPriority { low, medium, high }

enum TaskDueDateType { none, date, dateTime }

enum TaskRepeatFrequency { daily, weekly, monthly }

enum TaskRepeatEndType { never, onDate, afterOccurrences }

final class TaskAttachment {
  const TaskAttachment({
    required this.name,
    required this.url,
    required this.mimeType,
    this.publicId,
    this.sizeBytes,
  });

  final String name;
  final String url;
  final String? publicId;
  final String mimeType;
  final int? sizeBytes;

  factory TaskAttachment.fromJson(Object? raw) {
    if (raw is! Map) {
      throw const FormatException('Task attachment must be an object.');
    }

    final json = Map<String, dynamic>.from(raw);
    final name = json['name'];
    final url = json['url'];
    final publicId = json['publicId'];
    final mimeType = json['mimeType'];
    final sizeBytes = json['sizeBytes'];

    if (name is! String || name.trim().isEmpty || name.length > 255) {
      throw const FormatException('Task attachment has an invalid name.');
    }
    if (url is! String || url.trim().isEmpty || url.length > 2048) {
      throw const FormatException('Task attachment has an invalid URL.');
    }
    if (publicId != null &&
        (publicId is! String || publicId.isEmpty || publicId.length > 512)) {
      throw const FormatException('Task attachment has an invalid publicId.');
    }
    if (!const {
      'image/jpeg',
      'image/png',
      'image/webp',
      'image/heic',
    }.contains(mimeType)) {
      throw const FormatException('Task attachment has an unsupported type.');
    }
    if (sizeBytes != null &&
        (sizeBytes is! int || sizeBytes < 0)) {
      throw const FormatException('Task attachment has an invalid size.');
    }

    return TaskAttachment(
      name: name,
      url: url,
      publicId: publicId as String?,
      mimeType: mimeType as String,
      sizeBytes: sizeBytes as int?,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'url': url,
    if (publicId != null) 'publicId': publicId,
    'mimeType': mimeType,
    if (sizeBytes != null) 'sizeBytes': sizeBytes,
  };
}

final class TaskRepeatConfig {
  const TaskRepeatConfig({
    required this.enabled,
    this.frequency,
    this.interval = 1,
    this.weekdays = const [],
    this.anchorDate,
    this.anchorDay,
    this.endType = TaskRepeatEndType.never,
    this.endDate,
    this.maxOccurrences,
    this.timeZone = appTimeZone,
  });

  const TaskRepeatConfig.disabled()
    : enabled = false,
      frequency = null,
      interval = 1,
      weekdays = const [],
      anchorDate = null,
      anchorDay = null,
      endType = TaskRepeatEndType.never,
      endDate = null,
      maxOccurrences = null,
      timeZone = appTimeZone;

  final bool enabled;
  final TaskRepeatFrequency? frequency;
  final int interval;
  final List<int> weekdays;
  final String? anchorDate;
  final int? anchorDay;
  final TaskRepeatEndType endType;
  final String? endDate;
  final int? maxOccurrences;
  final String timeZone;

  factory TaskRepeatConfig.fromJson(Object? raw) {
    if (raw is! Map) return const TaskRepeatConfig.disabled();
    final json = Map<String, dynamic>.from(raw);
    final enabled = json['enabled'] == true;
    if (!enabled) return const TaskRepeatConfig.disabled();

    final frequency = TaskRepeatFrequency.values.where(
      (value) => value.name == json['frequency'],
    );
    final endType = TaskRepeatEndType.values.where(
      (value) => value.name == json['endType'],
    );
    final rawWeekdays = json['weekdays'];

    return TaskRepeatConfig(
      enabled: true,
      frequency: frequency.isEmpty ? null : frequency.first,
      interval: json['interval'] is int ? json['interval'] as int : 1,
      weekdays: rawWeekdays is List
          ? rawWeekdays.whereType<int>().toList(growable: false)
          : const [],
      anchorDate: json['anchorDate'] as String?,
      anchorDay: json['anchorDay'] as int?,
      endType: endType.isEmpty ? TaskRepeatEndType.never : endType.first,
      endDate: json['endDate'] as String?,
      maxOccurrences: json['maxOccurrences'] as int?,
      timeZone: json['timeZone'] as String? ?? appTimeZone,
    );
  }

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    if (enabled) ...{
      'frequency': frequency?.name,
      'interval': interval,
      'weekdays': weekdays,
      'anchorDate': anchorDate,
      'anchorDay': anchorDay,
      'endType': endType.name,
      'endDate': endDate,
      'maxOccurrences': maxOccurrences,
      'timeZone': timeZone,
    },
  };

  TaskRepeatConfig copyWith({
    bool? enabled,
    TaskRepeatFrequency? frequency,
    int? interval,
    List<int>? weekdays,
    String? anchorDate,
    int? anchorDay,
    TaskRepeatEndType? endType,
    String? endDate,
    int? maxOccurrences,
    String? timeZone,
  }) => TaskRepeatConfig(
    enabled: enabled ?? this.enabled,
    frequency: frequency ?? this.frequency,
    interval: interval ?? this.interval,
    weekdays: weekdays ?? this.weekdays,
    anchorDate: anchorDate ?? this.anchorDate,
    anchorDay: anchorDay ?? this.anchorDay,
    endType: endType ?? this.endType,
    endDate: endDate ?? this.endDate,
    maxOccurrences: maxOccurrences ?? this.maxOccurrences,
    timeZone: timeZone ?? this.timeZone,
  );

  String get label {
    if (!enabled) return 'Không lặp lại';
    final frequencyLabel = switch (frequency) {
      TaskRepeatFrequency.daily =>
        interval == 1 ? 'Hằng ngày' : 'Mỗi $interval ngày',
      TaskRepeatFrequency.weekly =>
        interval == 1 ? 'Hằng tuần' : 'Mỗi $interval tuần',
      TaskRepeatFrequency.monthly =>
        interval == 1 ? 'Hằng tháng' : 'Mỗi $interval tháng',
      null => 'Không lặp lại',
    };
    if (frequency == TaskRepeatFrequency.weekly && weekdays.isNotEmpty) {
      return '$frequencyLabel · ${weekdays.map(_weekdayLabel).join(', ')}';
    }
    return frequencyLabel;
  }
}

String _weekdayLabel(int weekday) => switch (weekday) {
  0 => 'CN',
  1 => 'T2',
  2 => 'T3',
  3 => 'T4',
  4 => 'T5',
  5 => 'T6',
  6 => 'T7',
  _ => '?',
};

final class TaskModel {
  const TaskModel({
    required this.id,
    required this.title,
    required this.description,
    required this.dueDate,
    TaskDueDateType? dueDateType,
    this.dueDateDate,
    this.timeZoneId,
    this.legacyDateTime = false,
    required this.priority,
    required this.category,
    required this.isCompleted,
    this.reminderMinutesBefore,
    this.recurrenceId,
    this.occurrenceIndex,
    this.repeat = const TaskRepeatConfig.disabled(),
    this.attachments = const [],
  }) : dueDateType =
           dueDateType ??
           (dueDate == null ? TaskDueDateType.none : TaskDueDateType.dateTime);

  final String id;
  final String title;
  final String description;
  final DateTime? dueDate;
  final TaskDueDateType dueDateType;
  final String? dueDateDate;
  final String? timeZoneId;

  /// True when the server response omitted dueDateType for a timestamp task.
  final bool legacyDateTime;
  final TaskPriority priority;
  final String category;
  final bool isCompleted;
  final String? recurrenceId;
  final int? occurrenceIndex;
  final TaskRepeatConfig repeat;
  final List<TaskAttachment> attachments;

  /// null: không nhắc; 0: đúng giờ; 15/60/1440: số phút trước hạn.
  final int? reminderMinutesBefore;

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    final rawId = json['_id'] ?? json['id'];
    final rawTitle = json['title'];
    final rawDescription = json['description'] ?? '';
    final rawDueDate = json['dueDate'];
    final rawDueDateType = json['dueDateType'];
    final rawDueDateDate = json['dueDateDate'];
    final rawTimeZoneId = json['timeZoneId'];
    final rawPriority = json['priority'] ?? TaskPriority.medium.name;
    final rawCategory = json['category'] ?? 'Cá nhân';
    final rawIsCompleted = json['isCompleted'] ?? false;
    final rawReminder = json['reminderMinutesBefore'];
    final rawAttachments = json['attachments'] ?? const [];

    const allowedReminderMinutes = {0, 5, 10, 15, 30, 60, 1440};

    _requireNonEmptyString(rawId, '_id/id');
    _requireString(rawTitle, 'title');
    _requireString(rawDescription, 'description');
    _requireNullableString(rawDueDate, 'dueDate');
    _requireNullableString(rawDueDateDate, 'dueDateDate');
    _requireNullableString(rawTimeZoneId, 'timeZoneId');
    _requireString(rawPriority, 'priority');
    _requireString(rawCategory, 'category');
    _requireBool(rawIsCompleted, 'isCompleted');
    _requireReminderMinutes(rawReminder, allowedReminderMinutes);
    if (rawAttachments is! List || rawAttachments.length > 5) {
      throw const FormatException(
        'Task field "attachments" must contain at most five items.',
      );
    }

    final dueDate = rawDueDate == null
        ? null
        : _parseIsoTimestamp(rawDueDate as String);

    final dueDateType = _parseDueDateType(rawDueDateType, rawDueDate);
    _validateDueDateContract(
      dueDateType: dueDateType,
      dueDate: dueDate,
      dueDateDate: rawDueDateDate,
      timeZoneId: rawTimeZoneId,
    );

    final priority = TaskPriority.values.where(
      (value) => value.name == rawPriority,
    );

    if (rawDueDate != null && dueDate == null) {
      throw const FormatException(
        'Task field "dueDate" must be a valid ISO-8601 date string.',
      );
    }

    if (priority.isEmpty) {
      throw FormatException(
        'Task field "priority" has unsupported value "$rawPriority". '
        'Expected low, medium, or high.',
      );
    }

    return TaskModel(
      id: rawId as String,
      title: rawTitle as String,
      description: rawDescription,
      dueDate: dueDate,
      dueDateType: dueDateType,
      dueDateDate: rawDueDateDate as String?,
      timeZoneId: rawTimeZoneId as String?,
      legacyDateTime: rawDueDateType == null && rawDueDate != null,
      priority: priority.first,
      category: rawCategory as String,
      isCompleted: rawIsCompleted as bool,
      reminderMinutesBefore: rawReminder as int?,
      recurrenceId: json['recurrenceId'] is String
          ? json['recurrenceId'] as String
          : null,
      occurrenceIndex: json['occurrenceIndex'] is int
          ? json['occurrenceIndex'] as int
          : null,
      repeat: TaskRepeatConfig.fromJson(json['repeat']),
      attachments: rawAttachments
          .map(TaskAttachment.fromJson)
          .toList(growable: false),
    );
  }

  Map<String, dynamic> toApiJson({
    bool includeRepeat = true,
    bool includeDateTimeFields = true,
  }) => {
    'title': title,
    'description': description,
    if (includeDateTimeFields) ...{
      'dueDateType': dueDateType.name,
      'dueDate': dueDateType == TaskDueDateType.dateTime
          ? dueDate?.toUtc().toIso8601String()
          : null,
      'dueDateDate': dueDateType == TaskDueDateType.date ? dueDateDate : null,
      'timeZoneId': dueDateType == TaskDueDateType.dateTime ? timeZoneId : null,
    },
    'priority': priority.name,
    'category': category,
    'isCompleted': isCompleted,
    'reminderMinutesBefore': reminderMinutesBefore,
    'attachments': attachments.map((attachment) => attachment.toJson()).toList(),
    if (includeRepeat) 'repeat': repeat.toJson(),
  };

  Map<String, dynamic> toJson() => {'_id': id, ...toApiJson()};

  TaskModel copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? dueDate,
    bool clearDueDate = false,
    TaskDueDateType? dueDateType,
    String? dueDateDate,
    bool clearDueDateDate = false,
    String? timeZoneId,
    bool clearTimeZoneId = false,
    bool markDateTimeChanged = false,
    TaskPriority? priority,
    String? category,
    bool? isCompleted,
    int? reminderMinutesBefore,
    bool clearReminderMinutesBefore = false,
    String? recurrenceId,
    int? occurrenceIndex,
    TaskRepeatConfig? repeat,
    List<TaskAttachment>? attachments,
  }) {
    final nextType = dueDateType ?? this.dueDateType;
    return TaskModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      dueDate:
          nextType == TaskDueDateType.date || nextType == TaskDueDateType.none
          ? null
          : clearDueDate
          ? null
          : dueDate ?? this.dueDate,
      dueDateType: nextType,
      dueDateDate: nextType == TaskDueDateType.date
          ? (clearDueDateDate ? null : dueDateDate ?? this.dueDateDate)
          : null,
      timeZoneId: nextType == TaskDueDateType.dateTime
          ? (clearTimeZoneId ? null : timeZoneId ?? this.timeZoneId)
          : null,
      legacyDateTime: markDateTimeChanged ? false : legacyDateTime,
      priority: priority ?? this.priority,
      category: category ?? this.category,
      isCompleted: isCompleted ?? this.isCompleted,
      reminderMinutesBefore: clearReminderMinutesBefore
          ? null
          : reminderMinutesBefore ?? this.reminderMinutesBefore,
      recurrenceId: recurrenceId ?? this.recurrenceId,
      occurrenceIndex: occurrenceIndex ?? this.occurrenceIndex,
      repeat: repeat ?? this.repeat,
      attachments: attachments ?? this.attachments,
    );
  }
}

TaskDueDateType _parseDueDateType(Object? rawType, Object? rawDueDate) {
  if (rawType == null) {
    return rawDueDate == null ? TaskDueDateType.none : TaskDueDateType.dateTime;
  }
  if (rawType is! String) {
    throw const FormatException(
      'Task field "dueDateType" must be one of none, date, or dateTime.',
    );
  }
  for (final value in TaskDueDateType.values) {
    if (value.name == rawType) return value;
  }
  throw FormatException(
    'Task field "dueDateType" has unsupported value "$rawType".',
  );
}

DateTime _parseIsoTimestamp(String value) {
  final match = RegExp(
    r'^([0-9]{4})-([0-9]{2})-([0-9]{2})T([0-9]{2}):([0-9]{2}):([0-9]{2})(?:\.([0-9]{1,6}))?(Z|[+-][0-9]{2}:?[0-9]{2})$',
  ).firstMatch(value);
  if (match == null)
    throw const FormatException(
      'Task field "dueDate" must be an ISO-8601 timestamp with timezone.',
    );
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final hour = int.parse(match.group(4)!);
  final minute = int.parse(match.group(5)!);
  final second = int.parse(match.group(6)!);
  final fraction = (match.group(7) ?? '').padRight(6, '0');
  final microsecond = fraction.isEmpty ? 0 : int.parse(fraction);
  final zone = match.group(8)!;
  if (zone != 'Z') {
    final digits = zone.substring(1).replaceAll(':', '');
    if (int.parse(digits.substring(0, 2)) > 23 ||
        int.parse(digits.substring(2)) > 59) {
      throw const FormatException(
        'Task field "dueDate" has an invalid timezone offset.',
      );
    }
  }
  final parsed = DateTime.parse(value);
  final check = DateTime.utc(
    year,
    month,
    day,
    hour,
    minute,
    second,
    microsecond ~/ 1000,
    microsecond % 1000,
  );
  if (check.year != year ||
      check.month != month ||
      check.day != day ||
      check.hour != hour ||
      check.minute != minute ||
      check.second != second) {
    throw const FormatException(
      'Task field "dueDate" contains an invalid calendar date or time.',
    );
  }
  return utcToAppTime(parsed);
}

void _validateDueDateContract({
  required TaskDueDateType dueDateType,
  required DateTime? dueDate,
  required String? dueDateDate,
  required String? timeZoneId,
}) {
  if (dueDateType == TaskDueDateType.none &&
      (dueDate != null || dueDateDate != null || timeZoneId != null))
    throw const FormatException(
      'Task date/time fields are inconsistent with dueDateType none.',
    );
  if (dueDateType == TaskDueDateType.date &&
      (dueDate != null || timeZoneId != null || !_isValidDateOnly(dueDateDate)))
    throw const FormatException(
      'Task date/time fields are inconsistent with dueDateType date.',
    );
  if (dueDateType == TaskDueDateType.dateTime &&
      (dueDate == null || dueDateDate != null))
    throw const FormatException(
      'Task date/time fields are inconsistent with dueDateType dateTime.',
    );
}

bool _isValidDateOnly(String? value) {
  if (value == null || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value))
    return false;
  final parts = value.split('-').map(int.parse).toList();
  final date = DateTime.utc(parts[0], parts[1], parts[2]);
  return date.year == parts[0] &&
      date.month == parts[1] &&
      date.day == parts[2];
}

Never _invalidTaskField({
  required String field,
  required Object? actual,
  required String expected,
}) {
  final actualType = actual == null ? 'null' : actual.runtimeType.toString();
  throw FormatException(
    'Task field "$field" has invalid type or value. '
    'Expected $expected; received $actualType.',
  );
}

void _requireNonEmptyString(Object? value, String field) {
  if (value is! String || value.isEmpty) {
    _invalidTaskField(
      field: field,
      actual: value,
      expected: 'a non-empty String',
    );
  }
}

void _requireString(Object? value, String field) {
  if (value is! String) {
    _invalidTaskField(field: field, actual: value, expected: 'a String');
  }
}

void _requireNullableString(Object? value, String field) {
  if (value != null && value is! String) {
    _invalidTaskField(
      field: field,
      actual: value,
      expected: 'a String or null',
    );
  }
}

void _requireBool(Object? value, String field) {
  if (value is! bool) {
    _invalidTaskField(field: field, actual: value, expected: 'a bool');
  }
}

void _requireReminderMinutes(Object? value, Set<int> allowedValues) {
  if (value != null && (value is! int || !allowedValues.contains(value))) {
    _invalidTaskField(
      field: 'reminderMinutesBefore',
      actual: value,
      expected: 'one of ${allowedValues.join(', ')} or null',
    );
  }
}
