import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/time/kst_date_time.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../core/widgets/sticky_action_button.dart';
import '../../../mock/mock_session.dart';
import '../../../mock/mock_store.dart';
import '../../../models/models.dart';
import '../presentation/shift_swap_request_sheet.dart';
import 'pay_breakdown_view.dart';
import 'pay_disclaimer_caption.dart';
import 'pending_change_card.dart';

/// 달력 상세보기용 근무일 카드 (내 근무표 기준 UI)
///
/// 접힘: 날짜·출퇴근·뱃지·급여 요약 / 펼침: 산정 내역
class ScheduleDayDetailCard extends StatefulWidget {
  const ScheduleDayDetailCard({
    super.key,
    required this.schedule,
    this.enableSwapRequest = true,
    this.showDate = true,
    this.headline,
    this.footer,
    this.extraBadges = const [],
  });

  final ScheduleModel schedule;

  /// 본인 근무·조건 충족 시 「대타 요청하기」 표시
  final bool enableSwapRequest;

  /// 상단 `M월 d일 (E)` 표기
  final bool showDate;

  /// 날짜 위 제목 (사장 달력의 직원 이름 등)
  final String? headline;

  /// 급여/대타 아래 추가 영역 (기간 합계, 사장 액션 등)
  final Widget? footer;

  final List<Widget> extraBadges;

  @override
  State<ScheduleDayDetailCard> createState() => _ScheduleDayDetailCardState();
}

class _ScheduleDayDetailCardState extends State<ScheduleDayDetailCard>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late final AnimationController _chevron;

  static final DateFormat _dayTitleFmt = DateFormat('M월 d일 (E)', 'ko_KR');
  static final DateFormat _timeFmt = DateFormat('HH:mm');

  ScheduleModel get s => widget.schedule;

  @override
  void initState() {
    super.initState();
    _chevron = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
  }

  @override
  void dispose() {
    _chevron.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    if (_expanded) {
      _chevron.forward();
    } else {
      _chevron.reverse();
    }
  }

  String _swapNoteLabel(ScheduleModel schedule) {
    final note = schedule.note ?? '';
    if (!note.startsWith('대타 승인')) return note;
    if (note.contains('요청자')) return note;

    final store = MockStore.instance;
    ShiftSwapRequest? approved;
    for (final swap in store.shiftSwaps.values) {
      if (swap.scheduleId == schedule.id &&
          swap.status == ShiftSwapStatus.approved) {
        approved = swap;
        break;
      }
    }
    if (approved == null) return note;
    final fromName =
        store.memberDisplayName(schedule.roomId, approved.fromWorkerId);
    final reason = approved.reason.trim().isEmpty
        ? null
        : approved.reason.trim();
    if (reason != null) {
      return '대타 승인 · 요청자 $fromName · 사유: $reason';
    }
    return '대타 승인 · 요청자 $fromName';
  }

  @override
  Widget build(BuildContext context) {
    final store = MockStore.instance;
    final uid = MockSession.instance.currentUser?.uid;
    final swap = store.openSwapForSchedule(s.id);
    final isMine = uid != null && s.workerId == uid;
    final today = DateTime(
      KstDateTime.now().year,
      KstDateTime.now().month,
      KstDateTime.now().day,
    );
    final scheduleDay = DateTime(
      s.startTime.year,
      s.startTime.month,
      s.startTime.day,
    );
    final clockOut = store.clockOutOnDate(
      s.roomId,
      s.workerId,
      s.startTime,
      scheduleId: s.id,
    );
    final clockedOut = clockOut != null;
    final canRequest = widget.enableSwapRequest &&
        isMine &&
        swap == null &&
        !s.isAbsent &&
        !clockedOut &&
        !scheduleDay.isBefore(today);

    final textTheme = Theme.of(context).textTheme;
    final muted = swap != null || s.isAbsent || clockedOut;
    final dayTitle = _dayTitleFmt.format(s.startTime);
    final headline = widget.headline;
    final hasHeadline = headline != null && headline.isNotEmpty;

    final actual = s.isAbsent
        ? null
        : store.actualPayEstimateOnDate(
            s.roomId,
            s.workerId,
            s.startTime,
          );
    final hasPay = !s.isAbsent &&
        (actual != null || s.estimatedPay != null);
    final payTitle = actual != null ? '실근무 급여' : '예상 급여';
    final payTotal = actual?.total ?? s.estimatedPay;

    return AppCard(
      padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
      onTap: hasPay ? _toggle : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (hasHeadline) ...[
                      Text(
                        headline,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                          color: muted
                              ? AppColors.textCaption
                              : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                    if (widget.showDate)
                      Text(
                        dayTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: (hasHeadline
                                ? textTheme.bodyMedium
                                : textTheme.titleMedium)
                            ?.copyWith(
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                          color: muted
                              ? AppColors.textCaption
                              : AppColors.textPrimary,
                        ),
                      ),
                    if (widget.showDate) const SizedBox(height: 4),
                    Text(
                      '${_timeFmt.format(s.startTime)} ~ '
                      '${_timeFmt.format(s.endTime)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: muted
                            ? AppColors.textCaption
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (hasPay)
                RotationTransition(
                  turns: Tween<double>(begin: 0, end: 0.5).animate(
                    CurvedAnimation(parent: _chevron, curve: Curves.easeOut),
                  ),
                  child: Icon(
                    Icons.expand_more_rounded,
                    size: 22,
                    color: AppColors.textSecondary.withValues(alpha: 0.75),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (s.isChangeRequested)
                const ChangeRequestedBadge()
              else if (!clockedOut)
                _StatusBadge(
                  label: s.attendanceStatusLabel,
                  color: s.isAbsent
                      ? AppColors.holiday
                      : s.isConfirmed
                          ? AppColors.success
                          : AppColors.warning,
                ),
              if (clockedOut)
                _StatusBadge(
                  label: '${_timeFmt.format(clockOut.timestamp)} 퇴근 완료',
                  color: AppColors.success,
                ),
              if (s.status != ScheduleStatus.normal && !s.isChangeRequested)
                _StatusBadge(
                  label: s.status.labelKo,
                  color: AppColors.secondary,
                ),
              if (swap != null)
                const _StatusBadge(
                  label: '대타 요청 중',
                  color: AppColors.warning,
                ),
              ...widget.extraBadges,
            ],
          ),
          if (s.isChangeRequested && s.pendingChange != null) ...[
            const SizedBox(height: 10),
            Text(
              '${_timeFmt.format(s.startTime)} ➔ '
              '${_timeFmt.format(s.pendingChange!.startTime)}'
              '  ·  '
              '${_timeFmt.format(s.endTime)} ➔ '
              '${_timeFmt.format(s.pendingChange!.endTime)}',
              style: textTheme.bodySmall?.copyWith(
                color: AppColors.warning,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (s.isAbsent) ...[
            const SizedBox(height: 10),
            Text(
              '사장님이 결근 처리한 근무입니다.',
              style: textTheme.bodySmall?.copyWith(
                color: AppColors.holiday,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          if (clockedOut) ...[
            const SizedBox(height: 10),
            Text(
              '${_timeFmt.format(clockOut.timestamp)}에 퇴근이 완료된 근무입니다.',
              style: textTheme.bodySmall?.copyWith(
                color: AppColors.success,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (swap != null) ...[
            const SizedBox(height: 10),
            Text(
              '${swap.status.labelKo} · '
              '${store.memberDisplayName(s.roomId, swap.toWorkerId)}에게 요청',
              style: textTheme.bodySmall?.copyWith(
                color: AppColors.warning,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          if (s.note != null &&
              s.note!.isNotEmpty &&
              s.note != '근무 배정') ...[
            const SizedBox(height: 10),
            Text(
              _swapNoteLabel(s),
              style: textTheme.bodyMedium?.copyWith(
                color: AppColors.textCaption,
              ),
            ),
          ],
          if (hasPay && payTotal != null) ...[
            const SizedBox(height: 12),
            Text(
              '$payTitle ${NumberFormat('#,###').format(payTotal)}원',
              style: textTheme.bodyLarge?.copyWith(
                color: AppColors.secondary,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
          ],
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _expanded && hasPay
                ? Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Divider(height: 1),
                        const SizedBox(height: 10),
                        if (actual != null)
                          PayBreakdownView(
                            schedule: s,
                            estimateOverride: actual,
                            titlePrefix: '실근무 급여',
                            showTitleTotal: false,
                          )
                        else
                          PayBreakdownView(
                            schedule: s,
                            showTitleTotal: false,
                          ),
                        const PayDisclaimerCaption(),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          if (canRequest) ...[
            const SizedBox(height: 14),
            StickyActionButton(
              label: '대타 요청하기',
              variant: StickyActionVariant.primary,
              onPressed: () async {
                final ok = await showShiftSwapRequestSheet(
                  context: context,
                  schedule: s,
                );
                if (ok && context.mounted) {
                  showAppSnackBar(
                    context,
                    message: '대타 요청을 보냈습니다.',
                  );
                }
              },
            ),
          ],
          if (widget.footer != null) ...[
            const SizedBox(height: 12),
            widget.footer!,
          ],
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});

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
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
      ),
    );
  }
}
