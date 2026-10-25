import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../mock/mock_store.dart';
import '../../../models/models.dart';
import '../schedule_store.dart';

/// 직원에게 표시되는 사장 발송 근무 일정 변경 요청 카드
class PendingChangeCard extends StatefulWidget {
  const PendingChangeCard({
    super.key,
    required this.schedule,
    this.onResolved,
    this.onApprove,
    this.onReject,
    this.busy = false,
  });

  final ScheduleModel schedule;
  final VoidCallback? onResolved;

  /// Firebase 등 외부 핸들러 (있으면 MockStore 대신 사용)
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final bool busy;

  @override
  State<PendingChangeCard> createState() => _PendingChangeCardState();
}

class _PendingChangeCardState extends State<PendingChangeCard> {
  bool _localBusy = false;

  bool get _busy => widget.busy || _localBusy;

  final _dayFmt = DateFormat('M월 d일', 'ko_KR');
  final _timeFmt = DateFormat('HH:mm');

  Future<void> _accept() async {
    if (widget.onApprove != null) {
      widget.onApprove!();
      return;
    }
    setState(() => _localBusy = true);
    try {
      ScheduleStore.acceptChange(widget.schedule.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('일정 변경을 수락했습니다. 근무표에 반영됩니다.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      widget.onResolved?.call();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), behavior: SnackBarBehavior.floating),
      );
    } finally {
      if (mounted) setState(() => _localBusy = false);
    }
  }

  Future<void> _reject() async {
    if (widget.onReject != null) {
      widget.onReject!();
      return;
    }
    final reasonController = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('변경 요청 거절'),
        content: TextField(
          controller: reasonController,
          maxLines: 3,
          autocorrect: false,
          enableSuggestions: false,
          spellCheckConfiguration: const SpellCheckConfiguration.disabled(),
          smartDashesType: SmartDashesType.disabled,
          smartQuotesType: SmartQuotesType.disabled,
          style: const TextStyle(decoration: TextDecoration.none),
          decoration: const InputDecoration(
            hintText: '거절 사유 (선택)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('거절하기'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) {
      reasonController.dispose();
      return;
    }
    setState(() => _localBusy = true);
    try {
      ScheduleStore.rejectChange(
        widget.schedule.id,
        rejectReason: reasonController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('변경 요청을 거절했습니다. 기존 일정이 유지됩니다.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      widget.onResolved?.call();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), behavior: SnackBarBehavior.floating),
      );
    } finally {
      reasonController.dispose();
      if (mounted) setState(() => _localBusy = false);
    }
  }

  String _formatRange(DateTime start, DateTime end) {
    final sameDay = start.year == end.year &&
        start.month == end.month &&
        start.day == end.day;
    if (sameDay) {
      return '${_dayFmt.format(start)}  '
          '${_timeFmt.format(start)} ~ ${_timeFmt.format(end)}';
    }
    return '${_dayFmt.format(start)} ${_timeFmt.format(start)}'
        ' ~ ${_dayFmt.format(end)} ${_timeFmt.format(end)}';
  }

  @override
  Widget build(BuildContext context) {
    final schedule = widget.schedule;
    final pending = schedule.pendingChange;
    if (pending == null || !pending.isPending) {
      return const SizedBox.shrink();
    }

    final textTheme = Theme.of(context).textTheme;
    final store = MockStore.instance;
    String? subName;
    if (pending.changeType == ScheduleChangeType.substitute &&
        pending.substituteWorkerId != null) {
      subName = store.memberDisplayName(
        schedule.roomId,
        pending.substituteWorkerId!,
      );
    }

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.schedule_send_rounded,
                color: AppColors.warning,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '근무 일정 변경 요청',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '변경 요청 중',
                  style: textTheme.labelSmall?.copyWith(
                    color: AppColors.warning,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            pending.changeType.labelKo,
            style: textTheme.labelLarge?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            '기존 근무',
            style: textTheme.labelSmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _formatRange(schedule.startTime, schedule.endTime),
            style: textTheme.bodyMedium?.copyWith(
              color: AppColors.textCaption,
              decoration: TextDecoration.lineThrough,
              decorationColor: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.arrow_downward_rounded,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: 6),
              Text(
                '요청 내용',
                style: textTheme.labelSmall?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (pending.changeType == ScheduleChangeType.cancel)
            Text(
              '근무 취소(휴무)로 변경',
              style: textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.holiday,
              ),
            )
          else if (pending.changeType == ScheduleChangeType.substitute)
            Text(
              '대체 직원 → ${subName ?? '미지정'}',
              style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w800),
            )
          else
            Text(
              _formatRange(pending.startTime, pending.endTime),
              style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
          if (pending.changeType == ScheduleChangeType.timeChange ||
              pending.changeType == ScheduleChangeType.dateChange) ...[
            const SizedBox(height: 6),
            Text(
              '${_timeFmt.format(schedule.startTime)}  ➔  '
              '${_timeFmt.format(pending.startTime)}'
              '   ·   '
              '${_timeFmt.format(schedule.endTime)}  ➔  '
              '${_timeFmt.format(pending.endTime)}',
              style: textTheme.bodySmall?.copyWith(
                color: AppColors.secondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '사장님 메시지',
                  style: textTheme.labelSmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  pending.reason,
                  style: textTheme.bodyMedium?.copyWith(height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy ? null : _reject,
                  child: const Text('거절하기'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _busy ? null : _accept,
                  child: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('수락하기'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 스케줄 카드용 변경 요청 중 뱃지
class ChangeRequestedBadge extends StatelessWidget {
  const ChangeRequestedBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '변경 요청 중',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.warning,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

/// 앱 진입 시 대기 중인 변경 요청을 팝업으로 표시
Future<bool?> showPendingChangeDialog(
  BuildContext context, {
  required ScheduleModel schedule,
}) {
  final pending = schedule.pendingChange;
  if (pending == null) return Future.value(null);

  final timeFmt = DateFormat('M/d HH:mm');

  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      title: const Text('근무 일정 변경 확인'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '현재 ${timeFmt.format(schedule.startTime)} ~ '
            '${timeFmt.format(schedule.endTime)}',
            style: Theme.of(ctx).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          Text(
            '요청 ${timeFmt.format(pending.startTime)} ~ '
            '${timeFmt.format(pending.endTime)}',
            style: Theme.of(ctx).textTheme.bodyLarge,
          ),
          const SizedBox(height: 12),
          Text(
            '사유: ${pending.reason}',
            style: Theme.of(ctx).textTheme.bodyMedium,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('거절'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('수락'),
        ),
      ],
    ),
  );
}
