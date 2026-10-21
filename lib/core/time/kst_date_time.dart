import 'package:intl/intl.dart';

/// 한국 표준시(KST, Asia/Seoul, UTC+9) 기준 DateTime 헬퍼.
///
/// 한국은 일광절약시를 쓰지 않으므로 UTC+9 고정 오프셋으로
/// **기기 타임존과 무관하게** 동일한 벽시계 시각을 얻습니다.
///
/// 에뮬레이터 타임존이 GMT/다른 지역으로 남아 있어도
/// [now] / [today] 는 PC·실기기와 같은 KST 날짜·시각을 반환합니다.
abstract final class KstDateTime {
  static const Duration offsetFromUtc = Duration(hours: 9);

  /// 현재 시각 (KST 벽시계). `isUtc == false` 인 naive DateTime.
  static DateTime now() {
    final utc = DateTime.now().toUtc();
    final kst = utc.add(offsetFromUtc);
    return DateTime(
      kst.year,
      kst.month,
      kst.day,
      kst.hour,
      kst.minute,
      kst.second,
      kst.millisecond,
      kst.microsecond,
    );
  }

  /// 오늘 0시 0분 (KST)
  static DateTime today() {
    final n = now();
    return DateTime(n.year, n.month, n.day);
  }

  /// `yyyy-MM-dd` (KST)
  static String todayKey([DateFormat? format]) {
    return (format ?? DateFormat('yyyy-MM-dd')).format(today());
  }

  /// 임의의 DateTime을 KST 벽시계로 변환
  static DateTime toKst(DateTime value) {
    final utc = value.isUtc ? value : value.toUtc();
    final kst = utc.add(offsetFromUtc);
    return DateTime(
      kst.year,
      kst.month,
      kst.day,
      kst.hour,
      kst.minute,
      kst.second,
      kst.millisecond,
      kst.microsecond,
    );
  }

  /// 날짜만 남김 (시·분·초 제거, KST 기준 입력이라고 가정)
  static DateTime dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  /// [a]·[b] 가 같은 KST 달력일인지
  static bool isSameDate(DateTime a, DateTime b) {
    final ka = dateOnly(toKst(a));
    final kb = dateOnly(toKst(b));
    return ka.year == kb.year && ka.month == kb.month && ka.day == kb.day;
  }

  /// 디버그용: 기기 로컬 vs KST 차이 확인
  static String debugSummary() {
    final device = DateTime.now();
    final kst = now();
    return 'device=${device.toIso8601String()} '
        '(isUtc=${device.isUtc}, offset=${device.timeZoneOffset})\n'
        'kst   =${kst.toIso8601String()} (UTC+9 wall clock)';
  }
}
