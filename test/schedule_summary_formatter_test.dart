import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:money_shift/features/schedules/utils/schedule_summary_formatter.dart';
import 'package:money_shift/models/schedule_model.dart';

ScheduleModel _s(DateTime day, {int sh = 9, int eh = 18, String id = ''}) {
  final start = DateTime(day.year, day.month, day.day, sh);
  final end = DateTime(day.year, day.month, day.day, eh);
  return ScheduleModel(
    id: id.isEmpty ? start.toIso8601String() : id,
    roomId: 'r1',
    workerId: 'w1',
    assignedBy: 'o1',
    date:
        '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}',
    startTime: start,
    endTime: end,
  );
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ko_KR');
  });

  test('월·목·일 패턴(+갭)은 매주 요약 — 개별 나열 없음', () {
    // 2026-10: 목1, 일4, 월5 … 일부만 있어도 요일 비중 ≥80%면 매주
    final days = <DateTime>[
      DateTime(2026, 10, 1), // 목
      DateTime(2026, 10, 4), // 일
      DateTime(2026, 10, 5), // 월
      DateTime(2026, 10, 8), // 목
      DateTime(2026, 10, 11), // 일
      DateTime(2026, 10, 12), // 월
      DateTime(2026, 10, 15), // 목
      DateTime(2026, 10, 18), // 일
      DateTime(2026, 10, 19), // 월
      DateTime(2026, 10, 22), // 목
      DateTime(2026, 10, 25), // 일
      DateTime(2026, 10, 26), // 월
      DateTime(2026, 10, 29), // 목
    ];
    final blocks = formatScheduleSummary(days.map(_s).toList());
    expect(blocks, hasLength(1));
    expect(blocks.single.kind, ScheduleSummaryKind.weekly);
    expect(blocks.single.headline, contains('매주'));
    expect(blocks.single.headline, contains('월'));
    expect(blocks.single.headline, contains('목'));
    expect(blocks.single.headline, contains('일'));
    expect(blocks.single.isExpandable, isFalse);
    expect(blocks.single.headline, isNot(contains('더보기')));
  });

  test('매주 패턴 + 다른 요일 추가는 날짜로 표기', () {
    final days = <DateTime>[
      DateTime(2026, 10, 1), // 목
      DateTime(2026, 10, 4), // 일
      DateTime(2026, 10, 8), // 목
      DateTime(2026, 10, 11), // 일
      DateTime(2026, 10, 15), // 목
      DateTime(2026, 10, 18), // 일
      DateTime(2026, 10, 22), // 목
      DateTime(2026, 10, 25), // 일
      DateTime(2026, 10, 29), // 목
      DateTime(2026, 10, 2), // 금 — 추가
      DateTime(2026, 10, 3), // 토 — 추가
    ];
    final blocks = formatScheduleSummary(days.map(_s).toList());
    expect(blocks, hasLength(1));
    expect(blocks.single.headline, contains('매주'));
    expect(blocks.single.headline, contains('10/2'));
    expect(blocks.single.headline, contains('10/3'));
    expect(blocks.single.headline, isNot(contains('추가')));
    expect(blocks.single.isExpandable, isFalse);
  });

  test('동일 시간대는 항상 1블록 — 야간과만 분리', () {
    final day = [
      _s(DateTime(2026, 10, 1)),
      _s(DateTime(2026, 10, 2)),
      _s(DateTime(2026, 10, 3)),
      _s(DateTime(2026, 10, 1), sh: 18, eh: 23, id: 'night'),
      _s(DateTime(2026, 10, 2), sh: 18, eh: 23, id: 'night2'),
      _s(DateTime(2026, 10, 3), sh: 18, eh: 23, id: 'night3'),
    ];
    final blocks = formatScheduleSummary(day);
    expect(blocks, hasLength(2));
    expect(blocks.every((b) => !b.isExpandable || b.detailLines.length <= 3), isTrue);
  });
}
