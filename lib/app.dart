import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:task_flow_v2/features/tasks/presentation/navigation/task_notification_router.dart';
import 'package:task_flow_v2/features/tasks/presentation/screens/auth_gate.dart';

import 'core/theme/app_theme.dart';
import 'features/tasks/presentation/providers/theme_mode_provider.dart';

class TaskFlowApp extends ConsumerWidget {
  const TaskFlowApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      navigatorKey: TaskNotificationRouter.navigatorKey,
      title: 'TaskFlow',
      debugShowCheckedModeBanner: false,
      supportedLocales: const [Locale('vi'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      home: const AuthGate(),
    );
  }
}
