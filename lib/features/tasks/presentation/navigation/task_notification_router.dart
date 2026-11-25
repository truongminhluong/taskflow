import 'package:flutter/material.dart';
import 'package:task_flow_v2/features/tasks/presentation/screens/task_details_screen.dart';

abstract final class TaskNotificationRouter {
  static final navigatorKey = GlobalKey<NavigatorState>();
  static String? _pendingTaskId;
  static bool _authenticatedShellReady = false;
  static VoidCallback? onNotificationOpened;

  static void openTask(String taskId) {
    if (taskId.isEmpty) return;

    onNotificationOpened?.call();

    final navigator = navigatorKey.currentState;
    if (navigator == null || !_authenticatedShellReady) {
      _pendingTaskId = taskId;
      return;
    }

    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => TaskDetailsScreen(taskId: taskId),
      ),
    );
  }

  static void openPendingTask() {
    final taskId = _pendingTaskId;
    if (taskId == null || navigatorKey.currentState == null) return;

    _pendingTaskId = null;
    openTask(taskId);
  }

  static void authenticatedShellReady() {
    _authenticatedShellReady = true;
    openPendingTask();
  }

  static void authenticatedShellClosed() {
    _authenticatedShellReady = false;
  }
}
