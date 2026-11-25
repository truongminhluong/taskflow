import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:task_flow_v2/core/notifications/task_reminder_coordinator.dart';

import '../state/notification_settings_state.dart';
import 'task_provider.dart';
import 'task_reminder_coordinator_provider.dart';

final notificationSettingsProvider =
    NotifierProvider<NotificationSettingsNotifier, NotificationSettingsState>(
      NotificationSettingsNotifier.new,
    );

class NotificationSettingsNotifier extends Notifier<NotificationSettingsState> {
  @override
  NotificationSettingsState build() {
    Future.microtask(_initialize);
    return const NotificationSettingsState(isLoading: true);
  }

  int _stateRevision = 0;

  Future<void> _initialize() async {
    await refresh();
    await _requestInitialPermissionIfNeeded();
    if (state.enabled && state.permissionGranted) {
      unawaited(_restoreReminders(_stateRevision));
    }
  }

  Future<void> refresh() async {
    if (state.isUpdating) return;

    final isInitialLoad = state.isLoading;
    final revision = ++_stateRevision;
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final coordinator = ref.read(taskReminderCoordinatorProvider);
      final settings = await coordinator.readSettings();

      if (revision != _stateRevision) return;

      state = state.copyWith(
        isLoading: false,
        enabled: settings.enabled,
        permissionGranted: settings.permissionGranted,
        badgePermissionGranted: settings.badgePermissionGranted,
        requiresSettingsHelp:
            settings.permissionRevoked ||
            (settings.enabled && !settings.badgePermissionGranted),
        errorMessage: settings.permissionRevoked
            ? 'Quyền thông báo đã bị tắt trong Cài đặt thiết bị.'
            : settings.enabled && !settings.badgePermissionGranted
            ? 'Bật “Huy hiệu” tại Cài đặt iPhone > Thông báo > Task Flow V2 để hiện số chưa đọc.'
            : null,
        clearError:
            !settings.permissionRevoked &&
            (!settings.enabled || settings.badgePermissionGranted),
      );

      // Show the saved switch state as soon as OS settings are known. Fetching
      // tasks and rebuilding every reminder can take much longer, so restore
      // schedules without keeping the Profile switch in its loading state.
      if (!isInitialLoad && settings.enabled && settings.permissionGranted) {
        unawaited(_restoreReminders(revision));
      }
    } catch (error, stackTrace) {
      if (revision != _stateRevision) return;
      state = state.copyWith(
        isLoading: false,
        enabled: state.enabled,
        errorMessage: 'Không thể kiểm tra cài đặt thông báo.',
      );
      // ignore: avoid_print
      print('Read notification settings failed: $error\n$stackTrace');
    }
  }

  Future<void> _restoreReminders(int stateRevision) async {
    final coordinator = ref.read(taskReminderCoordinatorProvider);
    final restoreRevision = coordinator.captureRestoreRevision();

    try {
      final tasks = await ref.read(taskRepositoryProvider).getTasks();
      await coordinator.syncTasks(tasks, restoreRevision: restoreRevision);
    } catch (error, stackTrace) {
      _logRestoreFailure(error, stackTrace);
      if (stateRevision != _stateRevision) return;

      NotificationSettingsSnapshot? settings;
      try {
        settings = await coordinator.readSettings();
      } catch (readError, readStackTrace) {
        _logRestoreFailure(readError, readStackTrace);
      }
      if (stateRevision != _stateRevision) return;

      state = state.copyWith(
        enabled: settings?.enabled,
        permissionGranted: settings?.permissionGranted,
        badgePermissionGranted: settings?.badgePermissionGranted,
        requiresSettingsHelp: settings == null
            ? null
            : settings.permissionRevoked ||
                  (settings.enabled && !settings.badgePermissionGranted),
        errorMessage:
            state.errorMessage ??
            'Không tải được công việc để khôi phục nhắc việc.',
      );
    }
  }

  Future<void> setEnabled(bool enabled) async {
    if (state.isUpdating || state.isLoading) return;

    final revision = ++_stateRevision;
    final previousEnabled = state.enabled;
    state = state.copyWith(isUpdating: true, clearError: true);

    try {
      final coordinator = ref.read(taskReminderCoordinatorProvider);

      if (!enabled) {
        await coordinator.disable();
        state = state.copyWith(
          isUpdating: false,
          enabled: false,
          clearError: true,
          requiresSettingsHelp: false,
        );
        return;
      }

      final settings = await coordinator.enable();
      if (revision != _stateRevision) return;
      if (!settings.permissionGranted) {
        state = state.copyWith(
          isUpdating: false,
          enabled: settings.enabled,
          permissionGranted: false,
          requiresSettingsHelp: true,
          errorMessage: 'TaskFlow chưa được cấp quyền thông báo. Hãy bật quyền trong Cài đặt thiết bị.',
        );
        return;
      }

      state = state.copyWith(
        isUpdating: false,
        enabled: settings.enabled,
        permissionGranted: true,
        badgePermissionGranted: settings.badgePermissionGranted,
        requiresSettingsHelp: !settings.badgePermissionGranted,
        errorMessage: settings.badgePermissionGranted ? null : 'Bật “Huy hiệu” tại Cài đặt iPhone > Thông báo > Task Flow V2 để hiện số chưa đọc.',
        clearError: settings.badgePermissionGranted,
      );
      await _restoreReminders(revision);
    } catch (error, stackTrace) {
      if (revision != _stateRevision) return;
      state = state.copyWith(
        isUpdating: false,
        enabled: previousEnabled,
        errorMessage: error is NotificationPermissionException
            ? 'Quyền thông báo chưa được cấp. Hãy bật quyền trong Cài đặt thiết bị.'
            : error is StateError &&
                  error.message == 'Không tải được danh sách công việc.'
            ? 'Không tải được công việc. Kiểm tra mạng rồi thử bật lại.'
            : enabled
            ? 'Không thể bật thông báo. Hãy kiểm tra quyền và thử lại.'
            : 'Không thể tắt thông báo. Hãy thử lại.',
        requiresSettingsHelp: error is NotificationPermissionException,
      );
      // ignore: avoid_print
      print('Update notification setting failed: $error\n$stackTrace');
    }
  }

  Future<void> _requestInitialPermissionIfNeeded() async {
    final revision = ++_stateRevision;
    state = state.copyWith(isUpdating: true);

    try {
      final settings = await ref
          .read(taskReminderCoordinatorProvider)
          .requestInitialPermissionIfNeeded();
      if (revision != _stateRevision) return;

      if (settings == null) {
        state = state.copyWith(isUpdating: false);
        return;
      }

      if (revision != _stateRevision) return;
      state = state.copyWith(
        isUpdating: false,
        enabled: settings.enabled,
        permissionGranted: settings.permissionGranted,
        badgePermissionGranted: settings.badgePermissionGranted,
        requiresSettingsHelp:
            !settings.permissionGranted || !settings.badgePermissionGranted,
        errorMessage: !settings.permissionGranted
            ? 'TaskFlow chưa được cấp quyền thông báo. Hãy bật quyền trong Cài đặt thiết bị.'
            : !settings.badgePermissionGranted
            ? 'Bật “Huy hiệu” tại Cài đặt iPhone > Thông báo > Task Flow V2 để hiện số chưa đọc.'
            : null,
        clearError:
            settings.permissionGranted && settings.badgePermissionGranted,
      );
    } catch (error, stackTrace) {
      if (revision != _stateRevision) return;
      state = state.copyWith(
        isUpdating: false,
        errorMessage: 'Không thể yêu cầu quyền thông báo lần đầu.',
      );
      // ignore: avoid_print
      print(
        'Initial notification permission request failed: $error\n$stackTrace',
      );
    }
  }

  void _logRestoreFailure(Object error, StackTrace stackTrace) {
    // ignore: avoid_print
    print('Restore task reminders failed: $error\n$stackTrace');
  }

  Future<void> openSettings() async {
    try {
      await ref.read(taskReminderCoordinatorProvider).openSettings();
    } catch (error, stackTrace) {
      state = state.copyWith(
        errorMessage:
            'Không mở được Cài đặt. Hãy mở Cài đặt thiết bị thủ công.',
      );
      // ignore: avoid_print
      print('Open notification settings failed: $error\n$stackTrace');
    }
  }
}
