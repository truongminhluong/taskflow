import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/notifications/task_notification_service.dart';
import 'features/tasks/presentation/navigation/task_notification_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const ProviderScope(child: TaskFlowApp()));
  unawaited(_initializeNotifications());
}

Future<void> _initializeNotifications() async {
  try {
    await TaskNotificationService.instance.initialize(
      onTaskTap: TaskNotificationRouter.openTask,
    );
  } catch (error, stackTrace) {
    debugPrint('Khởi tạo thông báo thất bại: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
}
