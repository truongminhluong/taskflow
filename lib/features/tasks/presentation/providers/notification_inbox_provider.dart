import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:task_flow_v2/core/notifications/notification_inbox_store.dart';
import 'package:task_flow_v2/core/notifications/task_notification_service.dart';

final notificationInboxProvider =
    NotifierProvider<NotificationInboxNotifier, NotificationInboxState>(
      NotificationInboxNotifier.new,
    );

final class NotificationInboxState {
  const NotificationInboxState({this.items = const [], this.isLoading = true});

  final List<NotificationInboxItem> items;
  final bool isLoading;

  List<NotificationInboxItem> get deliveredItems =>
      items.where((item) => item.isDelivered).toList(growable: false)..sort(
        (first, second) => second.scheduledAt.compareTo(first.scheduledAt),
      );

  int get unreadCount =>
      items.where((item) => item.isDelivered && !item.isRead).length;
}

final class NotificationInboxNotifier extends Notifier<NotificationInboxState> {
  final TaskNotificationService _service = TaskNotificationService.instance;

  @override
  NotificationInboxState build() {
    _service.setInboxChangedHandler(() => refresh());
    return const NotificationInboxState();
  }

  Future<void> refresh({bool syncBadge = true}) async {
    try {
      final items = await _service.readInbox();
      state = NotificationInboxState(items: items, isLoading: false);
      if (syncBadge) await _service.syncIconBadgeFromInbox();
    } catch (error, stackTrace) {
      debugPrint('Không thể đọc hộp thư thông báo: $error');
      debugPrintStack(stackTrace: stackTrace);
      state = NotificationInboxState(items: state.items, isLoading: false);
    }
  }

  Future<void> markRead(String taskId) async {
    await _service.markInboxItemRead(taskId);
    await refresh(syncBadge: false);
  }

  Future<void> markAllRead() async {
    await _service.markAllInboxItemsRead();
    await refresh(syncBadge: false);
  }
}
