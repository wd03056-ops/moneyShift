import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/time/kst_date_time.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../mock/mock_store.dart';
import '../../../../services/month_payroll_aggregator.dart';

String formatStaffWorkHours(int minutes) {
  if (minutes <= 0) return '0시간';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (m == 0) return '$h시간';
  if (h == 0) return '$m분';
  return '$h시간 $m분';
}

/// 이번 달 실근무 급여 요약 (하위 호환 별칭)
typedef StaffMonthPaySummary = WorkerMonthPaySummary;

extension StaffMonthPaySummaryX on WorkerMonthPaySummary {
  /// 카드 메인: 퇴근 확정 실근무
  int get estimatedPay => actualPay;

  int get basePay => actualBasePay;
  int get weeklyPay => actualWeeklyPay;
  int get overtimePay => actualOvertimePay;
  int get netWorkedMinutes => actualNetMinutes;
}

/// 출퇴근 탭 — 이번 달 퇴근 확정 실근무 급여만 표시
class StaffMonthPaySummaryCard extends StatelessWidget {
  const StaffMonthPaySummaryCard({
    super.key,
    required this.summary,
    required this.currency,
    required this.roomId,
  });

  final WorkerMonthPaySummary summary;
  final NumberFormat currency;
  final String roomId;

  factory StaffMonthPaySummaryCard.fromStore({
    Key? key,
    required MockStore store,
    required String roomId,
    required String userId,
    required NumberFormat currency,
  }) {
    final summary = MonthPayrollAggregator.forWorker(
      store: store,
      roomId: roomId,
      userId: userId,
    );
    return StaffMonthPaySummaryCard(
      key: key,
      summary: summary,
      currency: currency,
      roomId: roomId,
    );
  }

  /// 예: `10.1 ~ 오늘 (10.26)` (해당 월 1일 ~ 오늘까지 확정분)
  String get _periodLabel {
    final start = '${summary.month}.1';
    final now = KstDateTime.now();
    final isCurrentMonth =
        summary.year == now.year && summary.month == now.month;
    if (isCurrentMonth) {
      return '$start ~ 오늘 (${now.month}.${now.day})';
    }
    final lastDay = DateTime(summary.year, summary.month + 1, 0).day;
    return '$start ~ ${summary.month}.$lastDay';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _periodLabel,
            style: textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${currency.format(summary.actualPay)}원',
            style: textTheme.titleLarge?.copyWith(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.6,
            ),
          ),
        ],
      ),
    );
  }
}
