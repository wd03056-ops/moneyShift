/// 캘린더용 date-only 연산 — DST·월말·윤년에서 Duration(days) 대신 사용
abstract final class DateOnly {
  DateOnly._();

  static DateTime of(DateTime d) => DateTime(d.year, d.month, d.day);

  /// 다음 달력일 (월말·윤년 자동 이월)
  static DateTime nextDay(DateTime d) {
    final day = of(d);
    return DateTime(day.year, day.month, day.day + 1);
  }

  /// [from]~[to] 포함 일 목록 (양끝 date-only, 순서 무관)
  /// [maxDays] 초과 시 앞에서부터 잘라 반환 (OOM·UI 지연 방지)
  static List<DateTime> daysInclusive(
    DateTime a,
    DateTime b, {
    int maxDays = 400,
  }) {
    final start = of(a);
    final end = of(b);
    final from = start.isBefore(end) ? start : end;
    final to = start.isBefore(end) ? end : start;
    final days = <DateTime>[];
    for (var d = from; !d.isAfter(to); d = nextDay(d)) {
      days.add(d);
      if (days.length >= maxDays) break;
    }
    return days;
  }

  /// 해당 월의 모든 일 (1일~말일, 윤년 2월 포함)
  static List<DateTime> daysInMonth(int year, int month) {
    final last = DateTime(year, month + 1, 0).day;
    return [for (var d = 1; d <= last; d++) DateTime(year, month, d)];
  }

  /// 같은 시각을 유지한 채 날짜만 교체
  static DateTime combine(DateTime date, {required int hour, required int minute}) {
    final d = of(date);
    return DateTime(d.year, d.month, d.day, hour, minute);
  }
}
