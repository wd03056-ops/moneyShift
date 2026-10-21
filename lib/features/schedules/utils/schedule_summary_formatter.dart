import 'package:intl/intl.dart';

import '../../../core/time/date_only.dart';
import '../../../models/schedule_model.dart';

/// 근무 배정 카드용 요약 유형
enum ScheduleSummaryKind {
  /// 매주 동일 요일·시간 반복
  weekly,

  /// 연속 기간
  range,

  /// 월/총 횟수 압축 요약 (개별 나열 대신)
  compact,

  /// 소수·이질 일정만 개별 (동일 시간대에서는 거의 사용하지 않음)
  individual,
}

/// [formatScheduleSummary] 결과 한 블록
class ScheduleSummaryBlock {
  const ScheduleSummaryBlock({
    required this.kind,
    required this.headline,
    this.detailLines = const [],
    this.previewCount = 3,
  });

  final ScheduleSummaryKind kind;

  /// 카드에 보이는 한 줄 요약
  final String headline;

  /// [individual] 전용 — 날짜별 줄 (동일 시간대에서는 비움)
  final List<String> detailLines;

  final int previewCount;

  bool get isExpandable =>
      kind == ScheduleSummaryKind.individual &&
      detailLines.length > previewCount;

  int get hiddenCount =>
      isExpandable ? detailLines.length - previewCount : 0;

  List<String> visibleLines({required bool expanded}) {
    if (kind != ScheduleSummaryKind.individual) {
      return [headline];
    }
    if (expanded || !isExpandable) return detailLines;
    return detailLines.take(previewCount).toList();
  }
}

/// 배정 카드용 요약.
///
/// - **동일 출퇴근 시각**은 항상 1줄(또는 패턴+추가 1줄)로 압축.
/// - 요일 규칙이 전체의 [weeklyCoverageThreshold] 이상이면 `매주 …` 우선.
/// - 시간대가 다를 때만 블록(줄)을 분리.
List<ScheduleSummaryBlock> formatScheduleSummary(
  List<ScheduleModel> schedules, {
  DateFormat? dayFmt,
  DateFormat? rangeFmt,
  DateFormat? weekdayFmt,
  int individualPreviewCount = 3,
  int minGroupSize = 3,
  double weeklyCoverageThreshold = 0.8,
}) {
  if (schedules.isEmpty) return const [];

  final day = dayFmt ?? DateFormat('M/d');
  final time = rangeFmt ?? DateFormat('HH:mm');
  final weekday = weekdayFmt ?? DateFormat('E', 'ko_KR');
  final groupMin = minGroupSize < 2 ? 2 : minGroupSize;
  final threshold = weeklyCoverageThreshold.clamp(0.5, 1.0);

  // 날짜 중복 제거(같은 날·같은 시각) 후 시각별 통합 — 추가 배정·기간 배정 합침
  final byClock = <String, List<ScheduleModel>>{};
  final seenDayClock = <String>{};

  final sorted = List<ScheduleModel>.from(schedules)
    ..sort((a, b) => a.startTime.compareTo(b.startTime));

  for (final s in sorted) {
    final clockKey = _clockKey(s);
    final dayKey =
        '${DateOnly.of(s.startTime).toIso8601String()}|$clockKey';
    if (!seenDayClock.add(dayKey)) continue;
    byClock.putIfAbsent(clockKey, () => []).add(s);
  }

  final clockGroups = byClock.values.toList()
    ..sort((a, b) => a.first.startTime.compareTo(b.first.startTime));

  return [
    for (final group in clockGroups)
      _summarizeSameClock(
        group,
        day: day,
        time: time,
        weekday: weekday,
        groupMin: groupMin,
        weeklyThreshold: threshold,
        individualPreviewCount: individualPreviewCount,
      ),
  ];
}

String _clockKey(ScheduleModel s) =>
    '${s.startTime.hour}:${s.startTime.minute}|'
    '${s.endTime.hour}:${s.endTime.minute}';

ScheduleSummaryBlock _summarizeSameClock(
  List<ScheduleModel> group, {
  required DateFormat day,
  required DateFormat time,
  required DateFormat weekday,
  required int groupMin,
  required double weeklyThreshold,
  required int individualPreviewCount,
}) {
  group.sort((a, b) => a.startTime.compareTo(b.startTime));
  final days = group.map((s) => DateOnly.of(s.startTime)).toList();
  final first = group.first;
  final timeLabel =
      '${time.format(first.startTime)}~${time.format(first.endTime)}';
  final n = days.length;

  if (n == 1) {
    return ScheduleSummaryBlock(
      kind: ScheduleSummaryKind.range,
      headline:
          '${day.format(first.startTime)}(${weekday.format(first.startTime)})'
          ' | $timeLabel',
    );
  }

  // 1) 요일 패턴 ≥ threshold → 매주 요약 (+ 추가 날짜)
  final dominant = _dominantWeekdays(days, threshold: weeklyThreshold);
  if (dominant.isNotEmpty) {
    final matchingDays =
        days.where((d) => dominant.contains(d.weekday)).toList();
    final extraDays =
        days.where((d) => !dominant.contains(d.weekday)).toList();
    final matching = matchingDays.length;
    final coverage = matching / n;
    if (matching >= groupMin && coverage >= weeklyThreshold) {
      final labels = _weekdayLabels(dominant);
      if (extraDays.isEmpty) {
        return ScheduleSummaryBlock(
          kind: ScheduleSummaryKind.weekly,
          headline: '매주 $labels | $timeLabel (총 $n일)',
        );
      }
      final extraLabel = _formatExtraDates(extraDays, day: day);
      return ScheduleSummaryBlock(
        kind: ScheduleSummaryKind.weekly,
        headline: '매주 $labels ($matching회) + $extraLabel',
      );
    }
  }

  // 2) 연속 기간
  if (n >= groupMin && _isConsecutiveDays(days)) {
    return _rangeBlock(group, day: day, time: time, weekday: weekday);
  }

  // 3) 동일 시간대 — 개별 나열 금지, 월/총 횟수 1줄
  if (n >= groupMin) {
    return ScheduleSummaryBlock(
      kind: ScheduleSummaryKind.compact,
      headline: '${_monthOrTotalLabel(days)} | $timeLabel',
    );
  }

  // 4) 2일 미만 그룹만 짧은 개별 (더보기 없음)
  final lines = group.map((s) {
    final sameDay = DateOnly.of(s.startTime) == DateOnly.of(s.endTime);
    if (sameDay) {
      return '• ${day.format(s.startTime)} '
          '${time.format(s.startTime)}~${time.format(s.endTime)}';
    }
    return '• ${day.format(s.startTime)} ${time.format(s.startTime)}'
        ' ~ ${day.format(s.endTime)} ${time.format(s.endTime)}';
  }).toList();

  return ScheduleSummaryBlock(
    kind: ScheduleSummaryKind.individual,
    headline: lines.first,
    detailLines: lines,
    previewCount: individualPreviewCount,
  );
}

/// 빈도 높은 요일부터 채워 [threshold] 커버리지에 도달한 집합
List<int> _dominantWeekdays(
  List<DateTime> days, {
  required double threshold,
}) {
  if (days.isEmpty) return const [];
  final counts = <int, int>{};
  for (final d in days) {
    counts[d.weekday] = (counts[d.weekday] ?? 0) + 1;
  }
  final ordered = counts.entries.toList()
    ..sort((a, b) {
      final byCount = b.value.compareTo(a.value);
      if (byCount != 0) return byCount;
      return a.key.compareTo(b.key);
    });

  final selected = <int>[];
  var covered = 0;
  final total = days.length;
  for (final e in ordered) {
    selected.add(e.key);
    covered += e.value;
    if (covered / total >= threshold) break;
  }

  // 요일이 너무 많으면(거의 매일) 매주 표기보다 월 총횟수가 낫다 → 빈 집합
  if (selected.length >= 6) return const [];

  selected.sort();
  return selected;
}

String _weekdayLabels(List<int> weekdays) {
  final ordered = [1, 2, 3, 4, 5, 6, 7].where(weekdays.contains);
  return ordered.map(_weekdayShort).join('·');
}

String _monthOrTotalLabel(List<DateTime> days) {
  final months = <String, int>{};
  for (final d in days) {
    final key = '${d.year}-${d.month}';
    months[key] = (months[key] ?? 0) + 1;
  }
  if (months.length == 1) {
    final d = days.first;
    return '${d.month}월 총 ${days.length}회 근무';
  }
  return '총 ${days.length}회 근무';
}

/// 규칙 밖 추가 근무 — 날짜로 표기 (소수면 전부, 많으면 앞부분 + N일)
String _formatExtraDates(
  List<DateTime> extras, {
  required DateFormat day,
  int maxDates = 3,
}) {
  if (extras.isEmpty) return '';
  final sorted = List<DateTime>.from(extras)
    ..sort((a, b) => a.compareTo(b));
  if (sorted.length <= maxDates) {
    return sorted.map(day.format).join('·');
  }
  final shown = sorted.take(maxDates).map(day.format).join('·');
  return '$shown 외 ${sorted.length - maxDates}일';
}

ScheduleSummaryBlock _rangeBlock(
  List<ScheduleModel> group, {
  required DateFormat day,
  required DateFormat time,
  required DateFormat weekday,
}) {
  final first = group.first;
  final last = group.last;
  final timeLabel =
      '${time.format(first.startTime)}~${time.format(first.endTime)}';
  if (group.length == 1) {
    return ScheduleSummaryBlock(
      kind: ScheduleSummaryKind.range,
      headline:
          '${day.format(first.startTime)}(${weekday.format(first.startTime)})'
          ' | $timeLabel',
    );
  }
  return ScheduleSummaryBlock(
    kind: ScheduleSummaryKind.range,
    headline:
        '${day.format(first.startTime)}(${weekday.format(first.startTime)})'
        ' ~ ${day.format(last.startTime)}(${weekday.format(last.startTime)})'
        ' | $timeLabel',
  );
}

String _weekdayShort(int weekday) {
  const labels = {
    DateTime.monday: '월',
    DateTime.tuesday: '화',
    DateTime.wednesday: '수',
    DateTime.thursday: '목',
    DateTime.friday: '금',
    DateTime.saturday: '토',
    DateTime.sunday: '일',
  };
  return labels[weekday] ?? '';
}

bool _isConsecutiveDays(List<DateTime> days) {
  if (days.length < 2) return false;
  for (var i = 1; i < days.length; i++) {
    final expected = DateOnly.nextDay(days[i - 1]);
    if (days[i] != expected) return false;
  }
  return true;
}
