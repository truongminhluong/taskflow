import 'dart:async';

import 'package:flutter_confetti/flutter_confetti.dart';
import 'package:flutter/material.dart';
import 'package:task_flow_v2/core/time/app_time_zone.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:task_flow_v2/core/theme/app_theme.dart';
import 'package:task_flow_v2/features/tasks/data/models/task_model.dart';
import 'package:task_flow_v2/features/tasks/presentation/providers/task_provider.dart';
import 'package:task_flow_v2/features/tasks/presentation/providers/notification_inbox_provider.dart';
import 'package:task_flow_v2/features/tasks/presentation/screens/task_details_screen.dart';
import 'package:task_flow_v2/features/tasks/presentation/widgets/tasks/home_progress_overview.dart';
import 'package:task_flow_v2/features/tasks/presentation/widgets/common/app_svg_icon.dart';
import 'package:task_flow_v2/features/tasks/presentation/widgets/common/section_heading.dart';
import 'package:task_flow_v2/features/tasks/presentation/widgets/tasks/task_card.dart';
import 'package:task_flow_v2/features/tasks/presentation/widgets/tasks/task_load_error_panel.dart';
import 'package:task_flow_v2/features/tasks/presentation/widgets/common/vietnamese_date.dart';

import '../providers/auth_provider.dart';
import '../widgets/common/task_flow_background.dart';
import '../widgets/tasks/taskflow_empty_illustration.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({
    required this.onOpenTasks,
    required this.onOpenCalendar,
    required this.onOpenProfile,
    required this.onCreateTask,
    super.key,
  });

  final VoidCallback onOpenTasks;
  final VoidCallback onOpenCalendar;
  final VoidCallback onOpenProfile;
  final VoidCallback onCreateTask;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  final Map<String, bool> _optimisticCompletion = {};
  final Set<String> _completionUpdatesInFlight = {};

  Future<void> _maybeShowFaceIdPrompt() async {
    final notifier = ref.read(authProvider.notifier);
    final userId = ref.read(authProvider).user?.id;

    if (userId == null) return;

    try {
      final shouldPrompt = await notifier.shouldPromptToEnableFaceId();

      if (!shouldPrompt ||
          !mounted ||
          ref.read(authProvider).user?.id != userId) {
        return;
      }

      final enableFaceId = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Bật đăng nhập bằng Face ID?'),
          content: const Text(
            'Bạn có thể dùng Face ID để đăng nhập nhanh trên thiết bị này.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Để sau'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Bật Face ID'),
            ),
          ],
        ),
      );

      if (!mounted || ref.read(authProvider).user?.id != userId) return;

      if (enableFaceId == true) {
        // Hàm notifier sẽ xác thực Face ID, lưu cài đặt và đánh dấu đã hỏi.
        final enabled = await notifier.setFaceIdEnabled(true);
        if (!mounted || !enabled) return;
      } else {
        // Giữ hành vi hiện tại: không hỏi lại sau khi hoãn hoặc đóng dialog.
        await notifier.markFaceIdPromptSeen();
      }

      if (!mounted || enableFaceId == null) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            enableFaceId
                ? 'Đã bật đăng nhập bằng Face ID.'
                : 'Bạn có thể bật Face ID sau.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chưa thể thiết lập Face ID.')),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    unawaited(ref.read(notificationInboxProvider.notifier).refresh());

    Future.microtask(() {
      if (!mounted) return;
      ref.read(taskProvider.notifier).loadOverview();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeShowFaceIdPrompt();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(ref.read(notificationInboxProvider.notifier).refresh());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = nowInAppTime();
    final taskState = ref.watch(taskProvider);
    final overview = taskState.overview;

    final greeting = switch (now.hour) {
      < 12 => 'Chào buổi sáng',
      < 17 => 'Chào buổi chiều',
      _ => 'Chào buổi tối',
    };

    final isInitialLoading = taskState.isOverviewLoading && overview == null;
    final hasInitialError =
        taskState.overviewErrorMessage != null && overview == null;

    final todayTasks = overview?.todayTasks ?? const [];
    final displayedTodayTasks = todayTasks
        .map(
          (task) => _optimisticCompletion.containsKey(task.id)
              ? task.copyWith(isCompleted: _optimisticCompletion[task.id])
              : task,
        )
        .toList(growable: false);
    final upcomingTasks = overview?.upcomingTasks ?? const [];
    final hasNoTodayTasks =
        !isInitialLoading && !hasInitialError && todayTasks.isEmpty;
    final totalToday = overview?.summary.total ?? 0;
    final completedToday = _optimisticCompletion.isEmpty
        ? overview?.summary.completed ?? 0
        : displayedTodayTasks.where((task) => task.isCompleted).length;
    final progress = totalToday == 0 ? 0.0 : completedToday / totalToday;

    final overviewMessage = switch ((isInitialLoading, hasInitialError)) {
      (true, _) => 'Đang tải tiến độ hôm nay.',
      (_, true) => 'Chưa tải được tiến độ hôm nay.',
      _ => null,
    };

    return TaskFlowBackground(
      child: SafeArea(
        bottom: false,
        child: ContentColumn(
          child: Column(
            children: [
              _HomeHeader(
                greeting: greeting,
                dateLabel: VietnameseDate.full(now),
              ),
              Expanded(
                child: CustomScrollView(
                  key: const PageStorageKey('home-scroll'),
                  slivers: [
                    SliverPadding(
                      padding: EdgeInsets.only(
                        top: hasNoTodayTasks ? AppSpace.md : AppSpace.lg,
                      ),
                      sliver: SliverToBoxAdapter(
                        child: hasNoTodayTasks
                            ? _FirstTaskWelcome(
                                onCreateTask: widget.onCreateTask,
                                hasUpcomingTasks: upcomingTasks.isNotEmpty,
                              )
                            : HomeProgressOverview(
                                completed: completedToday,
                                total: totalToday,
                                progress: progress,
                                statusMessage: overviewMessage,
                                onOpenTasks: widget.onOpenTasks,
                              ),
                      ),
                    ),
                    if (!hasNoTodayTasks)
                      SliverPadding(
                        padding: const EdgeInsets.only(top: AppSpace.xl),
                        sliver: SliverToBoxAdapter(
                          child: SectionHeading(
                            title: 'Việc hôm nay',
                            actionLabel: 'Tất cả công việc',
                            onAction: widget.onOpenTasks,
                          ),
                        ),
                      ),
                    if (isInitialLoading)
                      const SliverToBoxAdapter(child: _HomeLoadingState())
                    else if (hasInitialError)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.only(top: AppSpace.md),
                          child: TaskLoadErrorPanel(
                            message: taskState.overviewErrorMessage!,
                            onRetry: () {
                              ref.read(taskProvider.notifier).loadOverview();
                            },
                          ),
                        ),
                      )
                    else if (displayedTodayTasks.isNotEmpty)
                      SliverPadding(
                        padding: const EdgeInsets.only(top: AppSpace.md),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            final task = displayedTodayTasks[index];

                            return Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppSpace.sm,
                              ),
                              child: TaskCard(
                                task: task,
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) =>
                                          TaskDetailsScreen(taskId: task.id),
                                    ),
                                  );
                                },
                                onToggle: () =>
                                    unawaited(_toggleTodayTask(task)),
                                isToggleEnabled: !_completionUpdatesInFlight
                                    .contains(task.id),
                              ),
                            );
                          }, childCount: displayedTodayTasks.length),
                        ),
                      ),
                    if (!isInitialLoading &&
                        !hasInitialError &&
                        upcomingTasks.isNotEmpty) ...[
                      SliverPadding(
                        padding: const EdgeInsets.only(top: AppSpace.lg),
                        sliver: SliverToBoxAdapter(
                          child: SectionHeading(
                            title: hasNoTodayTasks
                                ? 'Công việc sắp tới'
                                : 'Sắp tới',
                            actionLabel: 'Xem lịch',
                            onAction: widget.onOpenCalendar,
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.only(top: AppSpace.sm),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final task = upcomingTasks[index];

                              return Padding(
                                padding: const EdgeInsets.only(
                                  bottom: AppSpace.sm,
                                ),
                                child: TaskCard(
                                  task: task,
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) =>
                                            TaskDetailsScreen(taskId: task.id),
                                      ),
                                    );
                                  },
                                  onToggle: () {
                                    // Giữ nguyên hành vi hiện tại của task sắp tới.
                                  },
                                ),
                              );
                            },
                            childCount: upcomingTasks.length > 3
                                ? 3
                                : upcomingTasks.length,
                          ),
                        ),
                      ),
                    ],
                    if (!isInitialLoading &&
                        !hasInitialError &&
                        todayTasks.isNotEmpty &&
                        upcomingTasks.isEmpty) ...[
                      SliverPadding(
                        padding: const EdgeInsets.only(top: AppSpace.lg),
                        sliver: SliverToBoxAdapter(
                          child: SectionHeading(
                            title: 'Sắp tới',
                            actionLabel: 'Xem lịch',
                            onAction: widget.onOpenCalendar,
                          ),
                        ),
                      ),
                      const SliverPadding(
                        padding: EdgeInsets.only(top: AppSpace.sm),
                        sliver: SliverToBoxAdapter(
                          child: _UpcomingEmptyPrompt(),
                        ),
                      ),
                    ],

                    const SliverToBoxAdapter(
                      child: SizedBox(height: AppSpace.xxl * 2),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggleTodayTask(TaskModel task) async {
    if (_completionUpdatesInFlight.contains(task.id)) return;

    final notifier = ref.read(taskProvider.notifier);
    final overviewBefore = ref.read(taskProvider).overview;
    final wasCompleted = task.isCompleted;
    setState(() {
      _optimisticCompletion[task.id] = !wasCompleted;
      _completionUpdatesInFlight.add(task.id);
    });

    final succeeded = await notifier.toggleTask(task.id, knownTask: task);
    if (!mounted) return;
    setState(() {
      _optimisticCompletion.remove(task.id);
      _completionUpdatesInFlight.remove(task.id);
    });

    if (!succeeded || !mounted || wasCompleted || overviewBefore == null) {
      return;
    }

    final overviewAfter = ref.read(taskProvider).overview;
    if (overviewAfter == null ||
        overviewAfter.date != overviewBefore.date ||
        overviewBefore.summary.total == 0 ||
        overviewBefore.summary.completed >= overviewBefore.summary.total ||
        overviewAfter.summary.completed < overviewAfter.summary.total) {
      return;
    }

    Confetti.launch(
      context,
      options: const ConfettiOptions(particleCount: 120, spread: 80, y: 0.6),
    );
  }
}

class _HomeHeader extends ConsumerWidget {
  const _HomeHeader({required this.greeting, required this.dateLabel});

  final String greeting;
  final String dateLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final inbox = ref.watch(notificationInboxProvider);

    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.lg, bottom: AppSpace.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpace.xxs),
                Text(
                  'Hôm nay',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: AppSpace.xs),
                Text(
                  dateLabel,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpace.xs),
          Semantics(
            button: true,
            label: 'Thông báo',
            child: Material(
              color: colors.surface,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => _showNotifications(context, ref),
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Center(
                        child: AppSvgIcon(
                          name: 'notification-01',
                          color: colors.onSurface,
                          size: 24,
                        ),
                      ),
                      if (inbox.unreadCount > 0)
                        Positioned(
                          top: 1,
                          right: 0,
                          child: Container(
                            constraints: const BoxConstraints(
                              minWidth: 18,
                              minHeight: 18,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              color: colors.error,
                              borderRadius: BorderRadius.circular(
                                AppRadius.pill,
                              ),
                              border: Border.all(
                                color: colors.surface,
                                width: 2,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              inbox.unreadCount > 99
                                  ? '99+'
                                  : '${inbox.unreadCount}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colors.onError,
                                fontWeight: FontWeight.w700,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showNotifications(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(notificationInboxProvider.notifier);
    unawaited(notifier.refresh());
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Consumer(
          builder: (sheetContentContext, ref, _) {
            final inbox = ref.watch(notificationInboxProvider);
            final items = inbox.deliveredItems;
            return SizedBox(
              height: MediaQuery.sizeOf(sheetContentContext).height * 0.65,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpace.lg,
                      AppSpace.xs,
                      AppSpace.md,
                      AppSpace.sm,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Thông báo',
                            style: Theme.of(sheetContentContext)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (inbox.unreadCount > 0)
                          TextButton(
                            onPressed: () => notifier.markAllRead(),
                            child: const Text('Đánh dấu đã đọc'),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: items.isEmpty
                        ? Center(
                            child: Text(
                              inbox.isLoading
                                  ? 'Đang tải thông báo…'
                                  : 'Chưa có thông báo mới',
                              style: Theme.of(sheetContentContext)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(
                                    color: Theme.of(sheetContentContext)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpace.md,
                              0,
                              AppSpace.md,
                              AppSpace.lg,
                            ),
                            itemCount: items.length,
                            separatorBuilder: (_, _) =>
                                const Divider(height: 1),
                            itemBuilder: (itemContext, index) {
                              final item = items[index];
                              return ListTile(
                                leading: AppSvgIcon(
                                  name: 'task-01',
                                  color: item.isRead
                                      ? Theme.of(itemContext)
                                            .colorScheme
                                            .onSurfaceVariant
                                      : Theme.of(itemContext)
                                            .colorScheme
                                            .primary,
                                  size: 22,
                                ),
                                title: Text(item.title),
                                subtitle: Text(item.body),
                                trailing: item.isRead
                                    ? null
                                    : Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: Theme.of(itemContext)
                                              .colorScheme
                                              .primary,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                onTap: () async {
                                  await notifier.markRead(item.taskId);
                                  if (!sheetContext.mounted) return;
                                  Navigator.pop(sheetContext);
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => TaskDetailsScreen(
                                        taskId: item.taskId,
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _FirstTaskWelcome extends StatelessWidget {
  const _FirstTaskWelcome({
    required this.onCreateTask,
    required this.hasUpcomingTasks,
  });

  final VoidCallback onCreateTask;
  final bool hasUpcomingTasks;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final illustrationWidth = constraints.maxWidth.clamp(0.0, 360.0);
            return TaskFlowEmptyIllustration(
              width: illustrationWidth,
              height: illustrationWidth * 310 / 360,
            );
          },
        ),
        const SizedBox(height: AppSpace.sm),
        Text(
          hasUpcomingTasks
              ? 'Hôm nay chưa có công việc nào'
              : 'Chưa có công việc nào',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            color: colors.onSurface,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: AppSpace.xs),
        Container(
          width: 80,
          height: 5,
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: .22),
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          alignment: Alignment.centerLeft,
          child: Container(
            width: 40,
            decoration: BoxDecoration(
              color: colors.primary,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
          ),
        ),
        const SizedBox(height: AppSpace.md),
        Text(
          hasUpcomingTasks
              ? 'Các công việc sắp tới của bạn được hiển thị bên dưới.'
              : 'Bắt đầu tạo công việc đầu tiên\nđể sắp xếp cuộc sống của bạn tốt hơn!',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: colors.onSurfaceVariant,
            height: 1.35,
          ),
        ),
        const SizedBox(height: AppSpace.lg),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: onCreateTask,
            icon: const Icon(Icons.add_rounded),
            label: Text(
              hasUpcomingTasks ? 'Tạo công việc' : 'Tạo công việc đầu tiên',
            ),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(58),
              shape: const StadiumBorder(),
              textStyle: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _UpcomingEmptyPrompt extends StatelessWidget {
  const _UpcomingEmptyPrompt();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      clipBehavior: Clip.antiAlias,
      color: isDark ? const Color(0xFF202B40) : Colors.white,
      elevation: isDark ? 0 : 1,
      shadowColor: colors.primary.withValues(alpha: .08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: .55)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
        child: Row(
          children: [
            SizedBox(
              width: 40,
              height: 48,
              child: Center(
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  alignment: Alignment.center,
                  child: AppSvgIcon(
                    name: 'calendar-01',
                    size: 21,
                    color: colors.primary,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.xs,
                  vertical: AppSpace.xxs,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Chưa có công việc sắp tới',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpace.xxs),
                    Text(
                      'Mở Lịch để lên kế hoạch trước.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CalendarDot extends StatelessWidget {
  const _CalendarDot({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

class _HomeLoadingState extends StatelessWidget {
  const _HomeLoadingState();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.xl),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: colors.primary,
            ),
          ),
          const SizedBox(width: AppSpace.sm),
          Text(
            'Đang tải công việc…',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
