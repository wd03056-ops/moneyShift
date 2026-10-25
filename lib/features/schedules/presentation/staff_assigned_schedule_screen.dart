import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/navigation/app_navigation.dart';
import '../../../core/navigation/app_route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../core/widgets/scrollable_page_body.dart';
import '../../../core/widgets/sticky_action_button.dart';
import '../../../models/models.dart';
import '../schedule_store.dart';
import '../utils/schedule_summary_formatter.dart';
import '../widgets/pay_disclaimer_caption.dart';
import 'staff_assigned_detail_screen.dart';

/// 사장이 배정한 확인 대기 근무를 한눈에 모아 보는 화면
class StaffAssignedScheduleScreen extends StatefulWidget {
  const StaffAssignedScheduleScreen({
    super.key,
    required this.roomId,
    required this.workerId,
  });

  final String roomId;
  final String workerId;

  @override
  State<StaffAssignedScheduleScreen> createState() =>
      _StaffAssignedScheduleScreenState();
}

class _StaffAssignedScheduleScreenState
    extends State<StaffAssignedScheduleScreen> {
  bool _busy = false;
  bool _completed = false;

  Future<void> _confirmAll() async {
    if (_busy || _completed) return;
    setState(() => _busy = true);
    final count = ScheduleStore.confirmAllPending(
      roomId: widget.roomId,
      workerId: widget.workerId,
    );
    if (!mounted) return;
    if (count <= 0) {
      showAppSnackBar(
        context,
        message: '확인할 근무가 없습니다.',
        aboveStickyActions: true,
      );
      setState(() => _busy = false);
      return;
    }
    showAppSnackBar(
      context,
      message: '완료되었습니다',
      aboveStickyActions: true,
    );
    setState(() {
      _busy = false;
      _completed = true;
    });
    // 화면·스택 유지 — 목록은 ListenableBuilder로 갱신됨
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat('#,###');

    return ListenableBuilder(
      listenable: ScheduleStore.listenable,
      builder: (context, _) {
        final units =
            ScheduleStore.pendingUnits(widget.roomId, widget.workerId);
        final pending =
            ScheduleStore.pendingForWorker(widget.roomId, widget.workerId);

        final totalPay = pending.fold<int>(
          0,
          (sum, s) => sum + (s.estimatedPay ?? 0),
        );
        final hasWeekly = pending.any((s) => s.includeWeeklyHoliday);
        final hasOvertime = pending.any((s) => s.includeOvertimeNight);
        final hasPending = pending.isNotEmpty;

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            title: const Text('근무 배정표'),
          ),
          body: FixedBottomPage(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            bottom: (hasPending || _completed)
                ? StickyActionBar(
                    safeAreaBottom: true,
                    elevated: true,
                    children: [
                      StickyActionButton(
                        label: '전체 확인',
                        variant: StickyActionVariant.filled,
                        enabled: !_busy && !_completed && hasPending,
                        isLoading: _busy,
                        isCompleted: _completed || !hasPending,
                        completedLabel: '처리 완료',
                        onPressed: (_busy || _completed || !hasPending)
                            ? null
                            : _confirmAll,
                      ),
                    ],
                  )
                : null,
            body: units.isEmpty
                ? Center(
                    child: Text(
                      '확인할 근무가 없습니다.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '배정된 근무',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '아래 일정을 확인한 뒤 상세보기에서 근무표를 확인하세요.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          const _Badge(
                            label: '확인 대기',
                            color: AppColors.warning,
                          ),
                          if (hasWeekly)
                            const _Badge(
                              label: '주휴수당',
                              color: AppColors.secondary,
                            ),
                          if (hasOvertime)
                            const _Badge(
                              label: '연장수당',
                              color: AppColors.warning,
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      for (var i = 0; i < units.length; i++) ...[
                        if (i > 0) const SizedBox(height: 10),
                        _PendingUnitCard(
                          schedules: units[i],
                          currency: currency,
                          onOpenCalendar: () {
                            final unit = units[i];
                            final key = unit.first.assignmentBatchId ??
                                unit.first.id;
                            AppNavigation.pushSingleTop(
                              name: AppRouteNames.assignedDetail(key),
                              stopAtNames: [
                                AppRouteNames.assignedSchedule(widget.roomId),
                              ],
                              builder: (_) => StaffAssignedDetailScreen(
                                schedules: unit,
                              ),
                            );
                          },
                        ),
                      ],
                      if (units.length > 1) ...[
                        const SizedBox(height: 12),
                        AppCard(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '합계',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyLarge
                                      ?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ),
                              Text(
                                '${currency.format(totalPay)}원',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.secondary,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const PayDisclaimerCaption(
                        padding: EdgeInsets.only(top: 10),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}

class _PendingUnitCard extends StatelessWidget {
  const _PendingUnitCard({
    required this.schedules,
    required this.currency,
    required this.onOpenCalendar,
  });

  final List<ScheduleModel> schedules;
  final NumberFormat currency;
  final VoidCallback onOpenCalendar;

  int get _totalPay => schedules.fold<int>(
        0,
        (sum, s) => sum + (s.estimatedPay ?? 0),
      );

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final datesLine = formatScheduleDatesOnly(schedules);

    return AppCard(
      onTap: onOpenCalendar,
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  datesLine,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (_totalPay > 0) ...[
                  const SizedBox(height: 8),
                  Text(
                    '예상 급여 ${currency.format(_totalPay)}원',
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.secondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          TextButton(
            onPressed: onOpenCalendar,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              '상세보기',
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});

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
