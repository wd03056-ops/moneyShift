import 'package:flutter_test/flutter_test.dart';
import 'package:money_shift/services/payroll_calculator.dart';

/// 월간 실근무 합산 규칙(기간·주휴) 단위 검증.
/// UI 카드는 MonthPayrollAggregator → MockStore.attendanceLogs SSOT.
void main() {
  group('월간 실근무 합산 규칙', () {
    test('주휴: 주 실근로 15h 미만 → 0', () {
      expect(
        PayrollCalculator.weeklyHolidayPayForNetMinutes(
          netWorkedMinutes: 14 * 60,
          hourlyWage: 10000,
        ),
        0,
      );
    });

    test('주휴: 주 20h → (20/40)*8*시급', () {
      expect(
        PayrollCalculator.weeklyHolidayPayForNetMinutes(
          netWorkedMinutes: 20 * 60,
          hourlyWage: 10000,
        ),
        40000,
      );
    });

    test('기본급 반올림: 시급×실근로시간', () {
      final e = PayrollCalculator.estimate(
        startTime: DateTime(2026, 10, 1, 9),
        endTime: DateTime(2026, 10, 1, 18),
        hourlyWage: 9860,
        breakMinutes: 60,
      );
      expect(e.netWorkedMinutes, 8 * 60);
      expect(e.basePay, (8.0 * 9860).round());
    });

    test('날짜 키 사전식 비교로 1일~오늘 구간 필터가 동작한다', () {
      const monthStart = '2026-10-01';
      const today = '2026-10-25';
      final keys = [
        '2026-09-30',
        '2026-10-01',
        '2026-10-15',
        '2026-10-25',
        '2026-10-26',
        '2026-11-01',
      ];
      final inPeriod = keys
          .where(
            (k) =>
                k.compareTo(monthStart) >= 0 && k.compareTo(today) <= 0,
          )
          .toList();
      expect(inPeriod, ['2026-10-01', '2026-10-15', '2026-10-25']);
    });
  });
}
