import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/navigation/app_navigator.dart';
import '../../../core/theme/app_colors.dart';
import '../../../mock/mock_store.dart';
import '../../../models/commute_correction_request.dart';

/// 알바생 — 근태 수정 승인/거절 (`/requests/commute-correction`)
abstract final class CommuteCorrectionReview {
  CommuteCorrectionReview._();

  static Future<void> openById(String requestId) async {
    final ctx = appNavigatorKey.currentContext;
    if (ctx == null || !ctx.mounted) return;
    final req = MockStore.instance.commuteCorrectionById(requestId);
    if (req == null) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        const SnackBar(
          content: Text('근태 수정 요청을 찾을 수 없습니다.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    await show(ctx, req);
  }

  static Future<void> show(
    BuildContext context,
    CommuteCorrectionRequest req,
  ) {
    return showDialog<void>(
      context: context,
      builder: (_) => _CommuteCorrectionReviewDialog(request: req),
    );
  }
}

class _CommuteCorrectionReviewDialog extends StatefulWidget {
  const _CommuteCorrectionReviewDialog({required this.request});

  final CommuteCorrectionRequest request;

  @override
  State<_CommuteCorrectionReviewDialog> createState() =>
      _CommuteCorrectionReviewDialogState();
}

class _CommuteCorrectionReviewDialogState
    extends State<_CommuteCorrectionReviewDialog> {
  bool _busy = false;
  final _fmt = DateFormat('HH:mm');

  String _fmtTime(DateTime? t) => t == null ? '-' : _fmt.format(t);

  Future<void> _resolve(bool approve) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (approve) {
        MockStore.instance.approveCommuteCorrection(widget.request.id);
      } else {
        MockStore.instance.rejectCommuteCorrection(widget.request.id);
      }
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(approve ? '근태 수정을 승인했습니다.' : '근태 수정을 거절했습니다.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final req = widget.request;
    final storeName =
        MockStore.instance.rooms[req.roomId]?.name ?? '매장';
    final canAct = req.status.isOpen;

    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      title: const Text('근태 수정 요청'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              storeName,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 10),
            Text(
              '의도: ${req.intent.labelKo}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            _CompareRow(
              label: '출근',
              before: _fmtTime(req.originalClockIn),
              after: _fmtTime(req.proposedClockIn),
            ),
            const SizedBox(height: 6),
            _CompareRow(
              label: '퇴근',
              before: _fmtTime(req.originalClockOut),
              after: _fmtTime(req.proposedClockOut),
            ),
            if (req.reason.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                '사유',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              Text(req.reason),
            ],
            if (!canAct) ...[
              const SizedBox(height: 12),
              Text(
                '이미 ${req.status.labelKo} 처리되었습니다.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.holiday,
                    ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('닫기'),
        ),
        if (canAct) ...[
          TextButton(
            onPressed: _busy ? null : () => _resolve(false),
            child: const Text('거절'),
          ),
          FilledButton(
            onPressed: _busy ? null : () => _resolve(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.buttonFill,
              foregroundColor: AppColors.buttonOnFill,
            ),
            child: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('승인'),
          ),
        ],
      ],
    );
  }
}

class _CompareRow extends StatelessWidget {
  const _CompareRow({
    required this.label,
    required this.before,
    required this.after,
  });

  final String label;
  final String before;
  final String after;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 40,
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ),
        Expanded(child: Text(before)),
        const Icon(Icons.arrow_forward, size: 16, color: AppColors.textCaption),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            after,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}
