import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../core/time/app_time_zone.dart';

import '../../features/tasks/data/models/task_model.dart';
import 'notification_inbox_store.dart';
import 'task_reminder_policy.dart';

typedef TaskNotificationTapHandler = void Function(String taskId);
typedef TaskNotificationInboxChangedHandler = Future<void> Function();

abstract interface class TaskNotificationDriver {
  Future<void> initialize({TaskNotificationTapHandler? onTaskTap});

  Future<bool> hasPermission();

  Future<bool> requestPermission();

  Future<void> openNotificationSettings();

  Future<void> scheduleTaskReminder(TaskModel task);

  Future<void> cancelTaskReminder(String taskId);

  Future<void> cancelAllReminders();
}

abstract interface class TaskNotificationBadgePermissionDriver {
  Future<bool> hasBadgePermission();

  Future<bool> requestBadgePermission();
}

final class TaskNotificationService
    implements TaskNotificationDriver, TaskNotificationBadgePermissionDriver {
  TaskNotificationService._();

  static final instance = TaskNotificationService._();
  static const _badgeChannel = MethodChannel('task_flow/notification_badge');

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  Future<void>? _initialization;
  // Covers ID discovery, collision resolution, and the plugin mutation.
  Future<void> _mutationQueue = Future<void>.value();
  TaskNotificationTapHandler? _onTaskTap;
  TaskNotificationInboxChangedHandler? _inboxChangedHandler;

  void setInboxChangedHandler(TaskNotificationInboxChangedHandler handler) {
    _inboxChangedHandler = handler;
    _badgeChannel.setMethodCallHandler((call) async {
      if (call.method == 'notificationDelivered') {
        await _inboxChangedHandler?.call();
      }
    });
  }

  @override
  Future<void> initialize({TaskNotificationTapHandler? onTaskTap}) {
    if (onTaskTap != null) _onTaskTap = onTaskTap;
    if (_initialized) return Future<void>.value();

    final inFlight = _initialization;
    if (inFlight != null) return inFlight;

    final initialization = _initialize();
    _initialization = initialization;
    return initialization.catchError((Object error, StackTrace stackTrace) {
      _initialization = null;
      Error.throwWithStackTrace(error, stackTrace);
    });
  }

  Future<void> _initialize() async {
    initializeAppTimeZone();

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
        defaultPresentAlert: true,
        defaultPresentBadge: true,
        defaultPresentBanner: true,
        defaultPresentList: true,
        defaultPresentSound: true,
      ),
    );

    // On iOS this bool is the permission request result. Since permission
    // prompts are intentionally deferred, false is expected and does not
    // mean that the plugin failed to initialize.
    final initializationResult = await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: _handleNotificationResponse,
    );
    if (initializationResult == null ||
        (initializationResult == false &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      throw StateError(
        'Local notification plugin initialization returned '
        '$initializationResult on $defaultTargetPlatform.',
      );
    }

    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    final initialTaskId = launchDetails?.notificationResponse?.payload;
    if (launchDetails?.didNotificationLaunchApp == true &&
        initialTaskId != null &&
        initialTaskId.isNotEmpty) {
      unawaited(_handleTaskTap(initialTaskId));
    }

    _initialized = true;
  }

  void _handleNotificationResponse(NotificationResponse response) {
    final taskId = response.payload;
    if (taskId != null && taskId.isNotEmpty) {
      unawaited(_handleTaskTap(taskId));
    }
  }

  Future<void> _handleTaskTap(String taskId) async {
    await _markInboxItemRead(taskId);
    _onTaskTap?.call(taskId);
  }

  Future<List<NotificationInboxItem>> readInbox() =>
      NotificationInboxStore.instance.read();

  Future<void> markInboxItemRead(String taskId) => _markInboxItemRead(taskId);

  Future<void> markAllInboxItemsRead() async {
    await _serializeMutations(() async {
      final items = await NotificationInboxStore.instance.read();
      final now = nowInAppTime();
      await NotificationInboxStore.instance.write([
        for (final item in items)
          if (item.isDelivered)
            item.copyWith(readAt: item.readAt ?? now)
          else
            item,
      ]);
      await _reschedulePendingWithBadgeCounts();
      await _syncIconBadgeFromInboxInternal();
    });
  }

  Future<void> _markInboxItemRead(String taskId) async {
    await _serializeMutations(() async {
      final items = await NotificationInboxStore.instance.read();
      final now = nowInAppTime();
      await NotificationInboxStore.instance.write([
        for (final item in items)
          if (item.taskId == taskId && item.isDelivered)
            item.copyWith(readAt: item.readAt ?? now)
          else
            item,
      ]);
      await _reschedulePendingWithBadgeCounts();
      await _syncIconBadgeFromInboxInternal();
    });
  }

  Future<int> syncIconBadgeFromInbox() =>
      _serializeMutations(_syncIconBadgeFromInboxInternal);

  Future<int> _syncIconBadgeFromInboxInternal() async {
    final items = await NotificationInboxStore.instance.read();
    final unreadCount = items
        .where((item) => item.isDelivered && !item.isRead)
        .length;
    if (defaultTargetPlatform != TargetPlatform.iOS) return unreadCount;
    try {
      await _badgeChannel.invokeMethod<void>('setBadgeCount', unreadCount);
    } on PlatformException catch (error) {
      debugPrint('Không thể cập nhật badge thông báo: $error');
    } on MissingPluginException catch (error) {
      debugPrint('Badge thông báo chưa sẵn sàng: $error');
    }
    return unreadCount;
  }

  Future<void> _removeFutureInboxItem(String taskId) async {
    final items = await NotificationInboxStore.instance.read();
    await NotificationInboxStore.instance.write([
      for (final item in items)
        if (item.taskId != taskId || item.isDelivered) item,
    ]);
    await _reschedulePendingWithBadgeCounts();
  }

  Future<void> _reschedulePendingWithBadgeCounts() async {
    await initialize();
    final now = nowInAppTime();
    final items = await NotificationInboxStore.instance.read();
    final orderedPending =
        items.where((item) => item.scheduledAt.isAfter(now)).toList()..sort(
          (first, second) => first.scheduledAt.compareTo(second.scheduledAt),
        );
    var badgeCount = items
        .where((item) => !item.scheduledAt.isAfter(now) && !item.isRead)
        .length;

    for (final item in orderedPending) {
      badgeCount++;
      await _plugin.zonedSchedule(
        id: item.notificationId,
        title: item.title,
        body: item.body,
        scheduledDate: tz.TZDateTime.from(item.scheduledAt, appLocation),
        notificationDetails: NotificationDetails(
          android: const AndroidNotificationDetails(
            'task_reminders',
            'Nhắc việc',
            channelDescription: 'Nhắc bạn theo lịch đã đặt cho công việc.',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(
            badgeNumber: badgeCount,
            presentAlert: true,
            presentBanner: true,
            presentList: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: item.taskId,
      );
    }
  }

  @override
  Future<bool> hasPermission() async {
    await initialize();

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final status = await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.checkPermissions();
      return status?.isEnabled ?? false;
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.areNotificationsEnabled() ??
          false;
    }

    return false;
  }

  @override
  Future<bool> hasBadgePermission() async {
    await initialize();
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final status = await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.checkPermissions();
      return status?.isBadgeEnabled ?? false;
    }
    return defaultTargetPlatform == TargetPlatform.android;
  }

  @override
  Future<bool> requestBadgePermission() async {
    await initialize();
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: false, badge: true, sound: false);
      return hasBadgePermission();
    }
    return defaultTargetPlatform == TargetPlatform.android;
  }

  @override
  Future<bool> requestPermission() async {
    await initialize();

    if (defaultTargetPlatform == TargetPlatform.android) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.requestNotificationsPermission() ??
          false;
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >()
              ?.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
    }

    return false;
  }

  @override
  Future<void> openNotificationSettings() async {
    await initialize();
    await _plugin.openAppNotificationSettings();
  }

  @override
  Future<void> scheduleTaskReminder(TaskModel task) => _serializeMutations(
    () async {
      await initialize();

      if (task.id.isEmpty) {
        throw ArgumentError.value(task.id, 'task.id', 'Task ID không hợp lệ.');
      }

      final notificationId = await _prepareNotificationId(task.id);

      final notificationTime = TaskReminderPolicy.scheduledAt(
        task,
        now: nowInAppTime(),
      );
      if (notificationTime == null) {
        await _cancelTaskReminder(task.id);
        await _removeFutureInboxItemFromInbox(task.id);
        return;
      }

      await _plugin.zonedSchedule(
        id: notificationId,
        title: task.title,
        body: _reminderBody(task.reminderMinutesBefore!),
        scheduledDate: tz.TZDateTime.from(notificationTime, appLocation),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'task_reminders',
            'Nhắc việc',
            channelDescription: 'Nhắc bạn theo lịch đã đặt cho công việc.',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBanner: true,
            presentList: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: task.id,
      );

      final items = await NotificationInboxStore.instance.read();
      final previousItems = items.where((item) => item.taskId == task.id);
      final previous = previousItems.isEmpty ? null : previousItems.first;
      await NotificationInboxStore.instance.write([
        ...items.where((item) => item.taskId != task.id),
        NotificationInboxItem(
          taskId: task.id,
          notificationId: notificationId,
          title: task.title,
          body: _reminderBody(task.reminderMinutesBefore!),
          scheduledAt: notificationTime,
          readAt: previous?.scheduledAt == notificationTime
              ? previous?.readAt
              : null,
        ),
      ]);
    },
  );

  Future<void> _cancelTaskReminder(String taskId) async {
    final pending = await _plugin.pendingNotificationRequests();
    final active = await _plugin.getActiveNotifications();

    final taskIds = <int>{
      for (final item in pending)
        if (item.payload == taskId) item.id,
      for (final item in active)
        if (item.payload == taskId && item.id != null) item.id!,
    };

    final idsUsedByOtherTasks = <int>{
      for (final item in pending)
        if (item.payload != taskId) item.id,
      for (final item in active)
        if (item.payload != taskId && item.id != null) item.id!,
    };

    for (final id in taskIds.difference(idsUsedByOtherTasks)) {
      await _plugin.cancel(id: id);
    }
  }

  Future<void> _removeFutureInboxItemFromInbox(String taskId) async {
    final items = await NotificationInboxStore.instance.read();

    await NotificationInboxStore.instance.write([
      for (final item in items)
        if (item.taskId != taskId || item.isDelivered) item,
    ]);
  }

  String _reminderBody(int minutesBefore) => switch (minutesBefore) {
    0 => 'Công việc đến giờ nhắc.',
    5 => 'Còn 5 phút đến giờ nhắc.',
    10 => 'Còn 10 phút đến giờ nhắc.',
    15 => 'Còn 15 phút đến giờ nhắc.',
    30 => 'Còn 30 phút đến giờ nhắc.',
    60 => 'Còn 1 giờ đến giờ nhắc.',
    1440 => 'Còn 1 ngày đến giờ nhắc.',
    _ => 'Đã đến thời gian nhắc công việc.',
  };

  /// Stable, positive 31-bit ID derived from the MongoDB task ID.
  static int notificationIdFor(String taskId) {
    var hash = 0x811c9dc5;
    for (final unit in taskId.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash == 0 ? 1 : hash;
  }

  @visibleForTesting
  static int selectNotificationId(
    String taskId, {
    required Set<int> occupiedIds,
    Set<int> existingTaskIds = const {},
  }) {
    var candidate = existingTaskIds.isEmpty
        ? notificationIdFor(taskId)
        : existingTaskIds.first;
    while (occupiedIds.contains(candidate)) {
      candidate = candidate == 0x7fffffff ? 1 : candidate + 1;
    }
    return candidate;
  }

  @override
  Future<void> cancelTaskReminder(String taskId) =>
      _serializeMutations(() async {
        await initialize();
        if (taskId.isEmpty) return;

        final pending = await _plugin.pendingNotificationRequests();
        final active = await _plugin.getActiveNotifications();
        final taskIds = <int>{
          for (final item in pending)
            if (item.payload == taskId) item.id,
          for (final item in active)
            if (item.payload == taskId && item.id != null) item.id!,
        };
        final idsUsedByOtherTasks = <int>{
          for (final item in pending)
            if (item.payload != taskId) item.id,
          for (final item in active)
            if (item.payload != taskId && item.id != null) item.id!,
        };

        for (final id in taskIds.difference(idsUsedByOtherTasks)) {
          await _plugin.cancel(id: id);
        }
        await _removeFutureInboxItem(taskId);
      });

  @override
  Future<void> cancelAllReminders() => _serializeMutations(() async {
    await initialize();
    await _plugin.cancelAllPendingNotifications();
    final items = await NotificationInboxStore.instance.read();
    await NotificationInboxStore.instance.write(
      items.where((item) => item.isDelivered).toList(),
    );
  });

  Future<int> _prepareNotificationId(String taskId) async {
    final pending = await _plugin.pendingNotificationRequests();
    final active = await _plugin.getActiveNotifications();
    final existingTaskIds = <int>{
      for (final item in pending)
        if (item.payload == taskId) item.id,
      for (final item in active)
        if (item.payload == taskId && item.id != null) item.id!,
    };
    final occupiedIds = <int>{
      for (final item in pending)
        if (item.payload != taskId) item.id,
      for (final item in active)
        if (item.payload != taskId && item.id != null) item.id!,
    };

    final candidate = selectNotificationId(
      taskId,
      occupiedIds: occupiedIds,
      existingTaskIds: existingTaskIds,
    );

    // Remove prior copies (including active notifications) before replacing
    // the reminder. This also resolves any duplicates created by older builds.
    for (final id in existingTaskIds.difference(occupiedIds)) {
      await _plugin.cancel(id: id);
    }

    return candidate;
  }

  Future<T> _serializeMutations<T>(Future<T> Function() action) {
    final previous = _mutationQueue;
    final release = Completer<void>();
    _mutationQueue = release.future;

    return _runAfter(previous, release, action);
  }

  Future<T> _runAfter<T>(
    Future<void> previous,
    Completer<void> release,
    Future<T> Function() action,
  ) async {
    await previous;
    try {
      return await action();
    } finally {
      release.complete();
    }
  }
}
