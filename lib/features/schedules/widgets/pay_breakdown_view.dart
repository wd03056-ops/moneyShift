import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/models.dart';
import '../../../services/payroll_calculator.dart';

/// 표준근로계약서 참고용 — 총근무·휴게·실근로·기본급·가산·합계 산정 내역
class PayBreakdownView extends StatelessWidget {
  const PayBreakdownView({
    super.key,
    this.schedule,
    this.hourlyWage,
    this.compact = false,
    this.estimateOverride,
    this.titlePrefix = '예상 급여',
    this.showTitleTotal = true,
    this.cardTitle,
    this.dayCount = 1,
  }) : assert(
          schedule != null || estimateOverride != null,
          'schedule 또는 estimateOverride 중 하나는 필요합니다.',
        );

  final ScheduleModel? schedule;
  final int? hourlyWage;
  final bool compact;

  /// 실제 출퇴근 기준 산정 등 — 있으면 스케줄 배정 시간 대신 사용
  final PayEstimate? estimateOverride;

  /// 상단 요약 문구 접두사 (showTitleTotal 일 때)
  final String titlePrefix;

  /// 상단에 `예상 급여 N원` 한 줄 표시
  final bool showTitleTotal;

  /// 카드형 제목 (예: 산정 내역). null이면 제목 행 없음
  final String? cardTitle;

  /// 선택 일수 — 1보다 크면 금액에 곱해 합계에 반영
  final int dayCount;

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat('#,###');
    final schedule = this.schedule;
    final estimate = estimateOverride ??
        schedule?.payEstimate ??
        (schedule != null
            ? PayrollCalculator.fromSchedule(
                schedule,
                hourlyWage ??
                    schedule.payEstimate?.hourlyWage ??
                    AppConstants.minimumHourlyWage,
              )
            : estimateOverride!);

    final days = dayCount < 1 ? 1 : dayCount;
    final textTheme = Theme.of(context).textTheme;
    final showWeekly = estimate.includeWeeklyHoliday;
    final showOt = estimate.includeOvertimeNight;
    final wageLabel = NumberFormat('#,###').format(estimate.hourlyWage);
    final basePay = estimate.basePay * days;
    final weeklyPay = estimate.weeklyHolidayPay * days;
    final otPay = estimate.overtimeNightPay * days;
    final totalPay = estimate.total * days;
    final baseHint = days > 1
        ? '${estimate.netWorkedLabel} × $wageLabel원 × $days일'
        : '${estimate.netWorkedLabel} × $wageLabel원';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (cardTitle != null) ...[
          Text(cardTitle!, style: textTheme.titleSmall),
          const SizedBox(height: 8),
        ],
        if (showWeekly || showOt) ...[
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (showWeekly)
                const _PayBadge(label: '주휴수당', color: AppColors.secondary),
              if (showOt)
                const _PayBadge(label: '연장수당', color: AppColors.warning),
            ],
          ),
          const SizedBox(height: 8),
        ],
        if (showTitleTotal)
          Text(
            '$titlePrefix ${currency.format(totalPay)}원',
            style: textTheme.bodyLarge?.copyWith(
              color: AppColors.secondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        if (!compact) ...[
          if (showTitleTotal) const SizedBox(height: 8),
          _textLine(context, '적용 시급', '$wageLabel원'),
          _textLine(context, '총 근무시간', estimate.totalWorkedLabel),
          _textLine(context, '차감 휴게시간', estimate.breakLabel),
          _textLine(context, '인정 실 근로시간', estimate.netWorkedLabel),
          if (days > 1) _textLine(context, '선택 일수', '$days일'),
          const SizedBox(height: 6),
          _line(
            context,
            '기본급',
            basePay,
            currency,
            hint: baseHint,
          ),
          if (showWeekly || showOt) ...[
            const SizedBox(height: 4),
            Text(
              '가산 수당',
              style: textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (showWeekly)
              _line(context, '주휴수당', weeklyPay, currency),
            if (showOt)
              _line(
                context,
                '연장수당',
                otPay,
                currency,
                hint: _overtimeHint(estimate),
              ),
          ],
          const Divider(height: 16),
          _line(
            context,
            days > 1 ? '합계 ($days일)' : '합계',
            totalPay,
            currency,
            emphasize: true,
          ),
        ],
      ],
    );
  }

  String? _overtimeHint(PayEstimate e) {
    final parts = <String>[];
    if (e.overtimeMinutes > 0) {
      parts.add('연장 ${PayEstimate.formatDuration(e.overtimeMinutes)}');
    }
    if (e.nightMinutes > 0) {
      parts.add('야간 ${PayEstimate.formatDuration(e.nightMinutes)}');
    }
    if (parts.isEmpty) return null;
    return parts.join(' · ');
  }

  Widget _textLine(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }

  Widget _line(
    BuildContext context,
    String label,
    int amount,
    NumberFormat currency, {
    String? hint,
    bool emphasize = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              hint == null ? label : '$label ($hint)',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: emphasize
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                    fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
                  ),
            ),
          ),
          Text(
            '${currency.format(amount)}원',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
                  color: emphasize ? AppColors.secondary : null,
                ),
          ),
        ],
      ),
    );
  }
}

class _PayBadge extends StatelessWidget {
  const _PayBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
