import 'package:flutter/material.dart';
import 'package:task_flow_v2/core/theme/app_theme.dart';
import 'package:task_flow_v2/features/tasks/data/models/task_model.dart';
import 'package:task_flow_v2/features/tasks/presentation/widgets/common/app_svg_icon.dart';

class PriorityBadge extends StatelessWidget {
  const PriorityBadge({required this.priority, super.key});

  final TaskPriority priority;

  static Color accentColor(BuildContext context, TaskPriority priority) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return switch (priority) {
      TaskPriority.high =>
        isDark ? const Color(0xFFFFB36B) : AppPalette.warning,
      TaskPriority.medium =>
        isDark ? const Color(0xFF7ED7AD) : AppPalette.success,
      TaskPriority.low =>
        isDark ? const Color(0xFFC1A3FF) : AppPalette.terracotta,
    };
  }

  @override
  Widget build(BuildContext context) {
    final color = accentColor(context, priority);
    final (label, iconName) = switch (priority) {
      TaskPriority.high => ('Ưu tiên cao', 'flag-01'),
      TaskPriority.medium => ('Bình thường', 'checkmark-circle-01'),
      TaskPriority.low => ('Ưu tiên thấp', 'star'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(
          alpha: Theme.of(context).brightness == Brightness.dark ? .18 : .12,
        ),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppSvgIcon(name: iconName, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
