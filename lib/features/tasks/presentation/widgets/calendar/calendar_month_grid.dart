import 'package:flutter/material.dart';
import 'package:task_flow_v2/core/theme/app_theme.dart';
import 'package:task_flow_v2/features/tasks/data/models/task_model.dart';
import 'package:task_flow_v2/features/tasks/presentation/widgets/common/task_due_date_display.dart';
import 'package:task_flow_v2/features/tasks/presentation/widgets/common/vietnamese_date.dart';

bool _sameDay(DateTime first, DateTime second) {
  return first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;
}

class CalendarMonthGrid extends StatelessWidget {
  const CalendarMonthGrid({
    super.key,
    required this.visibleMonth,
    required this.selectedDate,
    required this.today,
    required this.tasks,
    required this.onSelect,
  });

  final DateTime visibleMonth;
  final DateTime selectedDate;
  final DateTime today;
  final List<TaskModel> tasks;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final firstOfMonth = DateTime(visibleMonth.year, visibleMonth.month);
    final leadingDays = firstOfMonth.weekday - 1;
    final gridStart = firstOfMonth.subtract(Duration(days: leadingDays));

    return Column(
      children: [
        Row(
          children: List.generate(7, (index) {
            return Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
                  child: Text(
                    VietnameseDate.shortWeekday(index),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
        SizedBox(
          height: 6 * 46,
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 42,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisExtent: 46,
            ),
            itemBuilder: (context, index) {
              final date = gridStart.add(Duration(days: index));
              final isCurrentMonth =
                  date.month == visibleMonth.month &&
                  date.year == visibleMonth.year;
              final isSelected = _sameDay(date, selectedDate);
              final isToday = _sameDay(date, today);

              final hasTasks = tasks.any((task) {
                final dueDate = taskCalendarDate(task);
                return dueDate != null && _sameDay(dueDate, date);
              });

              final dayTextColor = isSelected
                  ? scheme.onPrimary
                  : isToday
                  ? scheme.primary
                  : isCurrentMonth
                  ? scheme.onSurface
                  : scheme.onSurfaceVariant.withValues(alpha: 0.55);

              final indicatorColor = isSelected
                  ? scheme.onPrimary
                  : scheme.secondary;

              final todayLabel = isToday ? 'Hôm nay, ' : '';
              final taskLabel = hasTasks
                  ? ', có công việc'
                  : ', không có công việc';

              return Semantics(
                button: true,
                selected: isSelected,
                label: '$todayLabel${VietnameseDate.full(date)}$taskLabel',
                child: InkWell(
                  onTap: () => onSelect(date),
                  splashFactory: NoSplash.splashFactory,
                  overlayColor: WidgetStateProperty.resolveWith<Color?>((
                    states,
                  ) {
                    if (states.contains(WidgetState.pressed)) {
                      return Colors.transparent;
                    }
                    return null;
                  }),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected ? scheme.primary : null,
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          border: isToday && !isSelected
                              ? Border.all(color: scheme.primary, width: 1.5)
                              : null,
                        ),
                        child: ExcludeSemantics(
                          child: Text(
                            '${date.day}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: dayTextColor,
                              fontWeight: isSelected || isToday
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: hasTasks ? indicatorColor : Colors.transparent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
