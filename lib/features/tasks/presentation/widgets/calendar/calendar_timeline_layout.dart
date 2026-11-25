/// Vertical position and horizontal lane for a task in the daily timeline.
final class CalendarTimelinePlacement {
  const CalendarTimelinePlacement({
    required this.top,
    required this.column,
    required this.columnCount,
  });

  final double top;
  final int column;
  final int columnCount;
}

/// A display-only task group. Task indexes refer to the original input.
final class CalendarTimelineDisplayGroup {
  const CalendarTimelineDisplayGroup({
    required this.taskIndexes,
    required this.representativeTaskIndex,
    required this.top,
    required this.height,
    required this.column,
    required this.columnCount,
  });

  final List<int> taskIndexes;
  final int representativeTaskIndex;
  final double top;
  final double height;
  final int column;
  final int columnCount;

  bool get isGrouped => taskIndexes.length > 1;
  int get additionalTaskCount => taskIndexes.length - 1;
}

/// Packs visual task-card intervals into the fewest horizontal columns while
/// preserving each task's exact time-derived vertical position.
abstract final class CalendarTimelineLayout {
  static const cardTopSpacing = 5.0;
  static const cardBottomSpacing = 5.0;

  static List<CalendarTimelinePlacement> calculate({
    required List<DateTime> startTimes,
    required double pixelsPerHour,
    required double cardHeight,
    required double topInset,
    required double gap,
  }) {
    final items =
        [
          for (var index = 0; index < startTimes.length; index++)
            _TimelineItem(
              index: index,
              top: _topFor(
                startTimes[index],
                pixelsPerHour: pixelsPerHour,
                topInset: topInset,
              ),
            ),
        ]..sort((first, second) {
          final topOrder = first.top.compareTo(second.top);
          return topOrder == 0 ? first.index.compareTo(second.index) : topOrder;
        });

    final placements = List<CalendarTimelinePlacement?>.filled(
      startTimes.length,
      null,
    );

    var clusterStart = 0;
    while (clusterStart < items.length) {
      var clusterEnd = clusterStart + 1;
      var occupiedUntil = items[clusterStart].top + cardHeight + gap;

      while (clusterEnd < items.length &&
          items[clusterEnd].top < occupiedUntil) {
        occupiedUntil = items[clusterEnd].top + cardHeight + gap;
        clusterEnd++;
      }

      final columnEnds = <double>[];
      for (var itemIndex = clusterStart; itemIndex < clusterEnd; itemIndex++) {
        final item = items[itemIndex];
        final availableColumn = columnEnds.indexWhere((end) => end <= item.top);
        final column = availableColumn == -1
            ? columnEnds.length
            : availableColumn;

        if (column == columnEnds.length) {
          columnEnds.add(item.top + cardHeight + gap);
        } else {
          columnEnds[column] = item.top + cardHeight + gap;
        }

        placements[item.index] = CalendarTimelinePlacement(
          top: item.top,
          column: column,
          columnCount: 0,
        );
      }

      final columnCount = columnEnds.length;
      for (var itemIndex = clusterStart; itemIndex < clusterEnd; itemIndex++) {
        final item = items[itemIndex];
        final placement = placements[item.index]!;
        placements[item.index] = CalendarTimelinePlacement(
          top: placement.top,
          column: placement.column,
          columnCount: columnCount,
        );
      }

      clusterStart = clusterEnd;
    }

    return [for (final placement in placements) placement!];
  }

  /// Groups tasks by local calendar day and start hour.
  ///
  /// Group representatives are selected by descending priority rank, then
  /// earlier start time, then lexicographically smaller task ID. Every bucket
  /// occupies its full hour, including buckets with only one task.
  static List<CalendarTimelineDisplayGroup> groupByHour({
    required List<DateTime> startTimes,
    required List<int> priorityRanks,
    required List<String> taskIds,
    required double pixelsPerHour,
  }) {
    if (priorityRanks.length != startTimes.length ||
        taskIds.length != startTimes.length) {
      throw ArgumentError('Task metadata must match the start-time count.');
    }

    final indexesByHour = <(int, int, int, int), List<int>>{};
    for (var index = 0; index < startTimes.length; index++) {
      final time = startTimes[index];
      indexesByHour
          .putIfAbsent((time.year, time.month, time.day, time.hour), () => [])
          .add(index);
    }

    final groups = <CalendarTimelineDisplayGroup>[];
    for (final entry in indexesByHour.entries) {
      final indexes = List<int>.of(entry.value)
        ..sort((first, second) {
          final priorityOrder = priorityRanks[second].compareTo(
            priorityRanks[first],
          );
          if (priorityOrder != 0) return priorityOrder;
          final timeOrder = startTimes[first].compareTo(startTimes[second]);
          if (timeOrder != 0) return timeOrder;
          return taskIds[first].compareTo(taskIds[second]);
        });
      final hourStart = DateTime(
        entry.key.$1,
        entry.key.$2,
        entry.key.$3,
        entry.key.$4,
      );
      final representativeTaskIndex = indexes.first;
      final chronologicalIndexes = List<int>.of(indexes)
        ..sort((first, second) {
          final timeOrder = startTimes[first].compareTo(startTimes[second]);
          if (timeOrder != 0) return timeOrder;
          return taskIds[first].compareTo(taskIds[second]);
        });
      groups.add(
        CalendarTimelineDisplayGroup(
          taskIndexes: List.unmodifiable(chronologicalIndexes),
          representativeTaskIndex: representativeTaskIndex,
          top: hourStart.hour * pixelsPerHour + cardTopSpacing,
          height: pixelsPerHour - cardTopSpacing - cardBottomSpacing,
          column: 0,
          columnCount: 1,
        ),
      );
    }

    groups.sort((first, second) => first.top.compareTo(second.top));
    return _assignColumns(groups, 0);
  }

  static List<CalendarTimelineDisplayGroup> _assignColumns(
    List<CalendarTimelineDisplayGroup> groups,
    double gap,
  ) {
    final result = <CalendarTimelineDisplayGroup>[];
    var clusterStart = 0;
    while (clusterStart < groups.length) {
      var clusterEnd = clusterStart + 1;
      var occupiedUntil =
          groups[clusterStart].top + groups[clusterStart].height + gap;
      while (clusterEnd < groups.length &&
          groups[clusterEnd].top < occupiedUntil) {
        final next = groups[clusterEnd];
        occupiedUntil = occupiedUntil > next.top + next.height + gap
            ? occupiedUntil
            : next.top + next.height + gap;
        clusterEnd++;
      }

      final columnEnds = <double>[];
      final placements = <(CalendarTimelineDisplayGroup, int)>[];
      for (var index = clusterStart; index < clusterEnd; index++) {
        final group = groups[index];
        final availableColumn = columnEnds.indexWhere(
          (end) => end <= group.top,
        );
        final column = availableColumn == -1
            ? columnEnds.length
            : availableColumn;
        final end = group.top + group.height + gap;
        if (column == columnEnds.length) {
          columnEnds.add(end);
        } else {
          columnEnds[column] = end;
        }
        placements.add((group, column));
      }

      for (final (group, column) in placements) {
        result.add(
          CalendarTimelineDisplayGroup(
            taskIndexes: group.taskIndexes,
            representativeTaskIndex: group.representativeTaskIndex,
            top: group.top,
            height: group.height,
            column: column,
            columnCount: columnEnds.length,
          ),
        );
      }
      clusterStart = clusterEnd;
    }
    return result;
  }

  static double contentHeight({
    required double pixelsPerHour,
    required double cardHeight,
    required double topInset,
    required double gap,
  }) => 24 * pixelsPerHour + topInset + cardHeight + gap;

  static double _topFor(
    DateTime time, {
    required double pixelsPerHour,
    required double topInset,
  }) {
    final minutes = time.hour * 60 + time.minute + time.second / 60;
    return minutes / 60 * pixelsPerHour + topInset;
  }

  static double clampPixelsPerHour(
    double value, {
    required double minimum,
    required double maximum,
  }) {
    if (!value.isFinite || !minimum.isFinite || !maximum.isFinite) {
      throw ArgumentError('Zoom scale bounds and value must be finite.');
    }
    if (minimum <= 0 || maximum < minimum) {
      throw ArgumentError('Zoom scale bounds must be positive and ordered.');
    }
    return value.clamp(minimum, maximum);
  }
}

final class _TimelineItem {
  const _TimelineItem({required this.index, required this.top});

  final int index;
  final double top;
}
