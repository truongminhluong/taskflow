import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:task_flow_v2/core/time/app_time_zone.dart';

final class NotificationInboxItem {
  const NotificationInboxItem({
    required this.taskId,
    required this.notificationId,
    required this.title,
    required this.body,
    required this.scheduledAt,
    this.readAt,
  });

  final String taskId;
  final int notificationId;
  final String title;
  final String body;
  final DateTime scheduledAt;
  final DateTime? readAt;

  bool get isRead => readAt != null;
  bool get isDelivered => !scheduledAt.isAfter(nowInAppTime());

  NotificationInboxItem copyWith({
    DateTime? readAt,
    bool clearReadAt = false,
  }) => NotificationInboxItem(
    taskId: taskId,
    notificationId: notificationId,
    title: title,
    body: body,
    scheduledAt: scheduledAt,
    readAt: clearReadAt ? null : readAt ?? this.readAt,
  );

  factory NotificationInboxItem.fromJson(Map<String, dynamic> json) =>
      NotificationInboxItem(
        taskId: json['taskId'] as String,
        notificationId: json['notificationId'] as int,
        title: json['title'] as String,
        body: json['body'] as String,
        scheduledAt: DateTime.parse(json['scheduledAt'] as String),
        readAt: json['readAt'] == null
            ? null
            : DateTime.parse(json['readAt'] as String),
      );

  Map<String, Object?> toJson() => {
    'taskId': taskId,
    'notificationId': notificationId,
    'title': title,
    'body': body,
    'scheduledAt': scheduledAt.toIso8601String(),
    'readAt': readAt?.toIso8601String(),
  };
}

final class NotificationInboxStore {
  NotificationInboxStore._();

  static final instance = NotificationInboxStore._();
  static const _key = 'notification_inbox_v1';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<List<NotificationInboxItem>> read() async {
    final value = await _storage.read(key: _key);
    if (value == null) return [];
    try {
      final decoded = jsonDecode(value);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map(
            (item) =>
                NotificationInboxItem.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList();
    } on FormatException {
      return [];
    } on TypeError {
      return [];
    }
  }

  Future<void> write(List<NotificationInboxItem> items) => _storage.write(
    key: _key,
    value: jsonEncode(items.map((item) => item.toJson()).toList()),
  );
}
