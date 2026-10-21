import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/time/kst_date_time.dart';
import '../../../core/widgets/app_select_chip.dart';
import '../../../mock/mock_store.dart';
import '../../../models/enums/commute_correction_status.dart';
import 'owner_commute_dashboard_screen.dart';

/// 사장 직권 근태 수정 → pending 요청 생성 (즉시 반영 안 함)
class CommuteCorrectionSheet extends StatefulWidget {
  const CommuteCorrectionSheet({
    super.key,
    required this.roomId,
    required this.row,
  });

  final String roomId;
  final CommuteEmployeeRow row;

  static Future<void> show(
    BuildContext context, {
    required String roomId,
    required CommuteEmployeeRow row,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: CommuteCorrectionSheet(roomId: roomId, row: row),
      ),
    );
  }

  @override
  State<CommuteCorrectionSheet> createState() => _CommuteCorrectionSheetState();
}

class _CommuteCorrectionSheetState extends State<CommuteCorrectionSheet> {
  late CommuteCorrectionIntent _intent;
  late TimeOfDay? _clockIn;
  late TimeOfDay? _clockOut;
  final _reasonCtrl = TextEditingController();
  bool _submitting = false;
  final _timeFmt = DateFormat('HH:mm');

  @override
  void initState() {
    super.initState();
    _intent = CommuteCorrectionIntent.normal;
    final cin = widget.row.clockIn?.timestamp;
    final cout = widget.row.clockOut?.timestamp;
    final start = widget.row.schedule?.startTime;
    final end = widget.row.schedule?.endTime;
    _clockIn = cin != null
        ? TimeOfDay(hour: cin.hour, minute: cin.minute)
        : (start != null
            ? TimeOfDay(hour: start.hour, minute: start.minute)
            : null);
    _clockOut = cout != null
        ? TimeOfDay(hour: cout.hour, minute: cout.minute)
        : (end != null
            ? TimeOfDay(hour: end.hour, minute: end.minute)
            : null);
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  DateTime? _combine(TimeOfDay? t) {
    if (t == null) return null;
    final d = KstDateTime.today();
    return DateTime(d.year, d.month, d.day, t.hour, t.minute);
  }

  Future<void> _pickIn() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _clockIn ?? TimeOfDay.now(),
      initialEntryMode: TimePickerEntryMode.inputOnly,
    );
    if (picked != null && mounted) setState(() => _clockIn = picked);
  }

  Future<void> _pickOut() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _clockOut ?? TimeOfDay.now(),
      initialEntryMode: TimePickerEntryMode.inputOnly,
    );
    if (picked != null && mounted) setState(() => _clockOut = picked);
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      MockStore.instance.requestCommuteCorrection(
        roomId: widget.roomId,
        workerId: widget.row.workerId,
        intent: _intent,
        proposedClockIn: _intent == CommuteCorrectionIntent.absent
            ? null
            : _combine(_clockIn),
        proposedClockOut: _intent == CommuteCorrectionIntent.absent
            ? null
            : _combine(_clockOut),
        reason: _reasonCtrl.text,
        scheduleId: widget.row.schedule?.id,
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('근태 수정 요청을 보냈습니다. 직원 승인 후 반영됩니다.'),
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
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final row = widget.row;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
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
            const SizedBox(height: 14),
            Text(
              '근태 수정 · ${row.displayName}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              '즉시 반영되지 않으며, 직원 승인 후 적용됩니다.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(height: 14),
            Text(
              '기존 기록',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.textCaption,
                  ),
            ),
            Text(
              '출근 ${row.clockIn == null ? '-' : _timeFmt.format(row.clockIn!.timestamp)}'
              '  ·  퇴근 ${row.clockOut == null ? '-' : _timeFmt.format(row.clockOut!.timestamp)}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Text(
              '상태',
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final intent in CommuteCorrectionIntent.values)
                  AppSelectChip(
                    label: intent.labelKo,
                    selected: _intent == intent,
                    onTap: _submitting
                        ? null
                        : () => setState(() => _intent = intent),
                  ),
              ],
            ),
            if (_intent != CommuteCorrectionIntent.absent) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _submitting ? null : _pickIn,
                      child: Text(
                        '출근 ${_clockIn?.format(context) ?? '-'}',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _submitting ? null : _pickOut,
                      child: Text(
                        '퇴근 ${_clockOut?.format(context) ?? '-'}',
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 14),
            TextField(
              controller: _reasonCtrl,
              enabled: !_submitting,
              maxLines: 2,
              maxLength: 120,
              decoration: const InputDecoration(
                labelText: '수정 사유 (필수)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.buttonFill,
                foregroundColor: AppColors.buttonOnFill,
                minimumSize: const Size.fromHeight(48),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('수정 요청 보내기'),
            ),
          ],
        ),
      ),
    );
  }
}
