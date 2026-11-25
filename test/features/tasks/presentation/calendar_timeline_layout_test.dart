import 'package:flutter_test/flutter_test.dart';
import 'package:task_flow_v2/features/tasks/presentation/widgets/calendar/calendar_timeline_layout.dart';

void main() {
  group('CalendarTimelineLayout', () {
    const pixelsPerHour = 72.0;
    const cardHeight = 60.0;
    const topInset = 6.0;
    const gap = 4.0;

    test('clamps zoom values to finite configured bounds', () {
      expect(
        CalendarTimelineLayout.clampPixelsPerHour(
          12,
          minimum: 36,
          maximum: 144,
        ),
        36,
      );
      expect(
        CalendarTimelineLayout.clampPixelsPerHour(
          300,
          minimum: 36,
          maximum: 144,
        ),
        144,
      );
      expect(
        CalendarTimelineLayout.clampPixelsPerHour(
          72,
          minimum: 36,
          maximum: 144,
        ),
        72,
      );
      expect(
        () => CalendarTimelineLayout.clampPixelsPerHour(
          double.infinity,
          minimum: 36,
          maximum: 144,
        ),
        throwsArgumentError,
      );
    });

    test('scales a task position and timeline height proportionally', () {
      final time = DateTime(2026, 11, 5, 9, 30);
      final base = CalendarTimelineLayout.calculate(
        startTimes: [time],
        pixelsPerHour: 72,
        cardHeight: cardHeight,
        topInset: topInset,
        gap: gap,
      ).single;
      final zoomed = CalendarTimelineLayout.calculate(
        startTimes: [time],
        pixelsPerHour: 108,
        cardHeight: cardHeight,
        topInset: topInset,
        gap: gap,
      ).single;

      expect(
        zoomed.top - topInset,
        closeTo((base.top - topInset) * 1.5, 0.001),
      );
      expect(
        CalendarTimelineLayout.contentHeight(
          pixelsPerHour: 108,
          cardHeight: cardHeight,
          topInset: topInset,
          gap: gap,
        ),
        greaterThan(
          CalendarTimelineLayout.contentHeight(
            pixelsPerHour: 72,
            cardHeight: cardHeight,
            topInset: topInset,
            gap: gap,
          ),
        ),
      );
      expect(time, DateTime(2026, 11, 5, 9, 30));
    });

    test(
      'keeps 30-minute events at their actual times in separate columns',
      () {
        final placements = CalendarTimelineLayout.calculate(
          startTimes: [
            DateTime(2026, 11, 5, 15, 28),
            DateTime(2026, 11, 5, 15, 58),
          ],
          pixelsPerHour: pixelsPerHour,
          cardHeight: cardHeight,
          topInset: topInset,
          gap: gap,
        );

        expect(placements[0].top, closeTo(15.0 * 72 + 28 / 60 * 72 + 6, 0.001));
        expect(placements[1].top - placements[0].top, closeTo(36, 0.001));
        expect(placements.map((placement) => placement.column), [0, 1]);
        expect(placements.map((placement) => placement.columnCount), [2, 2]);
      },
    );

    test('places 45-minute events side by side when their cards collide', () {
      final placements = CalendarTimelineLayout.calculate(
        startTimes: [DateTime(2026, 11, 5, 15), DateTime(2026, 11, 5, 15, 45)],
        pixelsPerHour: pixelsPerHour,
        cardHeight: cardHeight,
        topInset: topInset,
        gap: gap,
      );

      expect(placements.map((placement) => placement.column), [0, 1]);
      expect(placements.map((placement) => placement.top), [
        closeTo(15 * 72 + 6, 0.001),
        closeTo(15 * 72 + 45 / 60 * 72 + 6, 0.001),
      ]);
    });

    test('assigns simultaneous events separate columns', () {
      final placements = CalendarTimelineLayout.calculate(
        startTimes: List.filled(3, DateTime(2026, 11, 5, 12, 30)),
        pixelsPerHour: pixelsPerHour,
        cardHeight: cardHeight,
        topInset: topInset,
        gap: gap,
      );

      expect(placements.map((placement) => placement.column), [0, 1, 2]);
      expect(placements.map((placement) => placement.columnCount), [3, 3, 3]);
    });

    test('reuses a column when visual intervals no longer overlap', () {
      final placements = CalendarTimelineLayout.calculate(
        startTimes: [DateTime(2026, 11, 5, 9), DateTime(2026, 11, 5, 10, 5)],
        pixelsPerHour: pixelsPerHour,
        cardHeight: cardHeight,
        topInset: topInset,
        gap: gap,
      );

      expect(placements.map((placement) => placement.column), [0, 0]);
      expect(placements.map((placement) => placement.columnCount), [1, 1]);
    });

    test('reuses columns across a dense sequence of events', () {
      final placements = CalendarTimelineLayout.calculate(
        startTimes: [
          DateTime(2026, 11, 5, 9),
          DateTime(2026, 11, 5, 9, 30),
          DateTime(2026, 11, 5, 10),
        ],
        pixelsPerHour: pixelsPerHour,
        cardHeight: cardHeight,
        topInset: topInset,
        gap: gap,
      );

      expect(placements.map((placement) => placement.column), [0, 1, 0]);
      expect(placements.map((placement) => placement.columnCount), [2, 2, 2]);
    });

    test('retains input order and time positions for unsorted times', () {
      final placements = CalendarTimelineLayout.calculate(
        startTimes: [
          DateTime(2026, 11, 5, 16, 10),
          DateTime(2026, 11, 5, 15, 28),
        ],
        pixelsPerHour: pixelsPerHour,
        cardHeight: cardHeight,
        topInset: topInset,
        gap: gap,
      );

      expect(placements[0].top, closeTo(16 * 72 + 10 / 60 * 72 + 6, 0.001));
      expect(placements[1].top, closeTo(15 * 72 + 28 / 60 * 72 + 6, 0.001));
      expect(placements.map((placement) => placement.columnCount), [2, 2]);
    });

    test('groups by local day and hour boundaries', () {
      final times = [
        DateTime(2026, 11, 5, 9, 15),
        DateTime(2026, 11, 5, 9, 30),
        DateTime(2026, 11, 5, 9, 55),
        DateTime(2026, 11, 5, 10),
        DateTime(2026, 11, 6, 9, 20),
      ];
      final groups = CalendarTimelineLayout.groupByHour(
        startTimes: times,
        priorityRanks: [2, 3, 1, 3, 3],
        taskIds: ['b', 'a', 'c', 'd', 'e'],
        pixelsPerHour: 72,
      );

      final firstHour = groups.singleWhere(
        (group) => group.taskIndexes.contains(0),
      );
      final nextHour = groups.singleWhere(
        (group) => group.taskIndexes.contains(3),
      );
      final nextDaySameHour = groups.singleWhere(
        (group) => group.taskIndexes.contains(4),
      );
      expect(firstHour.taskIndexes, [0, 1, 2]);
      expect(firstHour.representativeTaskIndex, 1);
      expect(firstHour.top, 9 * 72 + 5);
      expect(firstHour.height, 62);
      expect(firstHour.top + firstHour.height, 10 * 72 - 5);
      expect(firstHour.additionalTaskCount, 2);
      expect(nextHour.top, 10 * 72 + 5);
      expect(nextHour.height, 62);
      expect(nextDaySameHour.taskIndexes, [4]);
      expect(groups.expand((group) => group.taskIndexes).toSet(), {
        0,
        1,
        2,
        3,
        4,
      });
      expect(groups.expand((group) => group.taskIndexes).length, times.length);
    });

    test('selects representative by priority, time, then task ID', () {
      final groups = CalendarTimelineLayout.groupByHour(
        startTimes: [
          DateTime(2026, 11, 5, 9, 30),
          DateTime(2026, 11, 5, 9, 15),
          DateTime(2026, 11, 5, 9, 15),
        ],
        priorityRanks: [3, 3, 3],
        taskIds: ['z-task', 'b-task', 'a-task'],
        pixelsPerHour: 72,
      );

      expect(groups.single.representativeTaskIndex, 2);
      expect(groups.single.taskIndexes, [2, 1, 0]);
    });

    test('single tasks occupy their entire starting hour at every zoom', () {
      for (final pixelsPerHour in [36.0, 72.0, 144.0]) {
        for (final time in [
          DateTime(2026, 11, 5, 9, 15),
          DateTime(2026, 11, 5, 9, 55),
          DateTime(2026, 11, 5, 10),
        ]) {
          final single = CalendarTimelineLayout.groupByHour(
            startTimes: [time],
            priorityRanks: [2],
            taskIds: ['single'],
            pixelsPerHour: pixelsPerHour,
          ).single;

          expect(single.isGrouped, isFalse);
          final hourTop = time.hour * pixelsPerHour;
          expect(single.top, hourTop + CalendarTimelineLayout.cardTopSpacing);
          expect(
            single.height,
            pixelsPerHour -
                CalendarTimelineLayout.cardTopSpacing -
                CalendarTimelineLayout.cardBottomSpacing,
          );
          expect(
            single.top + single.height,
            (time.hour + 1) * pixelsPerHour -
                CalendarTimelineLayout.cardBottomSpacing,
          );
        }
      }
    });

    test('hour-group geometry scales at 50, 100, and 200 percent', () {
      for (final pixelsPerHour in [36.0, 72.0, 144.0]) {
        final group = CalendarTimelineLayout.groupByHour(
          startTimes: [
            DateTime(2026, 11, 5, 9, 15),
            DateTime(2026, 11, 5, 9, 30),
          ],
          priorityRanks: [2, 3],
          taskIds: ['medium', 'high'],
          pixelsPerHour: pixelsPerHour,
        ).single;

        final single = CalendarTimelineLayout.groupByHour(
          startTimes: [DateTime(2026, 11, 5, 9, 15)],
          priorityRanks: [2],
          taskIds: ['single'],
          pixelsPerHour: pixelsPerHour,
        ).single;
        final expectedTop =
            9 * pixelsPerHour + CalendarTimelineLayout.cardTopSpacing;
        final expectedHeight =
            pixelsPerHour -
            CalendarTimelineLayout.cardTopSpacing -
            CalendarTimelineLayout.cardBottomSpacing;
        expect(group.top, expectedTop);
        expect(group.height, expectedHeight);
        expect(single.top, group.top);
        expect(single.height, group.height);
        expect(group.top + group.height, 10 * pixelsPerHour - 5);
      }
    });

    test('keeps first and last day events within the expanded timeline', () {
      final placements = CalendarTimelineLayout.calculate(
        startTimes: [
          DateTime(2026, 11, 5, 0, 5),
          DateTime(2026, 11, 5, 23, 59),
        ],
        pixelsPerHour: pixelsPerHour,
        cardHeight: cardHeight,
        topInset: topInset,
        gap: gap,
      );

      final timelineHeight = CalendarTimelineLayout.contentHeight(
        pixelsPerHour: pixelsPerHour,
        cardHeight: cardHeight,
        topInset: topInset,
        gap: gap,
      );

      expect(placements[0].top, greaterThanOrEqualTo(0));
      expect(placements[1].top + cardHeight, lessThanOrEqualTo(timelineHeight));
      expect(timelineHeight, greaterThan(24 * pixelsPerHour));
    });
  });
}
