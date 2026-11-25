import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:task_flow_v2/features/tasks/presentation/navigation/task_notification_router.dart';
import 'package:task_flow_v2/features/tasks/presentation/providers/notification_settings_provider.dart';
import 'package:task_flow_v2/features/tasks/presentation/providers/notification_inbox_provider.dart';
import 'package:task_flow_v2/features/tasks/presentation/providers/task_provider.dart';
import 'package:task_flow_v2/features/tasks/presentation/screens/calendar_screen.dart';
import 'package:task_flow_v2/features/tasks/presentation/screens/home_screen.dart';
import 'package:task_flow_v2/features/tasks/presentation/screens/profile_screen.dart';
import 'package:task_flow_v2/features/tasks/presentation/screens/task_form_screen.dart';
import 'package:task_flow_v2/features/tasks/presentation/screens/task_screen.dart';
import 'package:task_flow_v2/features/tasks/presentation/widgets/tasks/add_task_button.dart';
import 'package:task_flow_v2/features/tasks/presentation/widgets/common/app_svg_icon.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    TaskNotificationRouter.onNotificationOpened = () {
      unawaited(ref.read(notificationInboxProvider.notifier).refresh());
    };
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) TaskNotificationRouter.authenticatedShellReady();
    });
  }

  @override
  void dispose() {
    TaskNotificationRouter.onNotificationOpened = null;
    TaskNotificationRouter.authenticatedShellClosed();
    super.dispose();
  }

  void _openCreateTask() {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const TaskFormScreen()));
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(taskProvider.select((state) => state.notificationErrorMessage), (
      previous,
      message,
    ) {
      if (message == null || message == previous) return;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
        ref.read(taskProvider.notifier).clearNotificationError();
        ref.read(notificationSettingsProvider.notifier).refresh();
      });
    });

    final screens = [
      HomeScreen(
        onOpenTasks: () => setState(() => _selectedIndex = 1),
        onOpenCalendar: () => setState(() => _selectedIndex = 2),
        onOpenProfile: () => setState(() => _selectedIndex = 3),
        onCreateTask: _openCreateTask,
      ),
      TaskScreen(isActive: _selectedIndex == 1),
      CalendarScreen(isActive: _selectedIndex == 2),
      ProfileScreen(isActive: _selectedIndex == 3),
    ];

    return Scaffold(
      extendBody: true,
      body: SafeArea(
        top: true,
        bottom: false,
        child: IndexedStack(index: _selectedIndex, children: screens),
      ),

      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
          child: Container(
            height: 76,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface
                  .withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(36),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant
                    .withValues(alpha: 0.45),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                _buildNavItem(
                  assetName: 'dashboard-square-01',
                  label: 'Tổng quan',
                  index: 0,
                ),
                _buildNavItem(
                  assetName: 'task-01',
                  label: 'Công việc',
                  index: 1,
                ),
                SizedBox(
                  width: 64,
                  child: Center(
                    child: AddTaskButton(onPressed: _openCreateTask, size: 52),
                  ),
                ),
                _buildNavItem(
                  assetName: 'calendar-01',
                  label: 'Lịch',
                  index: 2,
                ),
                _buildNavItem(
                  assetName: 'user-circle',
                  label: 'Cá nhân',
                  index: 3,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required String assetName,
    required String label,
    required int index,
  }) {
    final isSelected = _selectedIndex == index;
    final color = isSelected
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurfaceVariant;

    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedIndex = index;
          });
        },
        child: SizedBox(
          height: 64,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppSvgIcon(name: assetName, size: 24, color: color),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              const SizedBox(height: 3),
              Container(
                width: isSelected ? 28 : 0,
                height: 3,
                decoration: BoxDecoration(
                  color: isSelected ? color : Colors.transparent,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
