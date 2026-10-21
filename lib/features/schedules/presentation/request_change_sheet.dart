import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/calendar/snappy_calendar.dart';
import '../../../core/time/kst_date_time.dart';
import '../../../core/widgets/app_date_picker.dart';
import '../../../models/models.dart';
import '../../../services/schedule_repository.dart';

/// 근무시간 변경 요청 바텀시트 (즉시 반영하지 않음)
class RequestChangeSheet extends StatefulWidget {
  const RequestChangeSheet({
    super.key,
    required this.schedule,
    this.repository,
  });

  final ScheduleModel schedule;
  final ScheduleRepository? repository;

  static Future<ScheduleModel?> show(
    BuildContext context, {
    required ScheduleModel schedule,
  }) {
    return showModalBottomSheet<ScheduleModel>(
      context: context,
      isScrollControlled: true,
      sheetAnimationStyle: SnappyCalendar.sheetAnimationStyle,
      builder: (_) => RequestChangeSheet(schedule: schedule),
    );
  }

  @override
  State<RequestChangeSheet> createState() => _RequestChangeSheetState();
}

class _RequestChangeSheetState extends State<RequestChangeSheet> {
  late final ScheduleRepository _repo =
      widget.repository ?? ScheduleRepository();
  late DateTime _start;
  late DateTime _end;
  final _reasonController = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _start = widget.schedule.startTime;
    _end = widget.schedule.endTime;
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _pickStart() async {
    final date = await showAppDatePicker(
      context: context,
      initialDate: _start,
      firstDate: KstDateTime.now().subtract(const Duration(days: 365)),
      lastDate: KstDateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;

    var next = DateTime(
      date.year,
      date.month,
      date.day,
      _start.hour,
      _start.minute,
    );
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_start),
      initialEntryMode: TimePickerEntryMode.inputOnly,
    );
    if (!mounted) return;
    if (time != null) {
      next = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    }
    setState(() => _start = next);
  }

  Future<void> _pickEnd() async {
    final date = await showAppDatePicker(
      context: context,
      initialDate: _end,
      firstDate: KstDateTime.now().subtract(const Duration(days: 365)),
      lastDate: KstDateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;

    var next = DateTime(
      date.year,
      date.month,
      date.day,
      _end.hour,
      _end.minute,
    );
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_end),
      initialEntryMode: TimePickerEntryMode.inputOnly,
    );
    if (!mounted) return;
    if (time != null) {
      next = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    }
    setState(() => _end = next);
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      final updated = await _repo.requestTimeChange(
        scheduleId: widget.schedule.id,
        newStartTime: _start,
        newEndTime: _end,
        reason: _reasonController.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop(updated);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('요청 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('yyyy-MM-dd HH:mm');
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '근무시간 변경 요청',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              '상대방 확인 후에만 반영되며, 확인 시 급여에도 적용됩니다.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('새 시작'),
              subtitle: Text(fmt.format(_start)),
              trailing: const Icon(Icons.edit_calendar),
              onTap: _submitting ? null : _pickStart,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('새 종료'),
              subtitle: Text(fmt.format(_end)),
              trailing: const Icon(Icons.edit_calendar),
              onTap: _submitting ? null : _pickEnd,
            ),
            TextField(
              controller: _reasonController,
              decoration: const InputDecoration(
                labelText: '수정 사유',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('확인 요청 보내기'),
            ),
          ],
        ),
      ),
    );
  }
}
