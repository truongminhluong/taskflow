import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

const String appTimeZone = 'Asia/Ho_Chi_Minh';

bool _initialized = false;

void initializeAppTimeZone() {
  if (_initialized) return;
  tz_data.initializeTimeZones();
  _initialized = true;
}

tz.Location get appLocation {
  initializeAppTimeZone();
  return tz.getLocation(appTimeZone);
}

DateTime utcToAppTime(DateTime utcInstant) {
  final instant = utcInstant.toUtc();
  return tz.TZDateTime.from(instant, appLocation);
}

DateTime appTimeToUtc({
  required int year,
  required int month,
  required int day,
  required int hour,
  required int minute,
  int second = 0,
  int millisecond = 0,
  int microsecond = 0,
}) {
  final local = tz.TZDateTime(
    appLocation,
    year,
    month,
    day,
    hour,
    minute,
    second,
    millisecond,
    microsecond,
  );
  return local.toUtc();
}

tz.TZDateTime appTimeFromComponents({
  required int year,
  required int month,
  required int day,
  required int hour,
  required int minute,
}) => tz.TZDateTime(appLocation, year, month, day, hour, minute);

tz.TZDateTime nowInAppTime() => tz.TZDateTime.now(appLocation);

String dateOnly(String value) => value;
