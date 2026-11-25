import 'package:flutter/material.dart';
import 'package:task_flow_v2/features/tasks/data/models/task_model.dart';
import 'package:task_flow_v2/features/tasks/presentation/widgets/tasks/priority_badge.dart';
import 'package:task_flow_v2/features/tasks/presentation/widgets/common/app_svg_icon.dart';
import 'package:task_flow_v2/features/tasks/presentation/widgets/tasks/task_category_label.dart';
import 'package:task_flow_v2/features/tasks/presentation/widgets/common/vietnamese_date.dart';
import 'package:task_flow_v2/features/tasks/presentation/widgets/common/task_due_date_display.dart';

class TaskCard extends StatelessWidget {
  const TaskCard({
    required this.task,
    required this.onTap,
    required this.onToggle,
    this.isToggleEnabled = true,
    super.key,
  });

  final TaskModel task;
  final VoidCallback onTap;
  final VoidCallback onToggle;
  final bool isToggleEnabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final isCompleted = task.isCompleted;

    final description = task.description.trim();
    final dueDate = taskCalendarDate(task);
    final category = taskCategoryLabel(task.category);
    final priorityColor = PriorityBadge.accentColor(context, task.priority);

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      color: isDark ? const Color(0xFF202B40) : Colors.white,
      elevation: isDark ? 0 : 2,
      shadowColor: colors.primary.withValues(alpha: 0.07),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.45)),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Priority indicator
            Container(
              width: 4,
              decoration: BoxDecoration(color: priorityColor),
            ),

            // Checkbox
            SizedBox(
              width: 48,
              child: Center(
                child: Checkbox(
                  value: isCompleted,
                  onChanged: isToggleEnabled ? (_) => onToggle() : null,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  visualDensity: VisualDensity.compact,
                  semanticLabel: isCompleted
                      ? 'Đánh dấu ${task.title} chưa hoàn thành'
                      : 'Đánh dấu ${task.title} đã hoàn thành',
                ),
              ),
            ),

            // Task content
            Expanded(
              child: InkWell(
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(4, 14, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title and priority
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              task.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontSize: 14.5,
                                height: 1.4,
                                fontWeight: FontWeight.w700,
                                color: isCompleted
                                    ? colors.onSurfaceVariant
                                    : colors.onSurface,
                                decoration: isCompleted
                                    ? TextDecoration.lineThrough
                                    : null,
                                decorationColor: colors.onSurfaceVariant,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          PriorityBadge(priority: task.priority),
                        ],
                      ),

                      // Description
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 7),
                        Text(
                          description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 12,
                            height: 1.5,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],

                      const SizedBox(height: 13),

                      // Metadata
                      Wrap(
                        spacing: 14,
                        runSpacing: 9,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (dueDate != null) ...[
                            _TaskMetadata(
                              icon: 'calendar-01',
                              text: VietnameseDate.numeric(dueDate),
                              color: colors.onSurfaceVariant,
                            ),
                            if (task.dueDateType == TaskDueDateType.dateTime)
                              _TaskMetadata(
                                icon: 'clock-01',
                                text:
                                    '${dueDate.hour.toString().padLeft(2, '0')}:${dueDate.minute.toString().padLeft(2, '0')}',
                                color: colors.onSurfaceVariant,
                              ),
                          ],
                          _TaskMetadata(
                            icon: 'folder-01',
                            text: category,
                            color: colors.onSurfaceVariant,
                          ),
                          if (task.repeat.enabled)
                            _TaskMetadata(
                              icon: 'calendar-check-in-01',
                              text: task.repeat.label,
                              color: colors.primary,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskMetadata extends StatelessWidget {
  const _TaskMetadata({
    required this.icon,
    required this.text,
    required this.color,
  });

  final String icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppSvgIcon(name: icon, size: 13, color: color),
        const SizedBox(width: 5),
        Text(
          text,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }
}
