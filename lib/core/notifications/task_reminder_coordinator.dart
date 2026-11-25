import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../features/tasks/data/models/task_model.dart';
import 'task_notification_service.dart';

abstract interface class NotificationSettingsStore {
  Future<bool> readEnabled();

  Future<void> writeEnabled(bool enabled);

  Future<bool> readInitialPermissionRequested();

  Future<void> writeInitialPermissionRequested(bool requested);
}

final class SecureNotificationSettingsStore
    implements NotificationSettingsStore {
  SecureNotificationSettingsStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _enabledKey = 'notifications_enabled';
  static const _initialPermissionRequestedKey =
      'notification_initial_permission_requested';

  final FlutterSecureStorage _storage;

  @override
  Future<bool> readEnabled() async =>
      await _storage.read(key: _enabledKey) == 'true';

  @override
  Future<void> writeEnabled(bool enabled) =>
      _storage.write(key: _enabledKey, value: enabled.toString());

  @override
  Future<bool> readInitialPermissionRequested() async =>
      await _storage.read(key: _initialPermissionRequestedKey) == 'true';

  @override
  Future<void> writeInitialPermissionRequested(bool requested) => _storage
      .write(key: _initialPermissionRequestedKey, value: requested.toString());
}

final class NotificationSettingsSnapshot {
  const NotificationSettingsSnapshot({
    required this.enabled,
    required this.permissionGranted,
    this.badgePermissionGranted = true,
    this.permissionRevoked = false,
  });

  final bool enabled;
  final bool permissionGranted;
  final bool badgePermissionGranted;
  final bool permissionRevoked;
}

final class NotificationPermissionException implements Exception {
  const NotificationPermissionException();

  @override
  String toString() => 'Quyền thông báo của hệ điều hành chưa được cấp.';
}

abstract interface class TaskReminderCoordinatorContract {
  Future<NotificationSettingsSnapshot> readSettings();

  Future<NotificationSettingsSnapshot?> requestInitialPermissionIfNeeded();

  Future<NotificationSettingsSnapshot> enable();

  Future<NotificationSettingsSnapshot> enableForTasks(List<TaskModel> tasks);

  Future<void> disable();

  Future<void> syncTask(TaskModel task);

  Future<void> syncTasks(List<TaskModel> tasks, {int? restoreRevision});

  int captureRestoreRevision();

  Future<void> cancelTask(String taskId);

  Future<void> openSettings();
}

/// Coordinates the app-level preference with OS permission and task schedules.
final class TaskReminderCoordinator implements TaskReminderCoordinatorContract {
  TaskReminderCoordinator({required this.driver, required this.settingsStore});

  final TaskNotificationDriver driver;
  final NotificationSettingsStore settingsStore;
  // Protects whole coordinator workflows, especially cancel-all + restoration.
  // Keep nested work in private helpers to avoid re-entering this queue.
  Future<void> _mutationQueue = Future<void>.value();
  int _mutationRevision = 0;

  @override
  int captureRestoreRevision() => _mutationRevision;

  @override
  Future<NotificationSettingsSnapshot> readSettings() =>
      _serializeMutations(() async {
        await driver.initialize();
        final permissionGranted = await driver.hasPermission();
        final badgePermissionGranted = await _hasBadgePermission();
        final enabled = await settingsStore.readEnabled();
        var permissionRevoked = false;

        if (enabled && !permissionGranted) {
          await driver.cancelAllReminders();
          permissionRevoked = true;
        }

        return NotificationSettingsSnapshot(
          enabled: enabled,
          permissionGranted: permissionGranted,
          badgePermissionGranted: badgePermissionGranted,
          permissionRevoked: permissionRevoked,
        );
      });

  /// Requests iOS permission once per installation and records the app choice
  /// only after the operating system reports permission granted.
  @override
  Future<NotificationSettingsSnapshot?> requestInitialPermissionIfNeeded() =>
      _serializeMutations(() async {
        if (defaultTargetPlatform != TargetPlatform.iOS) return null;

        await driver.initialize();
        if (await settingsStore.readInitialPermissionRequested()) return null;

        var permissionGranted = await driver.hasPermission();
        if (!permissionGranted) {
          permissionGranted = await driver.requestPermission();
        }
        var badgePermissionGranted = await _hasBadgePermission();
        if (permissionGranted && !badgePermissionGranted) {
          await _requestBadgePermission();
          badgePermissionGranted = await _hasBadgePermission();
        }
        await settingsStore.writeInitialPermissionRequested(true);

        final enabled = await settingsStore.readEnabled();
        if (permissionGranted) {
          await settingsStore.writeEnabled(true);
          return NotificationSettingsSnapshot(
            enabled: true,
            permissionGranted: true,
            badgePermissionGranted: badgePermissionGranted,
          );
        }

        if (enabled) await driver.cancelAllReminders();
        return NotificationSettingsSnapshot(
          enabled: enabled,
          permissionGranted: false,
          permissionRevoked: enabled,
        );
      });

  /// Records the app's opt-in and confirms OS permission without scheduling.
  /// Call [syncTasks] afterward to restore reminders without delaying the UI.
  @override
  Future<NotificationSettingsSnapshot> enable() {
    _mutationRevision++;
    return _enable();
  }

  @override
  Future<NotificationSettingsSnapshot> enableForTasks(List<TaskModel> tasks) {
    _mutationRevision++;
    return _enable(tasks: tasks);
  }

  Future<NotificationSettingsSnapshot> _enable({List<TaskModel>? tasks}) =>
      _serializeMutations(() async {
        try {
          await driver.initialize();
          await settingsStore.writeEnabled(true);
          var permissionGranted = await driver.hasPermission();
          if (!permissionGranted) {
            permissionGranted = await driver.requestPermission();
          }

          if (!permissionGranted) {
            await driver.cancelAllReminders();
            return const NotificationSettingsSnapshot(
              enabled: true,
              permissionGranted: false,
              permissionRevoked: true,
            );
          }

          var badgePermissionGranted = await _hasBadgePermission();
          if (!badgePermissionGranted) {
            await _requestBadgePermission();
            badgePermissionGranted = await _hasBadgePermission();
          }

          if (tasks != null) {
            for (final task in tasks) {
              await driver.scheduleTaskReminder(task);
            }
          }

          await settingsStore.writeEnabled(true);
          return NotificationSettingsSnapshot(
            enabled: true,
            permissionGranted: true,
            badgePermissionGranted: badgePermissionGranted,
          );
        } catch (error, stackTrace) {
          try {
            await _turnOffAndCancel();
          } catch (cleanupError, cleanupStackTrace) {
            debugPrint('Notification rollback failed: $cleanupError');
            debugPrintStack(stackTrace: cleanupStackTrace);
          }
          Error.throwWithStackTrace(error, stackTrace);
        }
      });

  Future<bool> _hasBadgePermission() =>
      driver is TaskNotificationBadgePermissionDriver
      ? (driver as TaskNotificationBadgePermissionDriver).hasBadgePermission()
      : Future<bool>.value(true);

  Future<bool> _requestBadgePermission() async {
    if (driver is! TaskNotificationBadgePermissionDriver) return true;
    try {
      return await (driver as TaskNotificationBadgePermissionDriver)
          .requestBadgePermission();
    } catch (error, stackTrace) {
      debugPrint('Badge permission request failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }

  @override
  Future<void> disable() {
    _mutationRevision++;
    return _serializeMutations(() async {
      await driver.initialize();
      await driver.cancelAllReminders();
      await settingsStore.writeEnabled(false);
    });
  }

  /// Reconciles schedules after a successful task API operation.
  @override
  Future<void> syncTask(TaskModel task) {
    _mutationRevision++;
    return _serializeMutations(() async {
      await driver.initialize();

      if (!await settingsStore.readEnabled()) {
        await driver.cancelTaskReminder(task.id);
        return;
      }

      if (!await driver.hasPermission()) {
        await driver.cancelAllReminders();
        throw const NotificationPermissionException();
      }

      await driver.scheduleTaskReminder(task);
    });
  }

  /// Restores schedules after loading tasks from the backend on app startup.
  @override
  Future<void> syncTasks(
    List<TaskModel> tasks, {
    int? restoreRevision,
  }) => _serializeMutations(() async {
    await driver.initialize();
    if (!await settingsStore.readEnabled()) return;

    if (!await driver.hasPermission()) {
      await driver.cancelAllReminders();
      throw const NotificationPermissionException();
    }

    // A mutation may have completed while the full-list request was still
    // being fetched. In that case this snapshot is stale; do not cancel the
    // current schedules and rebuild them from stale data.
    if (restoreRevision != null && restoreRevision != _mutationRevision) {
      return;
    }

    try {
      // The backend is the source of truth. Remove stale schedules (for
      // example, tasks deleted on another device) before restoring this list.
      await driver.cancelAllReminders();
      for (final task in tasks) {
        await driver.scheduleTaskReminder(task);
      }
    } catch (error, stackTrace) {
      try {
        await _turnOffAndCancel();
      } catch (cleanupError, cleanupStackTrace) {
        debugPrint('Notification restore rollback failed: $cleanupError');
        debugPrintStack(stackTrace: cleanupStackTrace);
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  });

  @override
  Future<void> cancelTask(String taskId) {
    _mutationRevision++;
    return _serializeMutations(() async {
      await driver.initialize();
      await driver.cancelTaskReminder(taskId);
    });
  }

  @override
  Future<void> openSettings() async {
    await driver.openNotificationSettings();
  }

  Future<void> _turnOffAndCancel() async {
    try {
      await driver.cancelAllReminders();
    } finally {
      await settingsStore.writeEnabled(false);
    }
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
