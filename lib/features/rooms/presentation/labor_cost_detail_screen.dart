import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_decorations.dart';
import '../../../core/time/kst_date_time.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/outlined_toggle.dart';
import '../../../core/widgets/scrollable_page_body.dart';
import '../../../mock/mock_store.dart';
import '../../../models/models.dart';
import '../../../services/labor_cost_memo.dart';
import '../../../services/month_payroll_aggregator.dart';

/// 사장 — 이번 달 직원별 급여 상세 현황
class LaborCostDetailScreen extends StatefulWidget {
  const LaborCostDetailScreen({
    super.key,
    required this.room,
    this.includeWeeklyHoliday = false,
    this.includeEmployerInsurance = false,
  });

  final RoomModel room;
  final bool includeWeeklyHoliday;
  final bool includeEmployerInsurance;

  @override
  State<LaborCostDetailScreen> createState() => _LaborCostDetailScreenState();
}

class _LaborCostDetailScreenState extends State<LaborCostDetailScreen> {
  static final _won = NumberFormat('#,###', 'ko_KR');
  static final _hours = NumberFormat('#,##0.#', 'ko_KR');

  late bool _includeWeeklyHoliday;
  late bool _includeEmployerInsurance;

  @override
  void initState() {
    super.initState();
    _includeWeeklyHoliday = widget.includeWeeklyHoliday;
    _includeEmployerInsurance = widget.includeEmployerInsurance;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: MockStore.instance,
      builder: (context, _) {
        final store = MockStore.instance;
        final liveRoom = store.rooms[widget.room.id] ?? widget.room;
        final now = KstDateTime.now();
        final year = now.year;
        final month = now.month;

        final memoKey = '${liveRoom.id}|$year|$month|'
            'w=$_includeWeeklyHoliday|i=$_includeEmployerInsurance|'
            'r=${store.dataRevision}';
        final summary = LaborCostMemo.room(
          key: memoKey,
          compute: () => MonthPayrollAggregator.forRoom(
            store: store,
            roomId: liveRoom.id,
            year: year,
            month: month,
            includeWeeklyHoliday: _includeWeeklyHoliday,
            includeEmployerSocialInsurance: _includeEmployerInsurance,
          ),
        );
        final rows = LaborCostMemo.rows(
          key: 'rows|$memoKey',
          compute: () => MonthPayrollAggregator.workerRowsForRoom(
            store: store,
            roomId: liveRoom.id,
            year: year,
            month: month,
            includeWeeklyHoliday: _includeWeeklyHoliday,
          ),
        );

        final rowsSum = MonthPayrollAggregator.sumWorkerRowPay(rows);
        assert(
          rowsSum == summary.totalLaborCost,
          '인건비 상세 행 합($rowsSum) ≠ 대시보드 총액(${summary.totalLaborCost})',
        );
        final displayTotal = _includeEmployerInsurance
            ? summary.totalWithEmployerBurden
            : summary.totalLaborCost;

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            title: const Text('이번 달 인건비 상세 내역'),
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
          ),
          body: ScrollablePageBody(
            top: false,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SummaryCard(
                  totalPay: displayTotal,
                  workHours: summary.totalWorkHours,
                  workerCount: summary.activeWorkerCount,
                  periodFrom: summary.periodFrom,
                  periodTo: summary.periodTo,
                  includeWeeklyHoliday: _includeWeeklyHoliday,
                  includeEmployerInsurance: _includeEmployerInsurance,
                  insurance: summary.employerSocialInsuranceEstimate,
                  wonFormat: _won,
                  hoursFormat: _hours,
                ),
                const SizedBox(height: 16),
                AppCard(
                  padding: const EdgeInsets.fromLTRB(14, 6, 10, 6),
                  child: Column(
                    children: [
                      _LaborOptionSwitch(
                        label: '주휴수당 포함',
                        value: _includeWeeklyHoliday,
                        onChanged: (v) =>
                            setState(() => _includeWeeklyHoliday = v),
                      ),
                      const Divider(height: 1),
                      _LaborOptionSwitch(
                        label: '4대보험 포함',
                        value: _includeEmployerInsurance,
                        onChanged: (v) =>
                            setState(() => _includeEmployerInsurance = v),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  '직원별 급여',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  liveRoom.name,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
                const SizedBox(height: 12),
                if (rows.isEmpty)
                  AppCard(
                    child: Text(
                      '이번 달 집계된 근무·출퇴근 기록이 없습니다.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  )
                else
                  for (var i = 0; i < rows.length; i++) ...[
                    if (i > 0) const SizedBox(height: 10),
                    _WorkerPayExpandCard(
                      row: rows[i],
                      wonFormat: _won,
                      hoursFormat: _hours,
                    ),
                  ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LaborOptionSwitch extends StatelessWidget {
  const _LaborOptionSwitch({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          OutlinedToggle(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.totalPay,
    required this.workHours,
    required this.workerCount,
    required this.periodFrom,
    required this.periodTo,
    required this.includeWeeklyHoliday,
    required this.includeEmployerInsurance,
    required this.insurance,
    required this.wonFormat,
    required this.hoursFormat,
  });

  final int totalPay;
  final double workHours;
  final int workerCount;
  final String periodFrom;
  final String periodTo;
  final bool includeWeeklyHoliday;
  final bool includeEmployerInsurance;
  final int insurance;
  final NumberFormat wonFormat;
  final NumberFormat hoursFormat;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final period = periodFrom.length >= 10 && periodTo.length >= 10
        ? formatLaborCostPeriodLabel(periodFrom, periodTo)
        : null;

    return DecoratedBox(
      decoration: AppDecorations.borderedSurface(radius: 16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '이번 달 총 누적 인건비',
              style: textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: wonFormat.format(totalPay),
                    style: textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 30,
                      letterSpacing: -0.8,
                      color: AppColors.textPrimary,
                      height: 1.1,
                    ),
                  ),
                  TextSpan(
                    text: '원',
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              [
                '근무 직원 $workerCount명',
                '총 ${hoursFormat.format(workHours)}시간',
                ?period,
              ].join('  ·  '),
              style: textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                height: 1.35,
              ),
            ),
            if (includeWeeklyHoliday || includeEmployerInsurance) ...[
              const SizedBox(height: 8),
              Text(
                [
                  if (includeWeeklyHoliday) '주휴수당 포함',
                  if (includeEmployerInsurance)
                    '4대보험 약 ${wonFormat.format(insurance)}원',
                ].join(' · '),
                style: textTheme.labelSmall?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _WorkerPayExpandCard extends StatelessWidget {
  const _WorkerPayExpandCard({
    required this.row,
    required this.wonFormat,
    required this.hoursFormat,
  });

  final WorkerLaborCostRow row;
  final NumberFormat wonFormat;
  final NumberFormat hoursFormat;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: AppDecorations.borderedSurface(radius: 14),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.fromLTRB(14, 4, 10, 4),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          shape: const RoundedRectangleBorder(),
          collapsedShape: const RoundedRectangleBorder(),
          title: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primarySoft,
                child: Text(
                  row.displayName.isNotEmpty
                      ? String.fromCharCode(row.displayName.runes.first)
                      : '?',
                  style: textTheme.titleSmall?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            row.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        _RoleChip(label: row.roleLabel),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        '시급 ${wonFormat.format(row.hourlyWage)}원',
                        '${hoursFormat.format(row.workHours)}시간',
                        if (row.workedDays > 0) '${row.workedDays}일',
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.labelSmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8, left: 46),
            child: Text(
              '${wonFormat.format(row.totalPay)}원',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: -0.4,
              ),
            ),
          ),
          children: [
            const Divider(height: 1),
            const SizedBox(height: 10),
            _BreakdownRow(
              label: '기본 급여',
              value: '${wonFormat.format(row.basePay)}원',
            ),
            if (row.weeklyHolidayPay > 0)
              _BreakdownRow(
                label: '주휴수당',
                value: '${wonFormat.format(row.weeklyHolidayPay)}원',
              ),
            if (row.overtimePay > 0)
              _BreakdownRow(
                label: '연장수당',
                value: '${wonFormat.format(row.overtimePay)}원',
              ),
            if (row.nightPay > 0)
              _BreakdownRow(
                label: '야간수당',
                value: '${wonFormat.format(row.nightPay)}원',
              ),
            if (row.weeklyHolidayPay == 0 &&
                row.overtimePay == 0 &&
                row.nightPay == 0)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '수당 내역 없음 (기본 급여만)',
                  style: textTheme.labelSmall?.copyWith(
                    color: AppColors.textCaption,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            _BreakdownRow(
              label: '합계',
              value: '${wonFormat.format(row.totalPay)}원',
              emphasize: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.badgeStaffBg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.badgeStaffFg,
              fontWeight: FontWeight.w700,
              fontSize: 10,
            ),
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontWeight: emphasize ? FontWeight.w800 : FontWeight.w500,
          color: emphasize ? AppColors.textPrimary : AppColors.textSecondary,
        );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style),
        ],
      ),
    );
  }
}
