import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/storage/dashboard_pay_view_store.dart';
import '../../../../core/theme/app_colors.dart';
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

/// 이번 달 실근무·예상 급여 요약 (하위 호환 별칭)
typedef StaffMonthPaySummary = WorkerMonthPaySummary;

extension StaffMonthPaySummaryX on WorkerMonthPaySummary {
  /// 카드 메인(간략): 퇴근 확정 실근무
  int get estimatedPay => actualPay;

  int get basePay => actualBasePay;
  int get weeklyPay => actualWeeklyPay;
  int get overtimePay => actualOvertimePay;
  int get netWorkedMinutes => actualNetMinutes;
}

/// 출퇴근 탭 — 실근무(퇴근) + 예상(실근무+남은 배정+주휴)
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

  @override
  Widget build(BuildContext context) {
    final viewStore = DashboardPayViewStore.instance;

    return ListenableBuilder(
      listenable: viewStore,
      builder: (context, _) {
        final compact = viewStore.isStaffCompact(roomId);
        return AppCard(
          padding: compact
              ? const EdgeInsets.symmetric(horizontal: 14, vertical: 10)
              : const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: compact
              ? _StaffCompactBar(
                  actualPay: summary.actualPay,
                  projectedPay: summary.projectedPay,
                  currency: currency,
                  onExpand: () => viewStore.setStaffCompact(roomId, false),
                )
              : _StaffExpandedBody(
                  summary: summary,
                  currency: currency,
                  onCollapse: () => viewStore.setStaffCompact(roomId, true),
                ),
        );
      },
    );
  }
}

class _StaffCompactBar extends StatelessWidget {
  const _StaffCompactBar({
    required this.actualPay,
    required this.projectedPay,
    required this.currency,
    required this.onExpand,
  });

  final int actualPay;
  final int projectedPay;
  final NumberFormat currency;
  final VoidCallback onExpand;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '실근무 ',
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextSpan(
                  text: '${currency.format(actualPay)}원',
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                TextSpan(
                  text: ' · 예상 ',
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextSpan(
                  text: '${currency.format(projectedPay)}원',
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        GestureDetector(
          onTap: onExpand,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.only(left: 8, top: 4, bottom: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '상세히 보기',
                  style: textTheme.labelSmall?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Icon(
                  Icons.expand_more_rounded,
                  size: 18,
                  color: AppColors.textPrimary,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StaffExpandedBody extends StatelessWidget {
  const _StaffExpandedBody({
    required this.summary,
    required this.currency,
    required this.onCollapse,
  });

  final WorkerMonthPaySummary summary;
  final NumberFormat currency;
  final VoidCallback onCollapse;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final remaining = summary.remainingSchedulePay;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${summary.monthLabel} 실근무 급여',
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            GestureDetector(
              onTap: onCollapse,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.only(left: 8, top: 2, bottom: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '간략히 보기',
                      style: textTheme.labelSmall?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Icon(
                      Icons.expand_less_rounded,
                      size: 18,
                      color: AppColors.textPrimary,
                    ),
                  ],
                ),
              ),
            ),
          ],
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
        const SizedBox(height: 10),
        Row(
          children: [
            const Icon(
              Icons.schedule_rounded,
              size: 18,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                summary.workedDays == 0
                    ? '퇴근 누적 ${formatStaffWorkHours(summary.actualNetMinutes)}'
                    : '퇴근 누적 ${formatStaffWorkHours(summary.actualNetMinutes)}'
                        ' · ${summary.workedDays}일',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Divider(height: 1),
        const SizedBox(height: 10),
        _PayLinkRow(
          label: '기본급',
          value: '${currency.format(summary.actualBasePay)}원',
        ),
        if (summary.actualWeeklyPay > 0)
          _PayLinkRow(
            label: '주휴수당',
            value: '${currency.format(summary.actualWeeklyPay)}원',
          ),
        if (summary.actualOvertimePay > 0)
          _PayLinkRow(
            label: '연장·야간',
            value: '${currency.format(summary.actualOvertimePay)}원',
          ),
        if (remaining > 0)
          _PayLinkRow(
            label: '남은 배정',
            value: '${currency.format(remaining)}원',
          ),
        _PayLinkRow(
          label: '이번 달 예상 급여',
          value: '${currency.format(summary.projectedPay)}원',
        ),
        const SizedBox(height: 4),
        Text(
          remaining > 0
              ? '예상 = 퇴근 확정분 + 남은 배정 + 주휴(주 15h↑)'
              : '퇴근할 때마다 실근무·예상에 반영됩니다.',
          style: textTheme.labelSmall?.copyWith(
            color: AppColors.textCaption,
          ),
        ),
      ],
    );
  }
}

class _PayLinkRow extends StatelessWidget {
  const _PayLinkRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style: textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
