import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:task_flow_v2/core/time/app_time_zone.dart';
import 'package:popover/popover.dart';
import 'package:task_flow_v2/core/theme/app_theme.dart';
import 'package:task_flow_v2/features/tasks/data/models/task_model.dart';
import 'package:task_flow_v2/features/tasks/presentation/widgets/common/vietnamese_date.dart';
import 'package:task_flow_v2/features/tasks/presentation/widgets/common/app_svg_icon.dart';

class TaskDueDateReminderSection extends StatefulWidget {
  const TaskDueDateReminderSection({
    super.key,
    required this.dueDate,
    required this.selectedTime,
    this.dueDateType = TaskDueDateType.none,
    required this.isUrgent,
    required this.onDateToggled,
    required this.onDateSelected,
    required this.onTimeChanged,
    this.onTimeToggled,
    required this.onUrgencyChanged,
  });

  final DateTime? dueDate;
  final TimeOfDay? selectedTime;
  final TaskDueDateType dueDateType;
  final bool isUrgent;
  final ValueChanged<bool> onDateToggled;
  final ValueChanged<DateTime> onDateSelected;
  final ValueChanged<TimeOfDay> onTimeChanged;
  final ValueChanged<bool>? onTimeToggled;
  final ValueChanged<bool> onUrgencyChanged;

  @override
  State<TaskDueDateReminderSection> createState() =>
      _TaskDueDateReminderSectionState();
}

class _TaskDueDateReminderSectionState
    extends State<TaskDueDateReminderSection> {
  late DateTime _visibleMonth;
  late bool _isCalendarExpanded;
  bool _isTimeExpanded = false;

  @override
  void initState() {
    super.initState();
    _visibleMonth = _monthStart(widget.dueDate ?? nowInAppTime());
    _isCalendarExpanded = widget.dueDate != null;
    _isTimeExpanded = widget.dueDateType == TaskDueDateType.dateTime;
  }

  @override
  void didUpdateWidget(covariant TaskDueDateReminderSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dueDateType != widget.dueDateType) {
      _isTimeExpanded = widget.dueDateType == TaskDueDateType.dateTime;
    }
    if (widget.dueDate != null && oldWidget.dueDate == null) {
      _visibleMonth = _monthStart(widget.dueDate!);
      _isCalendarExpanded = true;
    } else if (widget.dueDate == null && oldWidget.dueDate != null) {
      _isCalendarExpanded = false;
    }
  }

  void _handleUrgentToggle(bool enabled) {
    widget.onUrgencyChanged(enabled);
  }

  static DateTime _monthStart(DateTime date) => DateTime(date.year, date.month);

  @override
  Widget build(BuildContext context) {
    final dueDate = widget.dueDate;
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: .7)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.md,
          AppSpace.sm,
          AppSpace.md,
          AppSpace.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Ngày & giờ',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.xs),
            _ScheduleRow(
              rowKey: const ValueKey('choose-task-date'),
              icon: 'calendar-01',
              title: 'Ngày',
              value: dueDate == null
                  ? 'Chưa chọn'
                  : VietnameseDate.numeric(dueDate),
              active: dueDate != null,
              onTap: () => _handleDateRowTap(dueDate),
              onToggle: _handleDateToggle,
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              child: dueDate == null || !_isCalendarExpanded
                  ? const SizedBox.shrink()
                  : InlineCalendar(
                      visibleMonth: _visibleMonth,
                      selectedDate: dueDate,
                      onMonthChanged: (month) {
                        setState(() => _visibleMonth = month);
                      },
                      onDateSelected: widget.onDateSelected,
                    ),
            ),
            Divider(
              height: 1,
              indent: 36,
              color: colors.outlineVariant.withValues(alpha: .65),
            ),
            _ScheduleRow(
              icon: 'clock-01',
              title: 'Thời gian',
              value:
                  widget.dueDateType == TaskDueDateType.dateTime &&
                      widget.selectedTime != null
                  ? MaterialLocalizations.of(context).formatTimeOfDay(
                      widget.selectedTime!,
                      alwaysUse24HourFormat: true,
                    )
                  : null,
              active: widget.dueDateType == TaskDueDateType.dateTime,
              onTap: _handleTimeTap,
              onToggle: _handleTimeToggle,
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              child: !_isTimeExpanded
                  ? const SizedBox.shrink()
                  : _InlineTimePicker(
                      initialTime:
                          widget.selectedTime ??
                          const TimeOfDay(hour: 9, minute: 0),
                      onTimeChanged: widget.onTimeChanged,
                    ),
            ),
            Divider(
              height: 1,
              indent: 36,
              color: colors.outlineVariant.withValues(alpha: .65),
            ),
            _ScheduleRow(
              icon: 'clock-01',
              materialIcon: Icons.alarm_rounded,
              title: 'Khẩn cấp',
              value: null,
              active: widget.isUrgent,
              onTap: null,
              onToggle: _handleUrgentToggle,
            ),
          ],
        ),
      ),
    );
  }

  void _handleDateToggle(bool enabled) {
    setState(() => _isCalendarExpanded = enabled);
    widget.onDateToggled(enabled);
  }

  void _handleDateRowTap(DateTime? dueDate) {
    if (dueDate == null) {
      _handleDateToggle(true);
      return;
    }

    setState(() => _isCalendarExpanded = !_isCalendarExpanded);
  }

  void _handleTimeToggle(bool enabled) {
    if (widget.dueDate == null) return;
    setState(() => _isTimeExpanded = enabled);
    if (enabled) {
      widget.onTimeChanged(
        widget.selectedTime ?? const TimeOfDay(hour: 9, minute: 0),
      );
    } else {
      widget.onTimeToggled?.call(false);
    }
  }

  void _handleTimeTap() {
    setState(() {
      if (widget.dueDate == null) return;
      if (widget.dueDateType != TaskDueDateType.dateTime) {
        _isTimeExpanded = true;
        widget.onTimeChanged(
          widget.selectedTime ?? const TimeOfDay(hour: 9, minute: 0),
        );
      } else {
        _isTimeExpanded = !_isTimeExpanded;
      }
    });
  }
}

class InlineCalendar extends StatelessWidget {
  const InlineCalendar({
    required this.visibleMonth,
    required this.selectedDate,
    required this.onMonthChanged,
    required this.onDateSelected,
  });

  final DateTime visibleMonth;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onMonthChanged;
  final ValueChanged<DateTime> onDateSelected;

  static const _weekdays = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
  static const _months = [
    'Tháng 1',
    'Tháng 2',
    'Tháng 3',
    'Tháng 4',
    'Tháng 5',
    'Tháng 6',
    'Tháng 7',
    'Tháng 8',
    'Tháng 9',
    'Tháng 10',
    'Tháng 11',
    'Tháng 12',
  ];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final firstDayOffset =
        DateTime(visibleMonth.year, visibleMonth.month, 1).weekday - 1;
    final daysInMonth = DateTime(
      visibleMonth.year,
      visibleMonth.month + 1,
      0,
    ).day;
    final today = nowInAppTime();

    return Padding(
      padding: const EdgeInsets.only(left: 10, right: 10, bottom: AppSpace.sm),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Transform.translate(
                  offset: const Offset(12, 3),
                  child: Text(
                    '${_months[visibleMonth.month - 1]} năm ${visibleMonth.year}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Tháng trước',
                onPressed: () => onMonthChanged(
                  DateTime(visibleMonth.year, visibleMonth.month - 1),
                ),
                icon: Icon(Icons.chevron_left_rounded, color: colors.primary),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Tháng sau',
                onPressed: () => onMonthChanged(
                  DateTime(visibleMonth.year, visibleMonth.month + 1),
                ),
                icon: Icon(Icons.chevron_right_rounded, color: colors.primary),
              ),
            ],
          ),
          Row(
            children: [
              for (final weekday in _weekdays)
                Expanded(
                  child: Center(
                    child: Text(
                      weekday,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpace.xs),
          GridView.builder(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: firstDayOffset + daysInMonth,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisExtent: 36,
              mainAxisSpacing: 2,
              crossAxisSpacing: 0,
            ),
            itemBuilder: (context, index) {
              if (index < firstDayOffset) return const SizedBox.shrink();

              final day = index - firstDayOffset + 1;
              final date = DateTime(visibleMonth.year, visibleMonth.month, day);
              final isSelected = _sameDate(date, selectedDate);
              final isToday = _sameDate(date, today);

              return Center(
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => onDateSelected(date),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected ? colors.primary : Colors.transparent,
                      shape: BoxShape.circle,
                      border: isToday && !isSelected
                          ? Border.all(color: colors.primary, width: 1.4)
                          : null,
                    ),
                    child: Text(
                      '$day',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 15,
                        color: isSelected ? colors.onPrimary : colors.onSurface,
                        fontWeight: isSelected || isToday
                            ? FontWeight.w800
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  static bool _sameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _InlineTimePicker extends StatefulWidget {
  const _InlineTimePicker({
    required this.initialTime,
    required this.onTimeChanged,
  });

  final TimeOfDay initialTime;
  final ValueChanged<TimeOfDay> onTimeChanged;

  @override
  State<_InlineTimePicker> createState() => _InlineTimePickerState();
}

class _InlineTimePickerState extends State<_InlineTimePicker> {
  late final FixedExtentScrollController _hourController;
  late final FixedExtentScrollController _minuteController;

  @override
  void initState() {
    super.initState();
    _hourController = FixedExtentScrollController(
      initialItem: widget.initialTime.hour,
    );
    _minuteController = FixedExtentScrollController(
      initialItem: widget.initialTime.minute,
    );
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.xs,
        AppSpace.xs,
        AppSpace.xs,
        AppSpace.sm,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest.withValues(alpha: .55),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: SizedBox(
          height: 148,
          child: Stack(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 92,
                    child: CupertinoPicker(
                      itemExtent: 36,
                      scrollController: _hourController,
                      onSelectedItemChanged: (hour) {
                        widget.onTimeChanged(
                          TimeOfDay(
                            hour: hour,
                            minute: widget.initialTime.minute,
                          ),
                        );
                      },
                      children: [
                        for (var hour = 0; hour < 24; hour++)
                          Center(
                            child: Text(
                              hour.toString().padLeft(2, '0'),
                              style: textTheme.titleMedium,
                            ),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 92,
                    child: CupertinoPicker(
                      itemExtent: 36,
                      scrollController: _minuteController,
                      onSelectedItemChanged: (minute) {
                        widget.onTimeChanged(
                          TimeOfDay(
                            hour: widget.initialTime.hour,
                            minute: minute,
                          ),
                        );
                      },
                      children: [
                        for (var minute = 0; minute < 60; minute++)
                          Center(
                            child: Text(
                              minute.toString().padLeft(2, '0'),
                              style: textTheme.titleMedium,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScheduleRow extends StatelessWidget {
  const _ScheduleRow({
    this.rowKey,
    this.materialIcon,
    this.onToggle,
    required this.icon,
    required this.title,
    required this.value,
    required this.active,
    required this.onTap,
  });

  final Key? rowKey;
  final IconData? materialIcon;
  final ValueChanged<bool>? onToggle;
  final String icon;
  final String title;
  final String? value;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return InkWell(
      key: rowKey,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
        child: Row(
          children: [
            materialIcon == null
                ? AppSvgIcon(
                    name: icon,
                    size: 20,
                    color: onToggle == null ? colors.outline : colors.primary,
                  )
                : Icon(
                    materialIcon,
                    size: 21,
                    color: onToggle == null ? colors.outline : colors.primary,
                  ),
            const SizedBox(width: AppSpace.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (value != null)
                    Text(
                      value!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: active
                            ? colors.primary
                            : colors.onSurfaceVariant,
                        fontWeight: active ? FontWeight.w600 : null,
                      ),
                    ),
                ],
              ),
            ),
            Switch.adaptive(value: active, onChanged: onToggle),
          ],
        ),
      ),
    );
  }
}

class TaskRepeatReminderSection extends StatelessWidget {
  const TaskRepeatReminderSection({
    super.key,
    required this.repeatLabel,
    required this.repeatEnabled,
    required this.endTypeLabel,
    required this.endDate,
    required this.endDateValue,
    required this.repeatConfig,
    required this.onRepeatChanged,
    required this.onEndTypeChanged,
    required this.onEndDateSelected,
    required this.reminderSelection,
    required this.reminderEnabled,
    required this.onReminderChanged,
  });

  final String repeatLabel;
  final bool repeatEnabled;
  final String endTypeLabel;
  final String? endDate;
  final DateTime endDateValue;
  final TaskRepeatConfig repeatConfig;
  final ValueChanged<TaskRepeatFrequency?> onRepeatChanged;
  final ValueChanged<String> onEndTypeChanged;
  final ValueChanged<DateTime> onEndDateSelected;
  final int reminderSelection;
  final bool reminderEnabled;
  final ValueChanged<int> onReminderChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      children: [
        Card(
          margin: EdgeInsets.zero,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            side: BorderSide(
              color: colors.outlineVariant.withValues(alpha: .7),
            ),
          ),
          child: Column(
            children: [
              _OptionRow(
                icon: 'calendar-check-in-01',
                title: 'Lặp lại',
                value: repeatLabel,
                onTapWithContext: _showRepeatPopover,
              ),
              Divider(
                height: 1,
                indent: 56,
                endIndent: AppSpace.md,
                color: colors.outlineVariant.withValues(alpha: .65),
              ),
              if (repeatEnabled) ...[
                Divider(
                  height: 1,
                  indent: 56,
                  endIndent: AppSpace.md,
                  color: colors.outlineVariant.withValues(alpha: .65),
                ),
                _OptionRow(
                  icon: 'calendar-01',
                  title: 'Kết thúc lặp lại',
                  value: endTypeLabel,
                  onTapWithContext: _showEndTypePopover,
                ),
                Divider(
                  height: 1,
                  indent: 56,
                  endIndent: AppSpace.md,
                  color: colors.outlineVariant.withValues(alpha: .65),
                ),
                if (endTypeLabel == 'Vào ngày')
                  _RepeatEndDatePicker(
                    value: endDate ?? 'Chọn ngày',
                    selectedDate: endDateValue,
                    onDateSelected: onEndDateSelected,
                  ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpace.sm),
        Card(
          margin: EdgeInsets.zero,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            side: BorderSide(
              color: colors.outlineVariant.withValues(alpha: .7),
            ),
          ),
          child: _OptionRow(
            icon: 'notification-01',
            title: 'Lời nhắc sớm',
            value: _reminderLabel(reminderSelection),
            enabled: reminderEnabled,
            isReminder: true,
            onTapWithContext: _showReminderMenu,
          ),
        ),
      ],
    );
  }

  String _reminderLabel(int minutes) => switch (minutes) {
    0 => 'Không có',
    15 => 'Trước 15 phút',
    60 => 'Trước 1 giờ',
    1440 => 'Trước 1 ngày',
    _ => 'Đã bật',
  };

  Future<void> _showRepeatPopover(BuildContext context) async {
    final choice = await showPopover<_RepeatMenuChoice>(
      context: context,
      width: 208,
      height: 208,
      direction: PopoverDirection.bottom,
      arrowDxOffset: 70,
      style: const PopoverStyle(arrowHeight: 0, arrowWidth: 0),
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      semanticsLabel: 'Chọn chu kỳ lặp lại',

      bodyBuilder: (context) => Material(
        type: MaterialType.transparency,
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
          children: [
            for (final option in _repeatOptions)
              ListTile(
                dense: true,
                title: Text(option.label),
                trailing: option.value == _currentRepeatChoice
                    ? Icon(
                        Icons.check_rounded,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : null,
                onTap: () => Navigator.of(context).pop(option.value),
              ),
          ],
        ),
      ),
    );
    if (choice == null) return;
    onRepeatChanged(switch (choice) {
      _RepeatMenuChoice.none => null,
      _RepeatMenuChoice.daily => TaskRepeatFrequency.daily,
      _RepeatMenuChoice.weekly => TaskRepeatFrequency.weekly,
      _RepeatMenuChoice.monthly => TaskRepeatFrequency.monthly,
    });
  }

  Future<void> _showEndTypePopover(BuildContext context) async {
    final selected = await showPopover<String>(
      context: context,
      width: 208,
      height: 112,
      direction: PopoverDirection.bottom,
      arrowDxOffset: 70,
      style: const PopoverStyle(arrowHeight: 0, arrowWidth: 0),
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      semanticsLabel: 'Chọn thời điểm kết thúc lặp lại',
      bodyBuilder: (context) => Material(
        type: MaterialType.transparency,
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
          children: [
            for (final option in const ['Không', 'Vào ngày'])
              ListTile(
                dense: true,
                title: Text(option),
                trailing: option == endTypeLabel
                    ? Icon(
                        Icons.check_rounded,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : null,
                onTap: () => Navigator.of(context).pop(option),
              ),
          ],
        ),
      ),
    );
    if (selected != null) onEndTypeChanged(selected);
  }

  _RepeatMenuChoice get _currentRepeatChoice {
    if (!repeatConfig.enabled) return _RepeatMenuChoice.none;
    return switch (repeatConfig.frequency) {
      TaskRepeatFrequency.daily => _RepeatMenuChoice.daily,
      TaskRepeatFrequency.weekly => _RepeatMenuChoice.weekly,
      TaskRepeatFrequency.monthly => _RepeatMenuChoice.monthly,
      null => _RepeatMenuChoice.none,
    };
  }

  static const _repeatOptions = [
    (value: _RepeatMenuChoice.none, label: 'Không'),
    (value: _RepeatMenuChoice.daily, label: 'Hằng ngày'),
    (value: _RepeatMenuChoice.weekly, label: 'Hằng tuần'),
    (value: _RepeatMenuChoice.monthly, label: 'Hằng tháng'),
  ];

  Future<void> _showReminderMenu(BuildContext context) async {
    final value = await showPopover<int>(
      context: context,
      width: 208,
      height: 208,
      direction: PopoverDirection.bottom,
      arrowDxOffset: 70,
      style: const PopoverStyle(arrowHeight: 0, arrowWidth: 0),
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      semanticsLabel: 'Chọn thời gian nhắc sớm',
      bodyBuilder: (context) => Material(
        type: MaterialType.transparency,
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
          children: [
            for (final option in const [
              (value: 0, label: 'Không có'),
              (value: 15, label: 'Trước 15 phút'),
              (value: 60, label: 'Trước 1 giờ'),
              (value: 1440, label: 'Trước 1 ngày'),
            ])
              ListTile(
                dense: true,
                title: Text(option.label),
                trailing: option.value == reminderSelection
                    ? Icon(
                        Icons.check_rounded,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : null,
                onTap: () => Navigator.of(context).pop(option.value),
              ),
          ],
        ),
      ),
    );

    if (value != null) {
      onReminderChanged(value);
    }
  }
}

class _RepeatEndDatePicker extends StatefulWidget {
  const _RepeatEndDatePicker({
    required this.value,
    required this.selectedDate,
    required this.onDateSelected,
  });

  final String value;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;

  @override
  State<_RepeatEndDatePicker> createState() => _RepeatEndDatePickerState();
}

class _RepeatEndDatePickerState extends State<_RepeatEndDatePicker> {
  late DateTime _visibleMonth = DateTime(
    widget.selectedDate.year,
    widget.selectedDate.month,
  );

  @override
  Widget build(BuildContext context) => Column(
    children: [
      _OptionRow(
        icon: 'calendar-01',
        title: 'Ngày kết thúc',
        value: widget.value,
        showDatePrefix: widget.value != 'Chọn ngày',
        pillValue: true,
        onTap: () => _showCalendar(context),
      ),
    ],
  );

  Future<void> _showCalendar(BuildContext context) async {
    final selectedDate = await showPopover<DateTime>(
      context: context,
      width: 300,
      height: 320,
      direction: PopoverDirection.bottom,
      arrowDxOffset: 70,
      style: const PopoverStyle(arrowHeight: 0, arrowWidth: 0),
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      semanticsLabel: 'Chọn ngày kết thúc',
      bodyBuilder: (context) => Material(
        type: MaterialType.transparency,
        child: SingleChildScrollView(
          // Keep the calendar inside the fixed-height popover on compact screens.
          // If the available height is insufficient, scroll instead of overflowing.
          physics: const ClampingScrollPhysics(),
          child: InlineCalendar(
            visibleMonth: _visibleMonth,
            selectedDate: widget.selectedDate,
            onMonthChanged: (month) => setState(() => _visibleMonth = month),
            onDateSelected: (date) => Navigator.of(context).pop(date),
          ),
        ),
      ),
    );
    if (selectedDate != null) {
      widget.onDateSelected(selectedDate);
      setState(
        () => _visibleMonth = DateTime(selectedDate.year, selectedDate.month),
      );
    }
  }
}

enum _RepeatMenuChoice { none, daily, weekly, monthly }

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.icon,
    required this.title,
    required this.value,
    this.onTap,
    this.onTapWithContext,
    this.enabled = true,
    this.pillValue = false,
    this.showDatePrefix = false,
    this.isReminder = false,
  });

  final String icon;
  final String title;
  final String value;
  final VoidCallback? onTap;
  final ValueChanged<BuildContext>? onTapWithContext;
  final bool enabled;
  final bool pillValue;
  final bool showDatePrefix;
  final bool isReminder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final handleTap = onTapWithContext == null
        ? onTap
        : () => onTapWithContext!(context);
    return InkWell(
      onTap: pillValue ? null : handleTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.md,
          vertical: AppSpace.sm,
        ),
        child: Row(
          children: [
            AppSvgIcon(
              name: icon,
              size: 21,
              color: isReminder || enabled ? colors.primary : colors.outline,
            ),
            const SizedBox(width: AppSpace.sm),

            Text(
              title,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),

            if (pillValue || isReminder)
              const SizedBox(width: AppSpace.sm)
            else
              const Spacer(),

            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: InkWell(
                  onTap: pillValue ? handleTap : null,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: DecoratedBox(
                    decoration: pillValue
                        ? BoxDecoration(
                            color: colors.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          )
                        : const BoxDecoration(),
                    child: Padding(
                      padding: pillValue
                          ? const EdgeInsets.symmetric(
                              horizontal: AppSpace.sm,
                              vertical: AppSpace.xs,
                            )
                          : EdgeInsets.zero,
                      child: Text(
                        showDatePrefix ? 'Ngày $value' : value,
                        textAlign: TextAlign.end,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.visible,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: value == 'Không lặp lại'
                              ? colors.onSurface
                              : enabled
                              ? colors.primary
                              : colors.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            if (!pillValue) ...[
              const SizedBox(width: AppSpace.xs),
              Icon(
                Icons.expand_more_rounded,
                color: enabled ? colors.onSurfaceVariant : colors.outline,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
