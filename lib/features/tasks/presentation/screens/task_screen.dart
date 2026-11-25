import 'dart:async';

import 'package:flutter/material.dart';
import 'package:task_flow_v2/core/time/app_time_zone.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:task_flow_v2/core/theme/app_theme.dart';
import 'package:task_flow_v2/features/tasks/data/models/task_model.dart';
import 'package:task_flow_v2/features/tasks/presentation/screens/task_details_screen.dart';
import 'package:task_flow_v2/features/tasks/presentation/screens/task_form_screen.dart';
import 'package:task_flow_v2/features/tasks/presentation/widgets/tasks/empty_state.dart';
import 'package:task_flow_v2/features/tasks/presentation/widgets/common/app_svg_icon.dart';
import 'package:task_flow_v2/features/tasks/presentation/widgets/common/section_heading.dart';
import 'package:task_flow_v2/features/tasks/presentation/widgets/tasks/task_card.dart';
import 'package:task_flow_v2/features/tasks/presentation/widgets/tasks/task_load_error_panel.dart';
import 'package:task_flow_v2/features/tasks/presentation/widgets/common/task_due_date_display.dart';

import '../providers/task_provider.dart';
import '../providers/task_screen_task_provider.dart';
import '../widgets/common/task_flow_background.dart';
import '../widgets/common/dismiss_keyboard_on_tap.dart';
import '../widgets/common/keyboard_dismissible_scroll_view.dart';

const _loadMoreThreshold = 400.0;

enum _TaskFilter { all, today, upcoming, completed }

class TaskScreen extends ConsumerStatefulWidget {
  const TaskScreen({this.isActive = true, super.key});

  final bool isActive;

  @override
  ConsumerState<TaskScreen> createState() => _TaskScreenState();
}

class _TaskScreenState extends ConsumerState<TaskScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  _TaskFilter _filter = _TaskFilter.all;
  TaskPriority? _priorityFilter;
  DateTimeRange? _dueDateRange;
  Timer? _searchDebounce;
  bool _hasStartedInitialLoad = false;
  bool _hasObservedSharedTaskList = false;
  bool _isCompletedGroupExpanded = false;
  final Set<String> _tasksBeingToggled = {};

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _hasObservedSharedTaskList = ref.read(taskProvider).hasLoaded;

    if (widget.isActive) _startInitialLoad();
  }

  @override
  void didUpdateWidget(covariant TaskScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!oldWidget.isActive && widget.isActive) _startInitialLoad();
  }

  void _startInitialLoad() {
    if (_hasStartedInitialLoad) return;

    Future.microtask(() {
      if (!mounted || !widget.isActive || _hasStartedInitialLoad) return;

      setState(() => _hasStartedInitialLoad = true);
      // Home and Calendar keep the complete shared task list. This screen
      // loads only its paginated query.
      unawaited(_loadTasks());
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pageState = ref.watch(taskScreenTaskProvider);
    final colors = Theme.of(context).colorScheme;

    ref.listen(taskProvider.select((state) => state.tasks), (previous, next) {
      if (identical(previous, next)) return;

      final changedTaskIds = <String>{};
      if (previous != null && previous.length == next.length) {
        for (var index = 0; index < next.length; index++) {
          if (!identical(previous[index], next[index])) {
            changedTaskIds.add(next[index].id);
          }
        }
      }
      if (changedTaskIds.isNotEmpty &&
          changedTaskIds.every(_tasksBeingToggled.contains)) {
        return;
      }

      final sharedState = ref.read(taskProvider);
      if (!_hasObservedSharedTaskList) {
        if (sharedState.hasLoaded) {
          _hasObservedSharedTaskList = true;
          return;
        }

        // A create can finish before the first full-list request does.
        if (next.length > (previous?.length ?? 0)) {
          _hasObservedSharedTaskList = true;
          unawaited(_loadTasks());
        }
        return;
      }

      unawaited(_loadTasks());
    });

    final isInitialLoading =
        pageState.items.isEmpty &&
        pageState.errorMessage == null &&
        (!_hasStartedInitialLoad || pageState.isLoading);
    final hasInitialError =
        pageState.items.isEmpty && pageState.errorMessage != null;
    final isUnfiltered =
        _filter == _TaskFilter.all &&
        _searchController.text.trim().isEmpty &&
        _priorityFilter == null &&
        _dueDateRange == null;
    final showCompletedGroup =
        _filter == _TaskFilter.all &&
        _searchController.text.trim().isEmpty &&
        _priorityFilter == null &&
        _dueDateRange == null;
    final completedItems = showCompletedGroup
        ? pageState.completedItems
        : const <TaskModel>[];
    final pendingItems = showCompletedGroup ? pageState.items : pageState.items;

    final resultHeading = isInitialLoading || hasInitialError
        ? 'Công việc'
        : showCompletedGroup
        ? 'Tất cả công việc'
        : '${pageState.totalItems} công việc';

    return TaskFlowBackground(
      child: ContentColumn(
        child: KeyboardDismissibleScrollBehavior(
          child: DismissKeyboardOnTap(
            child: CustomScrollView(
              key: const PageStorageKey('tasks-scroll'),
              controller: _scrollController,
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.only(top: AppSpace.lg),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Công việc',
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                        ),
                        const SizedBox(height: AppSpace.xs),
                        Text(
                          'Danh sách việc cần hoàn thành.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: colors.onSurfaceVariant),
                        ),
                        const SizedBox(height: AppSpace.lg),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                key: const ValueKey('task-search'),
                                controller: _searchController,
                                onChanged: _onSearchChanged,
                                textInputAction: TextInputAction.search,
                                decoration: InputDecoration(
                                  hintText: 'Tìm công việc...',
                                  prefixIcon: Icon(
                                    Icons.search_rounded,
                                    size: 24,
                                    color: colors.onSurfaceVariant,
                                  ),
                                  prefixIconConstraints: const BoxConstraints(
                                    minWidth: 48,
                                    minHeight: 48,
                                  ),
                                  suffixIcon: _searchController.text.isEmpty
                                      ? null
                                      : IconButton(
                                          tooltip: 'Xóa nội dung tìm kiếm',
                                          onPressed: _clearSearch,
                                          icon: const Icon(Icons.close),
                                        ),
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpace.xs),
                            IconButton.filledTonal(
                              key: const ValueKey('task-priority-filter'),
                              tooltip:
                                  _priorityFilter == null &&
                                      _dueDateRange == null
                                  ? 'Lọc theo mức độ ưu tiên'
                                  : [
                                      if (_priorityFilter != null)
                                        'Ưu tiên: ${_priorityLabel(_priorityFilter!)}',
                                      if (_dueDateRange != null) 'Có lọc ngày',
                                    ].join(' · '),
                              onPressed: _showPriorityFilter,
                              style: IconButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.md,
                                  ),
                                ),
                                minimumSize: const Size(48, 48),
                                padding: EdgeInsets.zero,
                                backgroundColor:
                                    _priorityFilter == null &&
                                        _dueDateRange == null
                                    ? colors.surfaceContainerHighest
                                    : colors.primaryContainer,
                              ),
                              icon: AppSvgIcon(
                                name: 'filter-horizontal',
                                size: 22,
                                color:
                                    _priorityFilter == null &&
                                        _dueDateRange == null
                                    ? colors.onSurfaceVariant
                                    : colors.onPrimaryContainer,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpace.sm),
                        SizedBox(
                          height: 48,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                for (final filter in _TaskFilter.values)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      right: AppSpace.xs,
                                    ),
                                    child: ChoiceChip(
                                      key: ValueKey('filter-${filter.name}'),
                                      label: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: AppSpace.xxs,
                                        ),
                                        child: Text(_filterLabel(filter)),
                                      ),
                                      labelStyle: Theme.of(context)
                                          .textTheme
                                          .labelLarge
                                          ?.copyWith(
                                            color: _filter == filter
                                                ? colors.onPrimaryContainer
                                                : colors.onSurfaceVariant,
                                          ),
                                      selected: _filter == filter,
                                      onSelected: (_) {
                                        if (_filter == filter) return;
                                        setState(() => _filter = filter);
                                        _searchDebounce?.cancel();
                                        unawaited(
                                          _loadTasks(resetScroll: true),
                                        );
                                      },
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpace.md),
                        SectionHeading(
                          title: resultHeading,
                          actionLabel: '',
                          onAction: _openCreateTask,
                        ),
                      ],
                    ),
                  ),
                ),
                if (isInitialLoading)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(AppSpace.xl),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  )
                else if (hasInitialError)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(top: AppSpace.md),
                      child: TaskLoadErrorPanel(
                        message: pageState.errorMessage!,
                        onRetry: () => unawaited(_loadTasks()),
                      ),
                    ),
                  )
                else if (showCompletedGroup)
                  ..._buildAllTaskGroups(
                    context,
                    pendingItems: pendingItems,
                    completedItems: completedItems,
                  )
                else if (pageState.items.isEmpty)
                  SliverToBoxAdapter(
                    child: EmptyState(
                      icon: isUnfiltered
                          ? Icons.check_circle_outline
                          : Icons.search_off_outlined,
                      title: isUnfiltered
                          ? 'Chưa có công việc nào'
                          : 'Không tìm thấy công việc',
                      message: isUnfiltered
                          ? 'Tạo công việc đầu tiên để bắt đầu sắp xếp việc cần làm.'
                          : 'Thử thay đổi từ khóa hoặc bộ lọc đang chọn.',
                      actionLabel: isUnfiltered ? 'Tạo công việc' : null,
                      onAction: isUnfiltered ? _openCreateTask : null,
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.only(top: AppSpace.xs),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final task = pageState.items[index];

                        return Padding(
                          padding: const EdgeInsets.only(bottom: AppSpace.sm),
                          child: TaskCard(
                            task: task,
                            onTap: () => _openTaskDetails(task),
                            onToggle: () => _toggleTask(task),
                          ),
                        );
                      }, childCount: pageState.items.length),
                    ),
                  ),
                if (pageState.isLoadingMore)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpace.lg),
                      child: Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                  )
                else if (pageState.loadMoreErrorMessage != null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpace.md,
                      ),
                      child: Column(
                        children: [
                          Text(
                            pageState.loadMoreErrorMessage!,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: colors.error),
                            textAlign: TextAlign.center,
                          ),
                          TextButton.icon(
                            onPressed: _retryLoadMore,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Thử tải lại'),
                          ),
                        ],
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
    );
  }

  List<Widget> _buildAllTaskGroups(
    BuildContext context, {
    required List<TaskModel> pendingItems,
    required List<TaskModel> completedItems,
  }) {
    final slivers = <Widget>[];
    if (pendingItems.isEmpty) {
      slivers.add(
        SliverToBoxAdapter(
          child: EmptyState(
            icon: Icons.check_circle_outline,
            title: 'Chưa có công việc nào',
            message: 'Tạo công việc đầu tiên để bắt đầu sắp xếp việc cần làm.',
            actionLabel: 'Tạo công việc',
            onAction: _openCreateTask,
          ),
        ),
      );
    }
    final now = nowInAppTime();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final overdue = <TaskModel>[];
    final dueToday = <TaskModel>[];
    final upcoming = <TaskModel>[];
    final undated = <TaskModel>[];
    for (final task in pendingItems) {
      final dueDate = taskCalendarDate(task);
      if (dueDate == null) {
        undated.add(task);
      } else if (dueDate.isBefore(today)) {
        overdue.add(task);
      } else if (dueDate.isBefore(tomorrow)) {
        dueToday.add(task);
      } else {
        upcoming.add(task);
      }
    }
    slivers.addAll([
      _taskCards([...overdue, ...dueToday, ...upcoming, ...undated]),
    ]);
    final pageState = ref.watch(taskScreenTaskProvider);
    slivers.add(
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(top: AppSpace.sm, bottom: AppSpace.xs),
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              key: const ValueKey('completed-tasks-group'),
              title: Text(
                'Đã hoàn thành (${pageState.completedLoaded ? pageState.completedTotalItems : '…'})',
              ),
              trailing: Icon(
                _isCompletedGroupExpanded
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded,
              ),
              onTap: () {
                setState(
                  () => _isCompletedGroupExpanded = !_isCompletedGroupExpanded,
                );
                if (_isCompletedGroupExpanded) {
                  unawaited(
                    ref
                        .read(taskScreenTaskProvider.notifier)
                        .loadCompletedGroup(),
                  );
                }
              },
            ),
          ),
        ),
      ),
    );
    if (_isCompletedGroupExpanded && completedItems.isNotEmpty) {
      slivers.add(_taskCards(completedItems));
    }
    if (_isCompletedGroupExpanded && pageState.isLoadingCompleted) {
      slivers.add(
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(AppSpace.md),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
        ),
      );
    } else if (_isCompletedGroupExpanded &&
        pageState.loadMoreErrorMessage != null) {
      slivers.add(
        SliverToBoxAdapter(
          child: TextButton.icon(
            onPressed: () => unawaited(
              pageState.completedLoaded
                  ? ref
                        .read(taskScreenTaskProvider.notifier)
                        .loadMoreCompleted()
                  : ref
                        .read(taskScreenTaskProvider.notifier)
                        .loadCompletedGroup(),
            ),
            icon: const Icon(Icons.refresh),
            label: const Text('Thử tải lại'),
          ),
        ),
      );
    } else if (_isCompletedGroupExpanded &&
        pageState.completedLoaded &&
        completedItems.isEmpty) {
      slivers.add(
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpace.md),
            child: Text('Chưa có công việc nào hoàn thành.'),
          ),
        ),
      );
    }
    if (_isCompletedGroupExpanded && pageState.completedHasNextPage) {
      slivers.add(
        SliverToBoxAdapter(
          child: TextButton(
            onPressed: pageState.isLoadingCompleted
                ? null
                : () => unawaited(
                    ref
                        .read(taskScreenTaskProvider.notifier)
                        .loadMoreCompleted(),
                  ),
            child: const Text('Tải thêm việc đã hoàn thành'),
          ),
        ),
      );
    }
    return slivers;
  }

  Widget _taskCards(List<TaskModel> tasks) {
    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final task = tasks[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpace.sm),
          child: TaskCard(
            task: task,
            onTap: () => _openTaskDetails(task),
            onToggle: () => _toggleTask(task),
          ),
        );
      }, childCount: tasks.length),
    );
  }

  void _onSearchChanged(String _) {
    setState(() {});
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      unawaited(_loadTasks(resetScroll: true));
    });
  }

  Future<void> _loadTasks({bool resetScroll = false}) async {
    if (resetScroll) _scrollToTop();

    final dateFilter = _dateFilterParameters();
    await ref
        .read(taskScreenTaskProvider.notifier)
        .loadInitial(
          search: _searchController.text,
          priority: _priorityFilter,
          isCompleted: dateFilter.isCompleted,
          dueFrom: dateFilter.dueFrom,
          dueBefore: dateFilter.dueBefore,
        );

    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _onScroll();
    });
  }

  Future<void> _showPriorityFilter() async {
    final result =
        await showModalBottomSheet<
          ({TaskPriority? priority, DateTimeRange? dueDateRange, bool cleared})
        >(
          context: context,
          showDragHandle: true,
          isScrollControlled: true,
          builder: (_) => _TaskFilterSheet(
            initialPriority: _priorityFilter,
            initialDateRange: _dueDateRange,
          ),
        );

    if (result == null || !mounted) return;
    if (result.cleared) {
      if (_priorityFilter == null && _dueDateRange == null) return;
      setState(() {
        _priorityFilter = null;
        _dueDateRange = null;
      });
    } else {
      if (_priorityFilter == result.priority &&
          _dueDateRange == result.dueDateRange) {
        return;
      }
      setState(() {
        _priorityFilter = result.priority;
        _dueDateRange = result.dueDateRange;
      });
    }

    _searchDebounce?.cancel();
    unawaited(_loadTasks(resetScroll: true));
  }

  String _priorityLabel(TaskPriority priority) => switch (priority) {
    TaskPriority.low => 'Thấp',
    TaskPriority.medium => 'Trung bình',
    TaskPriority.high => 'Cao',
  };

  ({bool? isCompleted, String? dueFrom, String? dueBefore})
  _dateFilterParameters() {
    if (_dueDateRange case final range?) {
      return (
        isCompleted: null,
        dueFrom: _isoWithLocalOffset(
          DateTime(range.start.year, range.start.month, range.start.day),
        ),
        dueBefore: _isoWithLocalOffset(
          DateTime(range.end.year, range.end.month, range.end.day + 1),
        ),
      );
    }

    // Task filters are business-date filters and must use Vietnam time.
    final now = nowInAppTime();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = DateTime(now.year, now.month, now.day + 1);

    return switch (_filter) {
      _TaskFilter.all => (isCompleted: null, dueFrom: null, dueBefore: null),
      _TaskFilter.today => (
        isCompleted: null,
        dueFrom: _isoWithLocalOffset(today),
        dueBefore: _isoWithLocalOffset(tomorrow),
      ),
      _TaskFilter.upcoming => (
        isCompleted: null,
        dueFrom: _isoWithLocalOffset(tomorrow),
        dueBefore: null,
      ),
      _TaskFilter.completed => (
        isCompleted: true,
        dueFrom: null,
        dueBefore: null,
      ),
    };
  }

  String _isoWithLocalOffset(DateTime date) {
    final base = date.toIso8601String();
    final offset = date.timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final absoluteMinutes = offset.inMinutes.abs();
    final hours = (absoluteMinutes ~/ 60).toString().padLeft(2, '0');
    final minutes = (absoluteMinutes % 60).toString().padLeft(2, '0');
    return '$base$sign$hours:$minutes';
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.extentAfter > _loadMoreThreshold) return;

    final state = ref.read(taskScreenTaskProvider);
    if (state.isLoading ||
        state.isLoadingMore ||
        !state.hasNextPage ||
        state.loadMoreErrorMessage != null) {
      return;
    }

    unawaited(ref.read(taskScreenTaskProvider.notifier).loadMore());
  }

  Future<void> _retryLoadMore() async {
    await ref.read(taskScreenTaskProvider.notifier).loadMore();
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _onScroll();
    });
  }

  void _scrollToTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) _scrollController.jumpTo(0);
    });
  }

  String _filterLabel(_TaskFilter filter) {
    return switch (filter) {
      _TaskFilter.all => 'Tất cả',
      _TaskFilter.today => 'Hôm nay',
      _TaskFilter.upcoming => 'Sắp tới',
      _TaskFilter.completed => 'Đã hoàn thành',
    };
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchController.clear();
    FocusScope.of(context).unfocus();
    setState(() {});
    unawaited(_loadTasks(resetScroll: true));
  }

  Future<void> _openTaskDetails(TaskModel task) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TaskDetailsScreen(taskId: task.id),
      ),
    );
  }

  Future<void> _toggleTask(TaskModel task) async {
    _tasksBeingToggled.add(task.id);
    try {
      final success = await ref
          .read(taskProvider.notifier)
          .toggleTask(task.id, knownTask: task);
      if (!success || !mounted) return;

      await ref.read(taskScreenTaskProvider.notifier).reload();
    } finally {
      _tasksBeingToggled.remove(task.id);
    }
  }

  void _openCreateTask() {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const TaskFormScreen()));
  }
}

class _TaskFilterSheet extends StatefulWidget {
  const _TaskFilterSheet({
    required this.initialPriority,
    required this.initialDateRange,
  });

  final TaskPriority? initialPriority;
  final DateTimeRange? initialDateRange;

  @override
  State<_TaskFilterSheet> createState() => _TaskFilterSheetState();
}

class _TaskFilterSheetState extends State<_TaskFilterSheet> {
  late TaskPriority? _priority = widget.initialPriority;
  late DateTimeRange? _dateRange = widget.initialDateRange;

  Future<void> _selectSingleDate() async {
    final now = DateTime.now();
    final initialDate = _dateRange?.start ?? now;
    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 20),
      helpText: 'Chọn ngày nhắc',
    );
    if (date == null || !mounted) return;
    setState(() => _dateRange = DateTimeRange(start: date, end: date));
  }

  Future<void> _selectDateRange() async {
    final now = DateTime.now();
    final initial =
        _dateRange != null && _dateRange!.start.isBefore(_dateRange!.end)
        ? _dateRange!
        : null;
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 20),
      initialDateRange: initial,
      helpText: 'Chọn khoảng ngày nhắc',
    );
    if (range == null || !mounted) return;
    setState(() => _dateRange = range);
  }

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.lg,
                  0,
                  AppSpace.lg,
                  AppSpace.md,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Bộ lọc công việc', style: theme.textTheme.titleLarge),
                    const SizedBox(height: AppSpace.xs),
                    Text(
                      'Thu hẹp danh sách theo mức độ ưu tiên và ngày nhắc.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpace.lg),
                    _sectionHeading(
                      context,
                      icon: Icons.flag_outlined,
                      title: 'Mức độ ưu tiên',
                      subtitle: 'Chọn một mức',
                    ),
                    const SizedBox(height: AppSpace.sm),
                    Wrap(
                      spacing: AppSpace.xs,
                      runSpacing: AppSpace.xs,
                      children: [
                        _priorityChip(context, null, 'Tất cả'),
                        for (final priority in TaskPriority.values)
                          _priorityChip(
                            context,
                            priority,
                            _priorityLabel(priority),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpace.lg),
                    _sectionHeading(
                      context,
                      icon: Icons.event_outlined,
                      title: 'Ngày nhắc',
                      subtitle: 'Lọc theo một ngày hoặc một khoảng ngày',
                    ),
                    const SizedBox(height: AppSpace.sm),
                    Row(
                      children: [
                        Expanded(
                          child: _dateOptionButton(
                            context,
                            icon: Icons.calendar_today_outlined,
                            title: 'Một ngày',
                            value: _singleDateValue,
                            selected:
                                _dateRange != null &&
                                _dateRange!.start.isAtSameMomentAs(
                                  _dateRange!.end,
                                ),
                            onPressed: _selectSingleDate,
                          ),
                        ),
                        const SizedBox(width: AppSpace.sm),
                        Expanded(
                          child: _dateOptionButton(
                            context,
                            icon: Icons.date_range_outlined,
                            title: 'Khoảng ngày',
                            value: _dateRangeValue,
                            selected:
                                _dateRange != null &&
                                _dateRange!.start.isBefore(_dateRange!.end),
                            onPressed: _selectDateRange,
                          ),
                        ),
                      ],
                    ),
                    if (_dateRange != null) ...[
                      const SizedBox(height: AppSpace.xs),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () => setState(() => _dateRange = null),
                          icon: const Icon(Icons.close_rounded, size: 18),
                          label: const Text('Xóa ngày'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Divider(height: 1, color: colors.outlineVariant),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.lg,
                AppSpace.sm,
                AppSpace.lg,
                AppSpace.md,
              ),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(
                      context,
                    ).pop((priority: null, dueDateRange: null, cleared: true)),
                    child: const Text('Xóa tất cả'),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: () => Navigator.of(context).pop((
                      priority: _priority,
                      dueDateRange: _dateRange,
                      cleared: false,
                    )),
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Áp dụng'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeading(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: colors.primary),
        const SizedBox(width: AppSpace.xs),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleMedium),
              const SizedBox(height: AppSpace.xxs),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String get _singleDateValue =>
      _dateRange != null && _dateRange!.start.isAtSameMomentAs(_dateRange!.end)
      ? _formatDate(_dateRange!.start)
      : 'Chọn ngày nhắc';

  String get _dateRangeValue =>
      _dateRange != null && _dateRange!.start.isBefore(_dateRange!.end)
      ? '${_formatDate(_dateRange!.start)} – ${_formatDate(_dateRange!.end)}'
      : 'Chọn khoảng';

  Widget _dateOptionButton(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
    required bool selected,
    required VoidCallback onPressed,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: selected ? colors.primaryContainer : colors.surface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          constraints: const BoxConstraints(minHeight: 88),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.sm,
            vertical: AppSpace.sm,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: selected ? colors.primary : colors.outlineVariant,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                color: selected ? colors.primary : colors.onSurfaceVariant,
              ),
              const SizedBox(height: AppSpace.xs),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? colors.onPrimaryContainer
                      : colors.onSurface,
                ),
              ),
              const SizedBox(height: AppSpace.xxs),
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: selected
                      ? colors.onPrimaryContainer
                      : colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _priorityChip(
    BuildContext context,
    TaskPriority? priority,
    String label,
  ) {
    final selected = _priority == priority;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _priority = priority),
      avatar: selected ? const Icon(Icons.check_rounded, size: 18) : null,
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.xs),
      labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: selected
            ? Theme.of(context).colorScheme.onPrimaryContainer
            : Theme.of(context).colorScheme.onSurfaceVariant,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
    );
  }

  String _priorityLabel(TaskPriority priority) => switch (priority) {
    TaskPriority.low => 'Thấp',
    TaskPriority.medium => 'Trung bình',
    TaskPriority.high => 'Cao',
  };
}
