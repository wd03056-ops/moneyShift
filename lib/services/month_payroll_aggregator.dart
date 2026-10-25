import 'package:intl/intl.dart';

import '../core/constants/app_constants.dart';
import '../core/time/kst_date_time.dart';
import '../mock/mock_store.dart';
import '../models/employee_contract_model.dart';
import '../models/enums/attendance_type.dart';
import '../models/enums/member_role.dart';
import '../models/monthly_labor_cost.dart';
import '../models/pay_estimate.dart';
import '../models/schedule_model.dart';
import 'payroll_calculator.dart';

/// 직원 1명의 이번 달 실근무·예상 급여
class WorkerMonthPaySummary {
  const WorkerMonthPaySummary({
    required this.year,
    required this.month,
    required this.actualBasePay,
    required this.actualWeeklyPay,
    required this.actualOvertimePay,
    required this.actualNetMinutes,
    required this.workedDays,
    required this.remainingSchedulePay,
    required this.projectedWeeklyPay,
    required this.projectedBasePay,
    required this.projectedOvertimePay,
  });

  final int year;
  final int month;

  /// 퇴근 완료분 기본급
  final int actualBasePay;
  final int actualWeeklyPay;
  final int actualOvertimePay;
  final int actualNetMinutes;
  final int workedDays;

  /// 남은(또는 미퇴근) 배정분 기본급+연장야간 (주휴 제외)
  final int remainingSchedulePay;

  /// 실근무+남은 배정까지 반영한 주휴(주 15h 재계산)
  final int projectedWeeklyPay;
  final int projectedBasePay;
  final int projectedOvertimePay;

  String get monthLabel => '$year년 $month월';

  int get actualPay =>
      actualBasePay + actualWeeklyPay + actualOvertimePay;

  /// 실근무 기본급+연장야간 (주휴 제외) — 예상 합산의 실근무 몫
  int get actualEarnedWithoutWeekly =>
      actualBasePay + actualOvertimePay;

  /// 이번 달 예상 = 실근무(기본+OT) + 남은 배정 + 주휴(실+남은 재계산)
  int get projectedPay =>
      projectedBasePay + projectedOvertimePay + projectedWeeklyPay;

  /// [projectedPay]와 동일해야 함 (실근무↔예상 연동 검증용)
  int get projectedPayFromParts =>
      actualEarnedWithoutWeekly +
      remainingSchedulePay +
      projectedWeeklyPay;
}

/// 사장 인건비 상세 — 직원 1명 행
class WorkerLaborCostRow {
  const WorkerLaborCostRow({
    required this.workerId,
    required this.displayName,
    required this.roleLabel,
    required this.hourlyWage,
    required this.netWorkedMinutes,
    required this.workedDays,
    required this.basePay,
    required this.weeklyHolidayPay,
    required this.overtimePay,
    required this.nightPay,
  });

  final String workerId;
  final String displayName;
  final String roleLabel;
  final int hourlyWage;
  final int netWorkedMinutes;
  final int workedDays;
  final int basePay;
  final int weeklyHolidayPay;

  /// 연장수당 (8h 초과분 가산)
  final int overtimePay;

  /// 야간수당 (22~06 가산)
  final int nightPay;

  int get premiumPay => overtimePay + nightPay;

  int get totalPay =>
      basePay + weeklyHolidayPay + overtimePay + nightPay;

  double get workHours =>
      (netWorkedMinutes / 60.0 * 100).round() / 100.0;
}

/// 출퇴근·계약·배정 기준 월간 급여/인건비 집계 (MockStore SSOT)
class MonthPayrollAggregator {
  MonthPayrollAggregator._();

  static final _dayFmt = DateFormat('yyyy-MM-dd');

  static WorkerMonthPaySummary forWorker({
    required MockStore store,
    required String roomId,
    required String userId,
    int? year,
    int? month,
    bool? forceWeeklyHoliday,
  }) {
    final now = KstDateTime.now();
    final y = year ?? now.year;
    final m = month ?? now.month;
    final member = store.getMembership(roomId, userId);
    final contract = member?.contract ?? const EmployeeContractModel();
    final wage = contract.hourlyWage > 0
        ? contract.hourlyWage
        : AppConstants.minimumHourlyWage;
    final wantWeek =
        forceWeeklyHoliday ?? contract.isWeekPayEnabled;
    final wantOt = contract.isOvertimePayEnabled;
    final wantNight = contract.isNightPayEnabled;

    // UI 기간(M.1 ~ 오늘)과 동일: 해당 월 1일 ~ 오늘(KST)까지
    final todayKey = _dayFmt.format(DateTime(now.year, now.month, now.day));
    final monthPrefix =
        '${y.toString().padLeft(4, '0')}-${m.toString().padLeft(2, '0')}';
    final monthStartKey = '$monthPrefix-01';
    final isCurrentMonth = now.year == y && now.month == m;
    final periodEndKey = isCurrentMonth
        ? todayKey
        : '$monthPrefix-${DateTime(y, m + 1, 0).day.toString().padLeft(2, '0')}';

    // dateKey → 그날 실근무(기본+OT, 주휴 제외)
    // SSOT: MockStore.attendanceLogs → actualPayEstimateOnDate
    // (실 출퇴근 구간 × 계약 시급·휴게·연장·야간. 주휴는 아래에서 주 합산)
    final actualByDay = <String, _DayPay>{};
    final clockOutDates = <String>{};
    for (final a in store.attendanceForUser(roomId, userId)) {
      if (a.type != AttendanceType.clockOut) continue;
      // 기록은 KstDateTime.now() 벽시계로 저장 — 달력일 기준 버킷
      final d = KstDateTime.dateOnly(a.timestamp);
      final key = _dayFmt.format(d);
      if (key.compareTo(monthStartKey) < 0) continue;
      if (key.compareTo(periodEndKey) > 0) continue;
      clockOutDates.add(key);
    }

    for (final key in clockOutDates) {
      final day = DateTime.parse(key);
      final e = store.actualPayEstimateOnDate(roomId, userId, day);
      // 당일 배정 없거나 실근로 0분이면 제외 (배정 확인 후에만 급여 산정)
      if (e == null || e.netWorkedMinutes <= 0) continue;
      actualByDay[key] = _DayPay(
        base: e.basePay,
        overtime: e.overtimeNightPay,
        netMinutes: e.netWorkedMinutes,
      );
    }

    // 남은 배정: 해당 월, 결근 아님, 아직 실근무 반영 안 된 날
    final remainingByDay = <String, _DayPay>{};
    for (final s in store.schedulesForWorker(roomId, userId)) {
      if (!s.date.startsWith(monthPrefix)) continue;
      if (s.isAbsent) continue;
      if (actualByDay.containsKey(s.date)) continue;
      // 과거 미출근은 누적 실근무에 넣지 않음. 오늘 포함 미래·미퇴근만 예상.
      if (s.date.compareTo(todayKey) < 0) continue;

      final estimate = _scheduleDayEstimate(
        schedule: s,
        wage: wage,
        contract: contract,
        wantOt: wantOt,
        wantNight: wantNight,
      );
      final prev = remainingByDay[s.date];
      remainingByDay[s.date] = _DayPay(
        base: (prev?.base ?? 0) + estimate.basePay,
        overtime: (prev?.overtime ?? 0) + estimate.overtimeNightPay,
        netMinutes: (prev?.netMinutes ?? 0) + estimate.netWorkedMinutes,
      );
    }

    var actualBase = 0;
    var actualOt = 0;
    var actualNet = 0;
    for (final d in actualByDay.values) {
      actualBase += d.base;
      actualOt += d.overtime;
      actualNet += d.netMinutes;
    }

    var remainBase = 0;
    var remainOt = 0;
    var remainPay = 0;
    for (final d in remainingByDay.values) {
      remainBase += d.base;
      remainOt += d.overtime;
      remainPay += d.base + d.overtime;
    }

    final actualWeekly = wantWeek
        ? _weeklyHolidayForDays(
            {...actualByDay},
            wage: wage,
          )
        : 0;
    final projectedWeekly = wantWeek
        ? _weeklyHolidayForDays(
            {...actualByDay, ...remainingByDay},
            wage: wage,
          )
        : 0;

    final summary = WorkerMonthPaySummary(
      year: y,
      month: m,
      actualBasePay: actualBase,
      actualWeeklyPay: actualWeekly,
      actualOvertimePay: actualOt,
      actualNetMinutes: actualNet,
      workedDays: actualByDay.length,
      remainingSchedulePay: remainPay,
      projectedWeeklyPay: projectedWeekly,
      projectedBasePay: actualBase + remainBase,
      projectedOvertimePay: actualOt + remainOt,
    );
    assert(
      summary.projectedPay == summary.projectedPayFromParts,
      'projectedPay must equal actual(base+OT) + remaining + weekly',
    );
    return summary;
  }

  /// 사장 — 방 전체 이번 달 누적 인건비 (퇴근 확정분만)
  static MonthlyLaborCost forRoom({
    required MockStore store,
    required String roomId,
    required int year,
    required int month,
    bool includeWeeklyHoliday = false,
    bool includeEmployerSocialInsurance = false,
    double employerSocialInsuranceRate = 0.099,
  }) {
    final now = KstDateTime.now();
    final dim = DateTime(year, month + 1, 0).day;
    final isCurrent = now.year == year && now.month == month;
    final endDay = isCurrent ? now.day.clamp(1, dim) : dim;
    final fromKey =
        '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-01';
    final toKey =
        '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${endDay.toString().padLeft(2, '0')}';

    var totalBase = 0;
    var totalWeekly = 0;
    var totalOt = 0;
    var totalNetMinutes = 0;
    final workerIds = <String>{};

    final staff = store.activeStaffMembers(roomId);
    final ids = staff.map((m) => m.userId).toSet();
    // 출퇴근만 있고 멤버 목록에 없는 경우도 포함
    for (final a in store.attendanceForRoom(roomId)) {
      ids.add(a.userId);
    }

    for (final uid in ids) {
      final member = store.getMembership(roomId, uid);
      if (member != null && !member.isActive) continue;
      // 직원별 상세(workerRows)와 동일 — 사장은 인건비 합산에서 제외
      if (member?.role == MemberRole.owner) continue;

      final summary = forWorker(
        store: store,
        roomId: roomId,
        userId: uid,
        year: year,
        month: month,
        // 토글 ON → 전원 주휴, OFF → 직원 계약 따름
        forceWeeklyHoliday: includeWeeklyHoliday ? true : null,
      );

      // 누적 인건비 = 퇴근 확정 실근무만 (배정 확인만으로는 집계하지 않음)
      if (summary.workedDays == 0 && summary.actualNetMinutes == 0) {
        continue;
      }

      workerIds.add(uid);
      totalBase += summary.actualBasePay;
      totalOt += summary.actualOvertimePay;
      totalWeekly += summary.actualWeeklyPay;
      totalNetMinutes += summary.actualNetMinutes;
    }

    final totalLabor = totalBase + totalOt + totalWeekly;
    final insurance = includeEmployerSocialInsurance
        ? (totalLabor * employerSocialInsuranceRate).round()
        : 0;

    return MonthlyLaborCost(
      roomId: roomId,
      year: year,
      month: month,
      periodFrom: fromKey,
      periodTo: toKey,
      totalLaborCost: totalLabor,
      totalWorkHours: (totalNetMinutes / 60.0 * 100).round() / 100.0,
      activeWorkerCount: workerIds.length,
      includeWeeklyHoliday: includeWeeklyHoliday,
      includeEmployerSocialInsurance: includeEmployerSocialInsurance,
      employerSocialInsuranceRate: employerSocialInsuranceRate,
      basePay: totalBase + totalOt,
      weeklyHolidayPay: totalWeekly,
      employerSocialInsuranceEstimate: insurance,
      source: 'mock',
    );
  }

  /// 직원별 인건비 상세 행 — 퇴근 확정 실근무만
  static List<WorkerLaborCostRow> workerRowsForRoom({
    required MockStore store,
    required String roomId,
    required int year,
    required int month,
    bool includeWeeklyHoliday = false,
  }) {
    final staff = store.activeStaffMembers(roomId);
    final ids = staff.map((m) => m.userId).toSet();
    for (final a in store.attendanceForRoom(roomId)) {
      ids.add(a.userId);
    }

    final rows = <WorkerLaborCostRow>[];
    for (final uid in ids) {
      final member = store.getMembership(roomId, uid);
      if (member != null && !member.isActive) continue;
      if (member?.role == MemberRole.owner) continue;

      final contract = member?.contract ?? const EmployeeContractModel();
      final wage = contract.hourlyWage > 0
          ? contract.hourlyWage
          : AppConstants.minimumHourlyWage;
      final name = member?.displayName.trim().isNotEmpty == true
          ? member!.displayName
          : store.memberDisplayName(roomId, uid);
      final roleLabel = member?.roleLabel ?? '직원';

      final summary = forWorker(
        store: store,
        roomId: roomId,
        userId: uid,
        year: year,
        month: month,
        forceWeeklyHoliday: includeWeeklyHoliday ? true : null,
      );

      // 배정 확인만으로는 행을 만들지 않음 — 퇴근 기록이 있어야 함
      if (summary.workedDays == 0 && summary.actualNetMinutes == 0) {
        continue;
      }

      // 연장·야간 합산을 분 비율로 나눌 정보가 없으면 연장 쪽에 둠
      final split = _splitPremium(
        summary.actualOvertimePay,
        overtimeWeight: contract.isOvertimePayEnabled ? 1 : 0,
        nightWeight: contract.isNightPayEnabled ? 1 : 0,
      );
      rows.add(
        WorkerLaborCostRow(
          workerId: uid,
          displayName: name,
          roleLabel: roleLabel,
          hourlyWage: wage,
          netWorkedMinutes: summary.actualNetMinutes,
          workedDays: summary.workedDays,
          basePay: summary.actualBasePay,
          weeklyHolidayPay: summary.actualWeeklyPay,
          overtimePay: split.ot,
          nightPay: split.night,
        ),
      );
    }

    rows.sort((a, b) => b.totalPay.compareTo(a.totalPay));
    return rows;
  }

  /// 직원별 행 합계 — [forRoom.totalLaborCost]와 일치해야 함
  static int sumWorkerRowPay(Iterable<WorkerLaborCostRow> rows) {
    var total = 0;
    for (final r in rows) {
      total += r.totalPay;
    }
    return total;
  }

  static ({int ot, int night}) _splitPremium(
    int total, {
    required int overtimeWeight,
    required int nightWeight,
  }) {
    if (total <= 0) return (ot: 0, night: 0);
    final ow = overtimeWeight < 0 ? 0 : overtimeWeight;
    final nw = nightWeight < 0 ? 0 : nightWeight;
    if (ow <= 0 && nw <= 0) return (ot: total, night: 0);
    if (nw <= 0) return (ot: total, night: 0);
    if (ow <= 0) return (ot: 0, night: total);
    final ot = (total * ow / (ow + nw)).round();
    return (ot: ot, night: total - ot);
  }

  static int _weeklyHolidayForDays(
    Map<String, _DayPay> byDay, {
    required int wage,
  }) {
    final byWeek = <String, int>{};
    for (final entry in byDay.entries) {
      final day = DateTime.parse(entry.key);
      final wk = PayrollCalculator.weekMondayKey(day);
      byWeek[wk] = (byWeek[wk] ?? 0) + entry.value.netMinutes;
    }
    var total = 0;
    for (final net in byWeek.values) {
      total += PayrollCalculator.weeklyHolidayPayForNetMinutes(
        netWorkedMinutes: net,
        hourlyWage: wage,
      );
    }
    return total;
  }

  static PayEstimate _scheduleDayEstimate({
    required ScheduleModel schedule,
    required int wage,
    required EmployeeContractModel contract,
    required bool wantOt,
    required bool wantNight,
  }) {
    if (schedule.payEstimate != null) {
      final pe = schedule.payEstimate!;
      return PayEstimate(
        hourlyWage: pe.hourlyWage,
        totalWorkedMinutes: pe.totalWorkedMinutes,
        breakMinutes: pe.breakMinutes,
        netWorkedMinutes: pe.netWorkedMinutes,
        basePay: pe.basePay,
        weeklyHolidayPay: 0,
        overtimeNightPay: pe.overtimeNightPay,
        includeWeeklyHoliday: false,
        includeOvertimeNight: pe.includeOvertimeNight,
        overtimeMinutes: pe.overtimeMinutes,
        nightMinutes: pe.nightMinutes,
      );
    }
    final gross = schedule.endTime.difference(schedule.startTime).inMinutes;
    final breakMin = schedule.breakMinutes > 0
        ? schedule.breakMinutes
        : contract.resolveBreakMinutes(gross);
    return PayrollCalculator.estimate(
      startTime: schedule.startTime,
      endTime: schedule.endTime,
      hourlyWage: wage,
      breakMinutes: breakMin,
      includeWeeklyHoliday: false,
      includeOvertime: wantOt || schedule.includeOvertimeNight,
      includeNight: wantNight || schedule.includeOvertimeNight,
    );
  }
}

class _DayPay {
  const _DayPay({
    required this.base,
    required this.overtime,
    required this.netMinutes,
  });

  final int base;
  final int overtime;
  final int netMinutes;
}
