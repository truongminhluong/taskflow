import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:task_flow_v2/core/theme/app_theme.dart';
import 'package:task_flow_v2/features/tasks/data/models/task_model.dart';
import 'package:task_flow_v2/features/tasks/presentation/providers/task_provider.dart';
import 'package:task_flow_v2/features/tasks/presentation/providers/task_screen_task_provider.dart';
import 'package:task_flow_v2/features/tasks/presentation/screens/task_form_screen.dart';
import 'package:task_flow_v2/features/tasks/presentation/widgets/tasks/priority_badge.dart';
import 'package:task_flow_v2/features/tasks/presentation/widgets/common/app_svg_icon.dart';
import 'package:task_flow_v2/features/tasks/presentation/widgets/tasks/task_category_label.dart';
import 'package:task_flow_v2/features/tasks/presentation/widgets/common/vietnamese_date.dart';
import 'package:task_flow_v2/features/tasks/presentation/widgets/common/task_due_date_display.dart';
import 'package:task_flow_v2/features/tasks/presentation/widgets/common/app_confirm_dialog.dart';
import 'package:task_flow_v2/features/tasks/presentation/providers/task_details_provider.dart';

import '../widgets/common/task_flow_background.dart';

class TaskDetailsScreen extends ConsumerStatefulWidget {
  const TaskDetailsScreen({required this.taskId, super.key});

  final String taskId;

  @override
  ConsumerState<TaskDetailsScreen> createState() => _TaskDetailsScreenState();
}

class _TaskDetailsScreenState extends ConsumerState<TaskDetailsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;

      final cachedTask = ref
          .read(taskProvider)
          .tasks
          .where((item) => item.id == widget.taskId);

      final notifier = ref.read(taskDetailsProvider.notifier);

      if (cachedTask.isNotEmpty) {
        notifier.setTask(cachedTask.first);
      } else {
        notifier.loadTask(widget.taskId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(taskProvider);
    final detailsState = ref.watch(taskDetailsProvider);

    final cachedTask = store.tasks.where((item) => item.id == widget.taskId);
    final task =
        detailsState.task ?? (cachedTask.isEmpty ? null : cachedTask.first);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết công việc'),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          if (task != null)
            IconButton(
              tooltip: 'Sửa công việc',
              onPressed: () {
                Navigator.of(context)
                    .push(
                      MaterialPageRoute<void>(
                        builder: (_) => TaskFormScreen(task: task),
                      ),
                    )
                    .then((_) {
                      if (!mounted) return;
                      ref
                          .read(taskDetailsProvider.notifier)
                          .loadTask(widget.taskId, forceRefresh: true);

                      ref.read(taskScreenTaskProvider.notifier).reload();
                    });
              },
              icon: AppSvgIcon(
                name: 'edit-01',
                size: 20,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
        ],
      ),
      body: TaskFlowBackground(
        child: task == null
            ? Center(
                child: detailsState.isLoading
                    ? const CircularProgressIndicator()
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            detailsState.isNotFound
                                ? 'Công việc này không còn tồn tại.'
                                : detailsState.errorMessage ??
                                      'Công việc này không còn tồn tại.',
                            textAlign: TextAlign.center,
                          ),
                          if (detailsState.errorMessage != null) ...[
                            const SizedBox(height: 12),
                            TextButton.icon(
                              onPressed: () => ref
                                  .read(taskDetailsProvider.notifier)
                                  .loadTask(widget.taskId, forceRefresh: true),
                              icon: const Icon(Icons.refresh),
                              label: const Text('Thử lại'),
                            ),
                          ],
                        ],
                      ),
              )
            : _TaskDetailsBody(
                task: task,
                onToggle: () async {
                  final success = await ref
                      .read(taskProvider.notifier)
                      .toggleTask(task.id, knownTask: task);
                  if (success && mounted) {
                    ref
                        .read(taskDetailsProvider.notifier)
                        .loadTask(widget.taskId, forceRefresh: true);
                    ref.read(taskScreenTaskProvider.notifier).reload();
                  }
                },
                onDelete: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      title: const Text('Xóa công việc?'),
                      content: const Text(
                        'Bạn có chắc muốn xóa công việc này không?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(false),
                          child: const Text('Hủy'),
                        ),
                        FilledButton(
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(true),
                          child: const Text('Xóa'),
                        ),
                      ],
                    ),
                  );

                  if (confirmed != true || !context.mounted) return;

                  final messenger = ScaffoldMessenger.of(context);
                  final success = await ref
                      .read(taskProvider.notifier)
                      .deleteTask(task.id, allowMissingFromSharedState: true);

                  if (!context.mounted) return;

                  if (success) {
                    ref.read(taskScreenTaskProvider.notifier).reload();
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Đã xóa công việc.')),
                    );
                    Navigator.of(context).pop();
                  } else {
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Không thể xóa công việc. Vui lòng thử lại.',
                        ),
                      ),
                    );
                  }
                },
                onStopRepeat: task.repeat.enabled && task.recurrenceId != null
                    ? () async {
                        final confirmed = await AppConfirmDialog.show(
                          context: context,
                          title: 'Dừng chuỗi lặp?',
                          message: 'Các lần lặp chưa hoàn thành sẽ không được tạo thêm.',
                          confirmLabel: 'Dừng lặp',
                          destructive: true,
                        );
                        if (confirmed != true || !context.mounted) return;
                        final messenger = ScaffoldMessenger.of(context);
                        final success = await ref
                            .read(taskProvider.notifier)
                            .stopRecurringSeries(task.recurrenceId!);
                        if (!mounted) return;
                        if (success) {
                          await ref
                              .read(taskDetailsProvider.notifier)
                              .loadTask(widget.taskId, forceRefresh: true);
                          ref.read(taskScreenTaskProvider.notifier).reload();
                          messenger.showSnackBar(
                            const SnackBar(content: Text('Đã dừng chuỗi lặp.')),
                          );
                        }
                      }
                    : null,
              ),
      ),
    );
  }
}

class _TaskDetailsBody extends StatelessWidget {
  const _TaskDetailsBody({
    required this.task,
    required this.onToggle,
    required this.onDelete,
    this.onStopRepeat,
  });

  final TaskModel task;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback? onStopRepeat;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: ListView(
            padding: const EdgeInsets.all(AppSpace.lg),
            children: [
              Row(
                children: [
                  PriorityBadge(priority: task.priority),
                  const SizedBox(width: AppSpace.sm),
                  Text(
                    taskCategoryLabel(task.category),
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: colors.onSurfaceVariant),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.lg),
              Text(
                task.title,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: AppSpace.lg),
              Card(
                child: ListTile(
                  leading: AppSvgIcon(
                    name: 'calendar-01',
                    color: colors.primary,
                  ),
                  title: const Text('Ngày nhắc'),
                  subtitle: Text(
                    taskCalendarDate(task) == null
                        ? 'Chưa đặt ngày nhắc'
                        : VietnameseDate.numeric(taskCalendarDate(task)!),
                  ),
                ),
              ),
              if (task.dueDateType == TaskDueDateType.dateTime &&
                  task.dueDate != null) ...[
                const SizedBox(height: AppSpace.sm),
                Card(
                  child: ListTile(
                    leading: AppSvgIcon(
                      name: 'clock-01',
                      color: colors.primary,
                    ),
                    title: const Text('Giờ nhắc'),
                    subtitle: Text(
                      '${task.dueDate!.hour.toString().padLeft(2, '0')}:${task.dueDate!.minute.toString().padLeft(2, '0')}',
                    ),
                  ),
                ),
              ],
              if (task.description.isNotEmpty) ...[
                const SizedBox(height: AppSpace.lg),
                Text(
                  'Mô tả',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: AppSpace.xs),
                Text(
                  task.description,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
              const SizedBox(height: AppSpace.xl),
              if (task.repeat.enabled) ...[
                Card(
                  child: ListTile(
                    leading: AppSvgIcon(
                      name: 'calendar-check-in-01',
                      color: colors.primary,
                    ),
                    title: const Text('Lặp lại công việc'),
                    subtitle: Text(task.repeat.label),
                  ),
                ),
                if (onStopRepeat != null)
                  TextButton.icon(
                    onPressed: onStopRepeat,
                    icon: AppSvgIcon(
                      name: 'calendar-check-in-01',
                      color: colors.error,
                    ),
                    label: const Text('Dừng chuỗi lặp'),
                    style: TextButton.styleFrom(foregroundColor: colors.error),
                  ),
                const SizedBox(height: AppSpace.sm),
              ],
              FilledButton.icon(
                onPressed: onToggle,
                icon: AppSvgIcon(
                  name: task.isCompleted ? 'task-01' : 'checkmark-circle-01',
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
                label: Text(
                  task.isCompleted
                      ? 'Đánh dấu đang thực hiện'
                      : 'Đánh dấu hoàn thành',
                ),
              ),
              const SizedBox(height: AppSpace.sm),
              TextButton.icon(
                onPressed: onDelete,
                icon: AppSvgIcon(name: 'delete-01', color: colors.error),
                label: const Text('Xóa công việc'),
                style: TextButton.styleFrom(foregroundColor: colors.error),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
