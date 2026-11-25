import 'package:flutter_test/flutter_test.dart';
import 'package:task_flow_v2/core/time/app_time_zone.dart';

void main() {
  setUp(initializeAppTimeZone);

  test('converts UTC to Vietnam time without changing the instant', () {
    final value = utcToAppTime(DateTime.utc(2026, 11, 23, 2));
    expect(value.year, 2026);
    expect(value.month, 11);
    expect(value.day, 23);
    expect(value.hour, 9);
    expect(value.minute, 0);
    expect(value.toUtc(), DateTime.utc(2026, 11, 23, 2));
  });

  test('converts Vietnam wall-clock components to UTC', () {
    expect(
      appTimeToUtc(year: 2026, month: 11, day: 23, hour: 9, minute: 0),
      DateTime.utc(2026, 11, 23, 2),
    );
  });

  test('handles day, month, and year boundaries', () {
    final monthBoundary = utcToAppTime(DateTime.utc(2026, 11, 22, 17, 30));
    expect(monthBoundary.toUtc(), DateTime.utc(2026, 11, 22, 17, 30));
    expect(monthBoundary.day, 23);
    final yearBoundary = utcToAppTime(DateTime.utc(2026, 12, 31, 17));
    expect(yearBoundary.toUtc(), DateTime.utc(2026, 12, 31, 17));
    expect(yearBoundary.year, 2027);
  });

  test('returns current time in the application timezone', () {
    final now = nowInAppTime();
    expect(now.location.name, appTimeZone);
    expect(
      now.toUtc().difference(DateTime.now().toUtc()).inSeconds.abs(),
      lessThan(2),
    );
  });

  test('keeps date-only strings unchanged', () {
    expect(dateOnly('2026-11-23'), '2026-11-23');
  });
}
