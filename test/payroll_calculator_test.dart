import 'package:flutter_test/flutter_test.dart';
import 'package:money_shift/services/payroll_calculator.dart';

void main() {
  group('PayrollCalculator.estimate', () {
    test('기본급 = 시급 × (총근무 − 휴게)', () {
      final e = PayrollCalculator.estimate(
        startTime: DateTime(2026, 10, 24, 9),
        endTime: DateTime(2026, 10, 24, 18),
        hourlyWage: 10000,
        breakMinutes: 60,
      );
      expect(e.totalWorkedMinutes, 9 * 60);
      expect(e.breakMinutes, 60);
      expect(e.netWorkedMinutes, 8 * 60);
      expect(e.basePay, 80000);
      expect(e.overtimeNightPay, 0);
      expect(e.weeklyHolidayPay, 0);
    });

    test('연장수당: 실근로 8시간 초과분 × 0.5', () {
      final e = PayrollCalculator.estimate(
        startTime: DateTime(2026, 10, 24, 9),
        endTime: DateTime(2026, 10, 24, 20),
        hourlyWage: 10000,
        breakMinutes: 60,
        includeOvertime: true,
        includeNight: false,
      );
      // 11h − 1h = 10h net → OT 2h → 2 * 10000 * 0.5 = 10000
      expect(e.netWorkedMinutes, 10 * 60);
      expect(e.overtimeMinutes, 2 * 60);
      expect(e.overtimeNightPay, 10000);
    });

    test('야간수당: 22~06 구간 × 0.5', () {
      final e = PayrollCalculator.estimate(
        startTime: DateTime(2026, 10, 24, 21),
        endTime: DateTime(2026, 10, 25, 2),
        hourlyWage: 10000,
        breakMinutes: 0,
        includeOvertime: false,
        includeNight: true,
      );
      // 21~02 = 5h, night = 22~02 = 4h → 4 * 10000 * 0.5 = 20000
      expect(e.nightMinutes, 4 * 60);
      expect(e.overtimeNightPay, 20000);
    });

    test('주휴: 단일 구간 8h는 주 15h 미만 → 0', () {
      final e = PayrollCalculator.estimate(
        startTime: DateTime(2026, 10, 24, 9),
        endTime: DateTime(2026, 10, 24, 18),
        hourlyWage: 10000,
        breakMinutes: 60,
        includeWeeklyHoliday: true,
      );
      expect(e.netWorkedMinutes, 8 * 60);
      expect(e.weeklyHolidayPay, 0);
    });

    test('주휴: 단일 구간 15h 이상이면 (h/40)*8*시급', () {
      final e = PayrollCalculator.estimate(
        startTime: DateTime(2026, 10, 24, 9),
        endTime: DateTime(2026, 10, 25, 1),
        hourlyWage: 10000,
        breakMinutes: 60,
        includeWeeklyHoliday: true,
      );
      // 16h − 1h = 15h net → (15/40)*8*10000 = 30000
      expect(e.netWorkedMinutes, 15 * 60);
      expect(e.weeklyHolidayPay, 30000);
    });

    test('주휴: 주 합산 15시간 이상이면 (h/40)*8*시급', () {
      final pay = PayrollCalculator.weeklyHolidayPayForNetMinutes(
        netWorkedMinutes: 20 * 60,
        hourlyWage: 10000,
      );
      // (20/40)*8*10000 = 40000
      expect(pay, 40000);
    });

    test('주휴: 15시간 미만 0', () {
      final pay = PayrollCalculator.weeklyHolidayPayForNetMinutes(
        netWorkedMinutes: 14 * 60,
        hourlyWage: 10000,
      );
      expect(pay, 0);
    });

    test('연장+야간 동시: 각 0.5 가산이 합산됨', () {
      final e = PayrollCalculator.estimate(
        startTime: DateTime(2026, 10, 24, 16),
        endTime: DateTime(2026, 10, 25, 2),
        hourlyWage: 10000,
        breakMinutes: 0,
        includeOvertime: true,
        includeNight: true,
      );
      // 10h net → OT 2h, night 22~02 = 4h → premium (2+4)*0.5*10000 = 30000
      expect(e.netWorkedMinutes, 10 * 60);
      expect(e.overtimeMinutes, 2 * 60);
      expect(e.nightMinutes, 4 * 60);
      expect(e.overtimeNightPay, 30000);
      expect(e.basePay, 100000);
    });
  });
}
