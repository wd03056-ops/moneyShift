import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/calendar/snappy_calendar.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/time/kst_date_time.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_date_picker.dart';
import '../../../core/widgets/app_select_chip.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../core/widgets/app_text_input_defaults.dart';
import '../../../core/widgets/sticky_action_button.dart';
import '../../../mock/mock_store.dart';
import '../../../models/models.dart';
import '../schedule_store.dart';

/// 사장 — 배정된 근무에 대한 일정 변경 요청 바텀시트
class OwnerChangeRequestSheet extends StatefulWidget {
  const OwnerChangeRequestSheet({
    super.key,
    required this.schedule,
  });

  final ScheduleModel schedule;

  static Future<ScheduleModel?> show(
    BuildContext context, {
    required ScheduleModel schedule,
  }) {
    final block = ScheduleStore.changeBlockReason(schedule);
    if (block != null) {
      showAppSnackBar(context, message: block);
      return Future.value(null);
    }
    return showModalBottomSheet<ScheduleModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      sheetAnimationStyle: SnappyCalendar.sheetAnimationStyle,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => OwnerChangeRequestSheet(schedule: schedule),
    );
  }

  @override
  State<OwnerChangeRequestSheet> createState() =>
      _OwnerChangeRequestSheetState();
}

class _OwnerChangeRequestSheetState extends State<OwnerChangeRequestSheet> {
  late ScheduleChangeType _type;
  late DateTime _newStart;
  late DateTime _newEnd;
  final _reasonController = TextEditingController();
  String? _substituteWorkerId;
  bool _submitting = false;

  final _dayFmt = DateFormat('M월 d일 (E)', 'ko_KR');
  final _timeFmt = DateFormat('HH:mm');

  @override
  void initState() {
    super.initState();
    _type = ScheduleChangeType.timeChange;
    _newStart = widget.schedule.startTime;
    _newEnd = widget.schedule.endTime;
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime({required bool isStart}) async {
    final initial = isStart ? _newStart : _newEnd;
    final date = await showAppDatePicker(
      context: context,
      initialDate: initial,
      firstDate: KstDateTime.now().subtract(const Duration(days: 30)),
      lastDate: KstDateTime.now().add(const Duration(days: 365)),
      markedDays: {
        DateTime(
          widget.schedule.startTime.year,
          widget.schedule.startTime.month,
          widget.schedule.startTime.day,
        ),
      },
    );
    if (date == null || !mounted) return;

    // 날짜는 즉시 반영 — 시간 피커를 취소해도 날짜 변경은 유지
    var next = DateTime(
      date.year,
      date.month,
      date.day,
      initial.hour,
      initial.minute,
    );

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
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

    setState(() {
      if (isStart) {
        _newStart = next;
        // 같은 날 근무로 맞추고, 종료가 시작 이하면 1시간 뒤로
        _newEnd = DateTime(
          next.year,
          next.month,
          next.day,
          _newEnd.hour,
          _newEnd.minute,
        );
        if (!_newEnd.isAfter(_newStart)) {
          _newEnd = _newStart.add(const Duration(hours: 1));
        }
      } else {
        _newEnd = next;
        if (!_newEnd.isAfter(_newStart)) {
          _newEnd = _newStart.add(const Duration(hours: 1));
        }
      }
    });
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      final updated = ScheduleStore.requestChange(
        scheduleId: widget.schedule.id,
        changeType: _type,
        newStartTime: _newStart,
        newEndTime: _newEnd,
        reason: _reasonController.text,
        substituteWorkerId: _substituteWorkerId,
      );
      if (!mounted) return;
      // 시트 pop 전에 루트 ScaffoldMessenger에 등록 (dispose 후 호출 방지)
      showAppSnackBar(
        context,
        message: '일정 변경 요청을 보냈습니다. 직원 수락을 기다려 주세요.',
      );
      Navigator.of(context).pop(updated);
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, message: '$e');
      setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final s = widget.schedule;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final staff = MockStore.instance
        .activeStaffMembers(s.roomId)
        .where((m) => m.userId != s.workerId)
        .toList();
    final needsDateTime = _type == ScheduleChangeType.timeChange ||
        _type == ScheduleChangeType.dateChange;

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottom),
        child: Column(
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
              '일정 변경 요청',
              style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              '직원이 수락하면 근무표·캘린더·예상 급여에 바로 반영됩니다.',
              style: textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            AppCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '기존 근무',
                    style: textTheme.labelMedium?.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${_dayFmt.format(s.startTime)}  '
                    '${_timeFmt.format(s.startTime)} ~ ${_timeFmt.format(s.endTime)}',
                    style: textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text('변경 구분', style: textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in ScheduleChangeType.values)
                  AppSelectChip(
                    label: t.labelKo,
                    selected: _type == t,
                    onTap: _submitting
                        ? null
                        : () => setState(() => _type = t),
                  ),
              ],
            ),
            if (needsDateTime) ...[
              const SizedBox(height: 16),
              Text('변경 후 일시', style: textTheme.titleSmall),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _DateTimeTapField(
                      label: '시작',
                      value:
                          '${_dayFmt.format(_newStart)}\n${_timeFmt.format(_newStart)}',
                      enabled: !_submitting,
                      onTap: () => _pickDateTime(isStart: true),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      color: AppColors.primary,
                    ),
                  ),
                  Expanded(
                    child: _DateTimeTapField(
                      label: '종료',
                      value:
                          '${_dayFmt.format(_newEnd)}\n${_timeFmt.format(_newEnd)}',
                      enabled: !_submitting,
                      onTap: () => _pickDateTime(isStart: false),
                    ),
                  ),
                ],
              ),
            ],
            if (_type == ScheduleChangeType.substitute) ...[
              const SizedBox(height: 16),
              Text('대체 직원', style: textTheme.titleSmall),
              const SizedBox(height: 8),
              if (staff.isEmpty)
                Text(
                  '지명할 다른 직원이 없습니다.',
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.warning,
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final m in staff)
                      AppSelectChip(
                        label: m.displayName,
                        selected: _substituteWorkerId == m.userId,
                        onTap: _submitting
                            ? null
                            : () => setState(
                                  () => _substituteWorkerId = m.userId,
                                ),
                      ),
                  ],
                ),
            ],
            if (_type == ScheduleChangeType.cancel) ...[
              const SizedBox(height: 12),
              Text(
                '직원이 수락하면 해당 근무는 결근(휴무)으로 처리되고 급여에서 제외됩니다.',
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: 16),
            Text('변경 사유', style: textTheme.titleSmall),
            const SizedBox(height: 8),
            AppElevatedInputShell(
              child: TextField(
                controller: _reasonController,
                maxLines: 3,
                enabled: !_submitting,
                autocorrect: false,
                enableSuggestions: false,
                spellCheckConfiguration:
                    const SpellCheckConfiguration.disabled(),
                smartDashesType: SmartDashesType.disabled,
                smartQuotesType: SmartQuotesType.disabled,
                style: const TextStyle(decoration: TextDecoration.none),
                decoration: AppTextInputDefaults.decoration(
                  hintText: '예: 매장 자재 입고 시간 변경으로 1시간 늦게 출근 가능할까?',
                  labelText: '변경 사유',
                ),
              ),
            ),
            const SizedBox(height: 20),
            StickyActionButton(
              label: '변경 요청 보내기',
              variant: StickyActionVariant.filled,
              onPressed: _submitting ? null : _submit,
              isLoading: _submitting,
            ),
          ],
        ),
      ),
    );
  }
}

class _DateTimeTapField extends StatelessWidget {
  const _DateTimeTapField({
    required this.label,
    required this.value,
    required this.onTap,
    this.enabled = true,
  });

  final String label;
  final String value;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ),
                  const Icon(
                    Icons.edit_calendar_outlined,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                      color: enabled
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
