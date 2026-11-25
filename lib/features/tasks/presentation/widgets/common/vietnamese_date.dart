/// Vietnamese date labels used by the task UI without an external dependency.
abstract final class VietnameseDate {
  static const _weekdays = [
    'Thứ Hai',
    'Thứ Ba',
    'Thứ Tư',
    'Thứ Năm',
    'Thứ Sáu',
    'Thứ Bảy',
    'Chủ nhật',
  ];
  static const _shortWeekdays = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
  static String full(DateTime date) =>
      '${_weekdays[date.weekday - 1]}, ngày ${_twoDigits(date.day)} '
      'tháng ${_twoDigits(date.month)} năm ${date.year}';

  static String numeric(DateTime date) =>
      '${_twoDigits(date.day)}/${_twoDigits(date.month)}/${date.year}';

  static String monthYear(DateTime date) =>
      'Tháng ${date.month} năm ${date.year}';

  static String shortWeekday(int mondayBasedIndex) =>
      _shortWeekdays[mondayBasedIndex];

  static String _twoDigits(int value) => value.toString().padLeft(2, '0');
}
