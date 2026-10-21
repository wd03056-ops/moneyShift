import 'package:flutter/material.dart';

import '../../../core/calendar/snappy_calendar.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_option_picker.dart';
import '../../../core/widgets/sticky_action_button.dart';
import '../../../mock/mock_session.dart';
import '../../../mock/mock_store.dart';
import '../../../models/models.dart';

/// 직원 — 대타 요청 바텀시트
Future<bool> showShiftSwapRequestSheet({
  required BuildContext context,
  required ScheduleModel schedule,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    sheetAnimationStyle: SnappyCalendar.sheetAnimationStyle,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => _ShiftSwapRequestSheet(schedule: schedule),
  );
  return result == true;
}

class _ShiftSwapRequestSheet extends StatefulWidget {
  const _ShiftSwapRequestSheet({required this.schedule});

  final ScheduleModel schedule;

  @override
  State<_ShiftSwapRequestSheet> createState() => _ShiftSwapRequestSheetState();
}

class _ShiftSwapRequestSheetState extends State<_ShiftSwapRequestSheet> {
  final _reasonCtrl = TextEditingController();
  String? _toWorkerId;
  bool _submitting = false;

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final toId = _toWorkerId;
    if (toId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('대타를 부탁할 동료를 선택해 주세요.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      MockStore.instance.requestShiftSwap(
        scheduleId: widget.schedule.id,
        toWorkerId: toId,
        reason: _reasonCtrl.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = MockSession.instance.requireUid;
    final staff = MockStore.instance
        .activeStaffMembers(widget.schedule.roomId)
        .where((m) => m.userId != uid)
        .toList();
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '대타 요청하기',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            '동료 수락 후 사장님이 최종 승인하면 근무자가 교체됩니다.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.35,
                ),
          ),
          const SizedBox(height: 16),
          Text('대타 동료', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          AppOptionPickerField<String>(
            title: '대타 동료 선택',
            hint: '동료를 선택하세요',
            enabled: !_submitting,
            selected: _toWorkerId,
            options: [
              for (final m in staff)
                AppPickerOption(
                  value: m.userId,
                  label: '${m.displayName} · ${m.role.labelKo}',
                ),
            ],
            onSelected: (v) => setState(() => _toWorkerId = v),
          ),
          const SizedBox(height: 14),
          Text('사유', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          AppBorderedField(
            height: null,
            child: AppPlainTextField(
              controller: _reasonCtrl,
              enabled: !_submitting,
              maxLines: 3,
              minLines: 2,
              hintText: '예: 개인 사정으로 근무가 어렵습니다.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.textPrimary,
                  ),
            ),
          ),
          const SizedBox(height: 20),
          StickyActionButton(
            label: '대타 요청 보내기',
            variant: StickyActionVariant.filled,
            enabled: !_submitting && staff.isNotEmpty,
            isLoading: _submitting,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}
