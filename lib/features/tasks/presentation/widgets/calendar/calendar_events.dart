import 'package:vnlunar/vnlunar.dart';

class CalendarEvent {
  const CalendarEvent._({
    required this.name,
    this.month,
    this.day,
    this.lunarMonth,
    this.lunarDay,
  });

  const CalendarEvent.solar({
    required String name,
    required int month,
    required int day,
  }) : this._(name: name, month: month, day: day);

  const CalendarEvent.lunar({
    required String name,
    required int month,
    required int day,
  }) : this._(name: name, lunarMonth: month, lunarDay: day);

  final String name;
  final int? month;
  final int? day;
  final int? lunarMonth;
  final int? lunarDay;
}

/// National observances and widely celebrated Vietnamese cultural occasions.
/// Variable-date public holiday make-up days and local festivals are excluded.
const _calendarEvents = <CalendarEvent>[
  CalendarEvent.solar(name: 'Tết Dương lịch', month: 1, day: 1),
  CalendarEvent.solar(name: 'Ngày Valentine', month: 2, day: 14),
  CalendarEvent.solar(name: 'Ngày Thầy thuốc Việt Nam', month: 2, day: 27),
  CalendarEvent.solar(name: 'Ngày Quốc tế Phụ nữ', month: 3, day: 8),
  CalendarEvent.solar(
    name: 'Ngày thành lập Đoàn TNCS Hồ Chí Minh',
    month: 3,
    day: 26,
  ),
  CalendarEvent.solar(
    name: 'Ngày Sách và Văn hóa đọc Việt Nam',
    month: 4,
    day: 21,
  ),
  CalendarEvent.solar(name: 'Ngày Giải phóng miền Nam', month: 4, day: 30),
  CalendarEvent.solar(name: 'Ngày Quốc tế Lao động', month: 5, day: 1),
  CalendarEvent.solar(name: 'Chiến thắng Điện Biên Phủ', month: 5, day: 7),
  CalendarEvent.solar(
    name: 'Ngày sinh Chủ tịch Hồ Chí Minh',
    month: 5,
    day: 19,
  ),
  CalendarEvent.solar(name: 'Ngày Quốc tế Thiếu nhi', month: 6, day: 1),
  CalendarEvent.solar(
    name: 'Ngày Báo chí Cách mạng Việt Nam',
    month: 6,
    day: 21,
  ),
  CalendarEvent.solar(name: 'Ngày Gia đình Việt Nam', month: 6, day: 28),
  CalendarEvent.solar(name: 'Ngày Thương binh - Liệt sĩ', month: 7, day: 27),
  CalendarEvent.solar(name: 'Cách mạng Tháng Tám', month: 8, day: 19),
  CalendarEvent.solar(name: 'Quốc khánh Việt Nam', month: 9, day: 2),
  CalendarEvent.solar(name: 'Ngày Quốc tế Người cao tuổi', month: 10, day: 1),
  CalendarEvent.solar(name: 'Ngày Giải phóng Thủ đô', month: 10, day: 10),
  CalendarEvent.solar(name: 'Ngày Doanh nhân Việt Nam', month: 10, day: 13),
  CalendarEvent.solar(name: 'Ngày Phụ nữ Việt Nam', month: 10, day: 20),
  CalendarEvent.solar(name: 'Ngày Nhà giáo Việt Nam', month: 11, day: 20),
  CalendarEvent.solar(
    name: 'Ngày thành lập Quân đội nhân dân Việt Nam',
    month: 12,
    day: 22,
  ),
  CalendarEvent.solar(name: 'Đêm Giáng sinh', month: 12, day: 24),
  CalendarEvent.solar(name: 'Lễ Giáng sinh', month: 12, day: 25),
  CalendarEvent.solar(name: 'Giao thừa Dương lịch', month: 12, day: 31),
  CalendarEvent.lunar(name: 'Tết Nguyên Đán', month: 1, day: 1),
  CalendarEvent.lunar(name: 'Mùng 2 Tết', month: 1, day: 2),
  CalendarEvent.lunar(name: 'Mùng 3 Tết', month: 1, day: 3),
  CalendarEvent.lunar(
    name: 'Tết Nguyên tiêu (Rằm tháng Giêng)',
    month: 1,
    day: 15,
  ),
  CalendarEvent.lunar(name: 'Tết Hàn thực', month: 3, day: 3),
  CalendarEvent.lunar(name: 'Giỗ Tổ Hùng Vương', month: 3, day: 10),
  CalendarEvent.lunar(name: 'Lễ Phật Đản', month: 4, day: 15),
  CalendarEvent.lunar(name: 'Tết Đoan Ngọ', month: 5, day: 5),
  CalendarEvent.lunar(name: 'Vu Lan (Rằm tháng Bảy)', month: 7, day: 15),
  CalendarEvent.lunar(name: 'Tết Trung Thu', month: 8, day: 15),
  CalendarEvent.lunar(name: 'Tết Hạ Nguyên', month: 10, day: 15),
  CalendarEvent.lunar(name: 'Ông Công, Ông Táo', month: 12, day: 23),
];

List<String> calendarEventsFor(DateTime date) {
  final events = <String>[];

  for (final event in _calendarEvents) {
    if (event.month != null &&
        event.day != null &&
        event.month == date.month &&
        event.day == date.day) {
      events.add(event.name);
    }
  }

  for (final lunarYear in [date.year - 1, date.year, date.year + 1]) {
    for (final event in _calendarEvents.where(
      (event) => event.lunarMonth != null,
    )) {
      try {
        final solarDate = Lunar.date(
          lunarYear,
          event.lunarMonth!,
          event.lunarDay!,
        ).getSolar().toDateTime();
        if (_sameDay(solarDate, date)) events.add(event.name);
      } on ArgumentError {
        // The selected lunar date may not exist in an unsupported edge year.
      }
    }

    final lastDayOfLunarYear = _lastLunarMonthDay(lunarYear);
    if (lastDayOfLunarYear != null && _sameDay(lastDayOfLunarYear, date)) {
      events.add('Tất niên');
    }
  }

  return events;
}

DateTime? _lastLunarMonthDay(int lunarYear) {
  for (final day in [30, 29]) {
    try {
      return Lunar.date(lunarYear, 12, day).getSolar().toDateTime();
    } on ArgumentError {
      continue;
    }
  }
  return null;
}

bool _sameDay(DateTime first, DateTime second) =>
    first.year == second.year &&
    first.month == second.month &&
    first.day == second.day;
