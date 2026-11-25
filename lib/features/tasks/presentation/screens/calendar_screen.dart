import 'dart:async';

import 'package:flutter/material.dart';
import 'package:task_flow_v2/core/time/app_time_zone.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:task_flow_v2/core/theme/app_theme.dart';
import 'package:task_flow_v2/features/tasks/data/models/task_model.dart';
import 'package:task_flow_v2/features/tasks/presentation/providers/task_provider.dart';
import 'package:task_flow_v2/features/tasks/presentation/screens/task_details_screen.dart';
import 'package:task_flow_v2/features/tasks/presentation/widgets/common/section_heading.dart';
import 'package:task_flow_v2/features/tasks/presentation/widgets/tasks/task_card.dart';
import 'package:task_flow_v2/features/tasks/presentation/widgets/tasks/task_load_error_panel.dart';
import 'package:task_flow_v2/features/tasks/presentation/widgets/tasks/priority_badge.dart';
import 'package:task_flow_v2/features/tasks/presentation/widgets/common/vietnamese_date.dart';
import 'package:task_flow_v2/features/tasks/presentation/widgets/common/task_due_date_display.dart';

import '../widgets/calendar/calendar_events.dart';
import '../widgets/calendar/calendar_timeline_layout.dart';
import '../widgets/common/task_flow_background.dart';

const _loadTasksErrorMessage = 'Không thể tải danh sách công việc.';

bool _sameDay(DateTime first, DateTime second) {
  return first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;
}

String _selectedDateLabel(DateTime date) {
  const months = [
    'thg 1',
    'thg 2',
    'thg 3',
    'thg 4',
    'thg 5',
    'thg 6',
    'thg 7',
    'thg 8',
    'thg 9',
    'thg 10',
    'thg 11',
    'thg 12',
  ];
  const weekdays = [
    'Thứ Hai',
    'Thứ Ba',
    'Thứ Tư',
    'Thứ Năm',
    'Thứ Sáu',
    'Thứ Bảy',
    'Chủ nhật',
  ];
  return '${weekdays[date.weekday - 1]} – ngày ${date.day} '
      '${months[date.month - 1]}, ${date.year}';
}

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({this.isActive = true, super.key});

  final bool isActive;

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  static const _minimumPixelsPerHour = 36.0;
  static const _maximumPixelsPerHour = 108.0;
  static const _initialPixelsPerHour = 72.0;

  late DateTime _selectedDate;
  late DateTime _visibleMonth;
  double _pixelsPerHour = _initialPixelsPerHour;

  bool _hasStartedInitialLoad = false;
  bool _hasAutoScrolledToCurrentTime = false;
  bool _autoScrollScheduled = false;
  final GlobalKey _timelineZoomSurfaceKey = GlobalKey();
  final GlobalKey _timelineLayoutKey = GlobalKey();
  final ScrollController _timelineScrollController = ScrollController();
  Timer? _currentTimeTimer;
  final Map<int, Offset> _timelinePointers = {};
  double? _pinchStartPixelsPerHour;
  double? _pinchStartDistance;
  double? _pinchAnchorMinute;

  @override
  void initState() {
    super.initState();

    final now = nowInAppTime();
    _selectedDate = DateTime(now.year, now.month, now.day);
    _visibleMonth = DateTime(now.year, now.month);

    _currentTimeTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });

    if (widget.isActive) {
      _startInitialLoad();
    }
  }

  @override
  void didUpdateWidget(covariant CalendarScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!oldWidget.isActive && widget.isActive) {
      final now = nowInAppTime();
      setState(() {
        _selectedDate = DateTime(now.year, now.month, now.day);
        _visibleMonth = DateTime(now.year, now.month);
        _hasAutoScrolledToCurrentTime = false;
      });
      _startInitialLoad();
    }
  }

  @override
  void dispose() {
    _currentTimeTimer?.cancel();
    _timelineScrollController.dispose();
    super.dispose();
  }

  void _startInitialLoad() {
    if (_hasStartedInitialLoad) return;

    Future.microtask(() {
      if (!mounted || !widget.isActive || _hasStartedInitialLoad) return;

      _hasStartedInitialLoad = true;
      final taskState = ref.read(taskProvider);

      if (!taskState.hasLoaded && !taskState.isLoading) {
        ref.read(taskProvider.notifier).loadTasks();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final taskState = ref.watch(taskProvider);
    final tasks = taskState.tasks;
    final colors = Theme.of(context).colorScheme;

    final now = nowInAppTime();
    final today = DateTime(now.year, now.month, now.day);

    final selectedTasks =
        tasks.where((task) {
          final dueDate = taskCalendarDate(task);
          return dueDate != null && _sameDay(dueDate, _selectedDate);
        }).toList()..sort(
          (first, second) =>
              (taskCalendarDate(first)!).compareTo(taskCalendarDate(second)!),
        );

    final isInitialLoading =
        tasks.isEmpty &&
        taskState.errorMessage == null &&
        (!_hasStartedInitialLoad || taskState.isLoading);
    final hasInitialError = tasks.isEmpty && taskState.errorMessage != null;
    final isLoadError = taskState.errorMessage == _loadTasksErrorMessage;

    final timelineReady =
        widget.isActive && !isInitialLoading && !hasInitialError;
    if (timelineReady && !_hasAutoScrolledToCurrentTime) {
      _scheduleScrollToCurrentTime();
    }

    return TaskFlowBackground(
      child: ContentColumn(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: AppSpace.lg),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lịch',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                    ),
                    const SizedBox(height: AppSpace.xs),
                    Text(
                      'Sắp xếp công việc theo ngày.',
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(color: colors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
            _CalendarHeaderPanel(
              month: _visibleMonth,
              selectedDate: _selectedDate,
              today: today,
              tasks: tasks,
              zoomPercent: (_pixelsPerHour / _initialPixelsPerHour * 100)
                  .round(),
              canZoomOut: _pixelsPerHour > _minimumPixelsPerHour,
              canZoomIn: _pixelsPerHour < _maximumPixelsPerHour,
              onPrevious: () => _changeMonth(-1),
              onNext: () => _changeMonth(1),
              onSelect: _selectDate,
              onWeekChanged: _selectWeek,
              onZoomOut: () {},
              onZoomIn: () {},
            ),
            Expanded(
              child: KeyedSubtree(
                key: const ValueKey('calendar-timeline-zoom-surface'),
                child: Listener(
                  key: _timelineZoomSurfaceKey,
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: _handleTimelinePointerDown,
                  onPointerMove: _handleTimelinePointerMove,
                  onPointerUp: _handleTimelinePointerEnd,
                  onPointerCancel: _handleTimelinePointerEnd,
                  child: CustomScrollView(
                    controller: _timelineScrollController,
                    slivers: [
                      if (taskState.isLoading && tasks.isNotEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.only(top: AppSpace.sm),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(
                                AppRadius.pill,
                              ),
                              child: const LinearProgressIndicator(
                                minHeight: 2,
                              ),
                            ),
                          ),
                        ),
                      if (!isInitialLoading &&
                          tasks.isNotEmpty &&
                          taskState.errorMessage != null)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.only(top: AppSpace.md),
                            child: TaskLoadErrorPanel(
                              message: taskState.errorMessage!,
                              onRetry: isLoadError
                                  ? () {
                                      ref
                                          .read(taskProvider.notifier)
                                          .loadTasks();
                                    }
                                  : null,
                            ),
                          ),
                        ),
                      if (isInitialLoading)
                        const SliverFillRemaining(
                          hasScrollBody: false,
                          child: _CalendarLoadingState(),
                        )
                      else if (hasInitialError)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpace.md,
                              ),
                              child: TaskLoadErrorPanel(
                                message: taskState.errorMessage!,
                                onRetry: isLoadError
                                    ? () {
                                        ref
                                            .read(taskProvider.notifier)
                                            .loadTasks();
                                      }
                                    : null,
                              ),
                            ),
                          ),
                        )
                      else
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.only(top: AppSpace.sm),
                            child: _CalendarDailyTimeline(
                              key: _timelineLayoutKey,
                              tasks: selectedTasks,
                              now: nowInAppTime(),
                              pixelsPerHour: _pixelsPerHour,
                              onTap: (task) {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) =>
                                        TaskDetailsScreen(taskId: task.id),
                                  ),
                                );
                              },
                              onToggle: (task) {
                                ref
                                    .read(taskProvider.notifier)
                                    .toggleTask(task.id, knownTask: task);
                              },
                            ),
                          ),
                        ),
                      const SliverToBoxAdapter(
                        child: SizedBox(height: AppSpace.xxl * 2),
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

  void _selectDate(DateTime date) {
    setState(() {
      _selectedDate = date;
      _visibleMonth = DateTime(date.year, date.month);
      _hasAutoScrolledToCurrentTime = false;
    });
  }

  void _scheduleScrollToCurrentTime() {
    if (_autoScrollScheduled || _hasAutoScrolledToCurrentTime) return;
    _autoScrollScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoScrollScheduled = false;
      if (!mounted || !widget.isActive || _hasAutoScrolledToCurrentTime) {
        return;
      }
      final timelineObject = _timelineLayoutKey.currentContext
          ?.findRenderObject();
      if (timelineObject is! RenderBox || !timelineObject.hasSize) return;
      final expectedTimelineHeight = CalendarTimelineLayout.contentHeight(
        pixelsPerHour: _pixelsPerHour,
        cardHeight: _pixelsPerHour,
        topInset: 0,
        gap: AppSpace.xxs,
      );
      if (timelineObject.size.height < expectedTimelineHeight) return;
      if (!_timelineScrollController.hasClients) return;
      if (!_sameDay(_selectedDate, nowInAppTime())) return;
      final position = _timelineScrollController.position;
      if (!position.hasContentDimensions || position.viewportDimension <= 0) {
        return;
      }
      final now = nowInAppTime();
      final currentTimeMarkerCenter =
          ((now.hour * 60 + now.minute) / 60) * _pixelsPerHour +
          AppSpace.sm +
          4;
      final target = currentTimeMarkerCenter - position.viewportDimension / 2;
      final clamped = target.clamp(0.0, position.maxScrollExtent);
      _timelineScrollController.jumpTo(clamped);
      _hasAutoScrolledToCurrentTime = true;
    });
  }

  void _changeMonth(int amount) {
    setState(() {
      _visibleMonth = DateTime(
        _visibleMonth.year,
        _visibleMonth.month + amount,
      );

      _selectedDate = DateTime(_visibleMonth.year, _visibleMonth.month, 1);
      _hasAutoScrolledToCurrentTime = false;
    });
  }

  void _selectWeek(DateTime weekStart) {
    final daysInWeek = List.generate(
      7,
      (index) => weekStart.add(Duration(days: index)),
    );
    if (daysInWeek.any((date) => _sameDay(date, _selectedDate))) return;

    final dateInMonth = daysInWeek.firstWhere(
      (date) =>
          date.year == _visibleMonth.year && date.month == _visibleMonth.month,
      orElse: () => weekStart,
    );
    _selectDate(dateInMonth);
  }

  void _handleTimelinePointerDown(PointerDownEvent event) {
    _timelinePointers[event.pointer] = event.position;
    if (_timelinePointers.length > 2) {
      _resetTimelinePinch();
      return;
    }
    if (_timelinePointers.length == 2) _beginTimelinePinch();
  }

  void _beginTimelinePinch() {
    if (!_timelineScrollController.hasClients) return;
    final points = _timelinePointers.values.toList(growable: false);
    final renderObject = _timelineZoomSurfaceKey.currentContext
        ?.findRenderObject();
    if (renderObject is! RenderBox) return;

    final localFocalPoint = renderObject.globalToLocal(
      (points[0] + points[1]) / 2,
    );
    _pinchStartDistance = (points[0] - points[1]).distance;
    _pinchStartPixelsPerHour = _pixelsPerHour;
    _pinchAnchorMinute =
        (_timelineScrollController.position.pixels + localFocalPoint.dy) /
        _pixelsPerHour *
        60;
  }

  void _handleTimelinePointerMove(PointerMoveEvent event) {
    if (!_timelinePointers.containsKey(event.pointer)) return;
    _timelinePointers[event.pointer] = event.position;
    if (_timelinePointers.length != 2 ||
        !_timelineScrollController.hasClients) {
      return;
    }

    final startDistance = _pinchStartDistance;
    final startScale = _pinchStartPixelsPerHour;
    final anchorMinute = _pinchAnchorMinute;
    final renderObject = _timelineZoomSurfaceKey.currentContext
        ?.findRenderObject();
    if (startDistance == null ||
        startDistance <= 0 ||
        startScale == null ||
        anchorMinute == null ||
        renderObject is! RenderBox) {
      return;
    }

    final points = _timelinePointers.values.toList(growable: false);
    final distance = (points[0] - points[1]).distance;
    final localFocalPoint = renderObject.globalToLocal(
      (points[0] + points[1]) / 2,
    );
    _applyZoom(
      CalendarTimelineLayout.clampPixelsPerHour(
        startScale * distance / startDistance,
        minimum: _minimumPixelsPerHour,
        maximum: _maximumPixelsPerHour,
      ),
      anchorMinute: anchorMinute,
      anchorViewportY: localFocalPoint.dy,
    );
  }

  void _handleTimelinePointerEnd(PointerEvent event) {
    _timelinePointers.remove(event.pointer);
    _resetTimelinePinch();
    if (_timelinePointers.length == 2) {
      _beginTimelinePinch();
    }
  }

  void _resetTimelinePinch() {
    _pinchStartDistance = null;
    _pinchStartPixelsPerHour = null;
    _pinchAnchorMinute = null;
  }

  void _applyZoom(
    double nextScale, {
    required double anchorMinute,
    required double anchorViewportY,
  }) {
    if (nextScale == _pixelsPerHour) return;
    setState(() => _pixelsPerHour = nextScale);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_timelineScrollController.hasClients) return;
      final position = _timelineScrollController.position;
      final target = anchorMinute / 60 * nextScale - anchorViewportY;
      _timelineScrollController.jumpTo(
        target.clamp(0.0, position.maxScrollExtent),
      );
    });
  }
}

class _CalendarHeaderPanel extends StatelessWidget {
  const _CalendarHeaderPanel({
    required this.month,
    required this.selectedDate,
    required this.today,
    required this.tasks,
    required this.zoomPercent,
    required this.canZoomOut,
    required this.canZoomIn,
    required this.onZoomOut,
    required this.onZoomIn,
    required this.onPrevious,
    required this.onNext,
    required this.onSelect,
    required this.onWeekChanged,
  });

  final DateTime month;
  final DateTime selectedDate;
  final DateTime today;
  final List<TaskModel> tasks;
  final int zoomPercent;
  final bool canZoomOut;
  final bool canZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onZoomIn;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final ValueChanged<DateTime> onSelect;
  final ValueChanged<DateTime> onWeekChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final eventLabels = calendarEventsFor(selectedDate);
    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpace.xs),
        child: Column(
          children: [
            _MonthHeader(
              label: VietnameseDate.monthYear(month),
              onPrevious: onPrevious,
              onNext: onNext,
            ),
            _WeekDateSelector(
              visibleMonth: month,
              selectedDate: selectedDate,
              today: today,
              tasks: tasks,
              onSelect: onSelect,
              onWeekChanged: onWeekChanged,
            ),
            const SizedBox(height: AppSpace.xs),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _selectedDateLabel(selectedDate),
                    textAlign: TextAlign.left,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            if (eventLabels.isNotEmpty) ...[
              const SizedBox(height: AppSpace.xxs),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  eventLabels.join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            Divider(
              height: AppSpace.sm,
              color: colors.outlineVariant.withValues(alpha: .55),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekDateSelector extends StatefulWidget {
  const _WeekDateSelector({
    required this.visibleMonth,
    required this.selectedDate,
    required this.today,
    required this.tasks,
    required this.onSelect,
    required this.onWeekChanged,
  });

  final DateTime visibleMonth;
  final DateTime selectedDate;
  final DateTime today;
  final List<TaskModel> tasks;
  final ValueChanged<DateTime> onSelect;
  final ValueChanged<DateTime> onWeekChanged;

  @override
  State<_WeekDateSelector> createState() => _WeekDateSelectorState();
}

class _WeekDateSelectorState extends State<_WeekDateSelector> {
  static const _initialPage = 1000;
  late DateTime _anchorWeek;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _anchorWeek = _mondayOf(widget.selectedDate);
    _pageController = PageController(initialPage: _initialPage);
  }

  @override
  void didUpdateWidget(covariant _WeekDateSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.visibleMonth.month != widget.visibleMonth.month ||
        oldWidget.visibleMonth.year != widget.visibleMonth.year) {
      _anchorWeek = _mondayOf(widget.selectedDate);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _pageController.hasClients) {
          _pageController.jumpToPage(_initialPage);
        }
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  static DateTime _mondayOf(DateTime date) => DateTime(
    date.year,
    date.month,
    date.day - date.weekday + DateTime.monday,
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return SizedBox(
      height: 62,
      child: PageView.builder(
        controller: _pageController,
        itemBuilder: (context, page) {
          final weekStart = _anchorWeek.add(
            Duration(days: (page - _initialPage) * 7),
          );
          return Row(
            children: List.generate(7, (index) {
              final date = DateTime(
                weekStart.year,
                weekStart.month,
                weekStart.day + index,
              );
              final isSelected = _sameDay(date, widget.selectedDate);
              final isToday = _sameDay(date, widget.today);
              final hasTasks = widget.tasks.any(
                (task) =>
                    taskHasDate(task) &&
                    _sameDay(taskCalendarDate(task)!, date),
              );

              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: index == 6 ? 0 : AppSpace.xs),
                  child: Semantics(
                    button: true,
                    selected: isSelected,
                    label:
                        '${VietnameseDate.full(date)}${hasTasks ? ', có công việc' : ''}',
                    child: InkWell(
                      splashFactory: NoSplash.splashFactory,
                      onTap: () => widget.onSelect(date),
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      child: Column(
                        children: [
                          Text(
                            VietnameseDate.shortWeekday(date.weekday - 1),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: isSelected
                                  ? colors.primary
                                  : colors.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Container(
                            width: 34,
                            height: 34,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isSelected ? colors.primary : null,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '${date.day}',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: isSelected
                                    ? colors.onPrimary
                                    : isToday
                                    ? colors.primary
                                    : colors.onSurface,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          SizedBox(
                            height: 5,
                            child: Center(
                              child: hasTasks
                                  ? Container(
                                      width: 5,
                                      height: 5,
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? colors.primary
                                            : colors.secondary,
                                        shape: BoxShape.circle,
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          );
        },
        onPageChanged: (page) {
          final weekStart = _anchorWeek.add(
            Duration(days: (page - _initialPage) * 7),
          );
          widget.onWeekChanged(weekStart);
        },
      ),
    );
  }
}

class _CalendarDailyTimeline extends StatelessWidget {
  const _CalendarDailyTimeline({
    super.key,
    required this.tasks,
    required this.now,
    required this.pixelsPerHour,
    required this.onTap,
    required this.onToggle,
  });

  static const _cardGap = AppSpace.xxs;

  final List<TaskModel> tasks;
  final DateTime now;
  final double pixelsPerHour;
  final ValueChanged<TaskModel> onTap;
  final ValueChanged<TaskModel> onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final timelineTasks = tasks
        .where(
          (task) =>
              task.dueDateType == TaskDueDateType.dateTime &&
              task.dueDate != null,
        )
        .toList();
    final timelineHeight = CalendarTimelineLayout.contentHeight(
      pixelsPerHour: pixelsPerHour,
      cardHeight: pixelsPerHour,
      topInset: 0,
      gap: _cardGap,
    );

    return SizedBox(
      height: timelineHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final groups = CalendarTimelineLayout.groupByHour(
            startTimes: [for (final task in timelineTasks) task.dueDate!],
            priorityRanks: [
              for (final task in timelineTasks)
                switch (task.priority) {
                  TaskPriority.high => 3,
                  TaskPriority.medium => 2,
                  TaskPriority.low => 1,
                },
            ],
            taskIds: [for (final task in timelineTasks) task.id],
            pixelsPerHour: pixelsPerHour,
          );

          return Stack(
            children: [
              for (var hour = 0; hour <= 24; hour++)
                Positioned(
                  top: hour * pixelsPerHour,
                  left: 0,
                  right: 0,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 35,
                        child: FractionalTranslation(
                          translation: const Offset(0, -0.5),
                          child: Text(
                            '${hour.toString().padLeft(2, '0')}:00',
                            textAlign: TextAlign.left,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpace.sm),
                      Expanded(
                        child: Divider(
                          height: 1,
                          color: colors.outlineVariant.withValues(alpha: .55),
                        ),
                      ),
                    ],
                  ),
                ),
              for (final group in groups)
                if (group.taskIndexes.every(
                  (index) => timelineTasks[index].dueDate != null,
                ))
                  _buildPositionedGroup(
                    context: context,
                    group: group,
                    constraints: constraints,
                    timelineTasks: timelineTasks,
                  ),
              Positioned(
                top: (now.hour * 60 + now.minute) / 60 * pixelsPerHour,
                left: 25 + AppSpace.sm,
                right: 0,
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: colors.error,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Expanded(
                      child: Divider(
                        height: 1,
                        thickness: 2,
                        color: colors.error,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPositionedGroup({
    required BuildContext context,
    required CalendarTimelineDisplayGroup group,
    required BoxConstraints constraints,
    required List<TaskModel> timelineTasks,
  }) {
    const leftInset = 35 + AppSpace.sm;
    const rightInset = 4.0;
    final availableWidth = constraints.maxWidth - leftInset - rightInset;
    final cardWidth =
        (availableWidth - _cardGap * (group.columnCount - 1)) /
        group.columnCount;
    final left = leftInset + group.column * (cardWidth + _cardGap);
    final groupTasks = [
      for (final index in group.taskIndexes) timelineTasks[index],
    ];
    final representative = timelineTasks[group.representativeTaskIndex];

    return Positioned(
      top: group.top,
      left: left,
      width: cardWidth,
      height: group.height,
      child: group.isGrouped
          ? _CalendarTimelineTaskGroup(
              task: representative,
              additionalTaskCount: group.additionalTaskCount,
              onOpen: () => _showTaskGroup(context, groupTasks),
            )
          : _CalendarTimelineTask(
              task: representative,
              zoomPercent: (pixelsPerHour / 72 * 100).round(),
              onTap: () => onTap(representative),
              onToggle: () => onToggle(representative),
            ),
    );
  }

  Future<void> _showTaskGroup(
    BuildContext context,
    List<TaskModel> groupTasks,
  ) async {
    final selectedTask = await showModalBottomSheet<TaskModel>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: FractionallySizedBox(
          heightFactor: .82,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Các công việc trong khung giờ này',
                        style: Theme.of(sheetContext).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Đóng',
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  itemCount: groupTasks.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpace.sm),
                  itemBuilder: (context, index) {
                    final taskId = groupTasks[index].id;
                    return Consumer(
                      builder: (context, ref, _) {
                        final matchingTasks = ref
                            .watch(taskProvider)
                            .tasks
                            .where((item) => item.id == taskId)
                            .toList();
                        final task = matchingTasks.isEmpty
                            ? groupTasks[index]
                            : matchingTasks.first;
                        return TaskCard(
                          task: task,
                          onTap: () => Navigator.of(sheetContext).pop(task),
                          onToggle: () {
                            ref
                                .read(taskProvider.notifier)
                                .toggleTask(task.id, knownTask: task);
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (selectedTask != null && context.mounted) onTap(selectedTask);
  }
}

class _CalendarTimelineTaskGroup extends StatelessWidget {
  const _CalendarTimelineTaskGroup({
    required this.task,
    required this.additionalTaskCount,
    required this.onOpen,
  });

  final TaskModel task;
  final int additionalTaskCount;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      color: theme.brightness == Brightness.dark
          ? colors.surfaceContainerHighest
          : colors.surfaceContainerHigh,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  task.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w700,
                    decoration: task.isCompleted
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$additionalTaskCount lời nhắc khác',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CalendarTimelineTask extends StatelessWidget {
  const _CalendarTimelineTask({
    required this.task,
    required this.zoomPercent,
    required this.onTap,
    required this.onToggle,
  });

  final TaskModel task;
  final int zoomPercent;
  final VoidCallback onTap;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dueDate = task.dueDate;
    final description = task.description.trim();
    final priorityColor = PriorityBadge.accentColor(context, task.priority);
    final time = dueDate == null
        ? 'Cả ngày'
        : '${dueDate.hour.toString().padLeft(2, '0')}:${dueDate.minute.toString().padLeft(2, '0')}';

    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        final width = constraints.maxWidth;
        final titleFits = height >= 24 && width >= 44;
        final showTime = height >= 45 && width >= 86;
        final showDescription =
            zoomPercent > 125 &&
            height >= 70 &&
            width >= 150 &&
            description.isNotEmpty;
        final showCompletion = height >= 45 && width >= 122;
        final horizontalPadding = width < 100 ? 4.0 : 8.0;

        return Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          color: priorityColor.withValues(
            alpha: theme.brightness == Brightness.dark ? .22 : .14,
          ),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Semantics(
            button: true,
            label: task.title,
            child: InkWell(
              onTap: onTap,
              onLongPress: showCompletion ? onToggle : null,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: double.infinity,
                    color: priorityColor,
                  ),
                  SizedBox(
                    width: 32,
                    height: double.infinity,
                    child: Center(
                      child: Semantics(
                        button: true,
                        label: task.isCompleted
                            ? 'Đánh dấu ${task.title} chưa hoàn thành'
                            : 'Đánh dấu ${task.title} đã hoàn thành',
                        child: InkResponse(
                          splashFactory: NoSplash.splashFactory,
                          onTap: onToggle,
                          radius: 18,
                          containedInkWell: true,
                          child: SizedBox(
                            width: 32,
                            height: 24,
                            child: Center(
                              child: Icon(
                                task.isCompleted
                                    ? Icons.check_circle
                                    : Icons.radio_button_unchecked,
                                size: 18,
                                color: task.isCompleted
                                    ? priorityColor
                                    : colors.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                      ),
                      child: !titleFits
                          ? const SizedBox.expand()
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildTitle(theme, colors),
                                if (showTime) ...[
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          time,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.labelSmall
                                              ?.copyWith(
                                                color: colors.onSurfaceVariant,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                                if (showDescription) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    description,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: colors.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTitle(ThemeData theme, ColorScheme colors) => Text(
    task.title,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: (theme.textTheme.bodySmall ?? const TextStyle()).copyWith(
      color: task.isCompleted ? colors.onSurfaceVariant : colors.onSurface,
      fontWeight: FontWeight.w700,
      decoration: task.isCompleted ? TextDecoration.lineThrough : null,
    ),
  );
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({
    required this.label,
    required this.onPrevious,
    required this.onNext,
  });

  final String label;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        IconButton(
          tooltip: 'Tháng trước',
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left),
        ),
        IconButton(
          tooltip: 'Tháng sau',
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

class _CalendarLoadingState extends StatelessWidget {
  const _CalendarLoadingState();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: colors.primary),
          const SizedBox(height: AppSpace.md),
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
