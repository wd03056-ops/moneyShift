import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../core/async/action_guard.dart';
import '../../../core/calendar/korean_holidays.dart';
import '../../../core/calendar/snappy_calendar.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/exceptions/schedule_exceptions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/time/date_only.dart';
import '../../../core/time/kst_date_time.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_select_chip.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../core/widgets/outlined_toggle.dart';
import '../../../core/widgets/scrollable_page_body.dart';
import '../../../core/widgets/sticky_action_button.dart';
import '../../../mock/mock_store.dart';
import '../../../models/models.dart';
import '../../../services/payroll_calculator.dart';
import '../widgets/pay_breakdown_view.dart';
import '../widgets/pay_disclaimer_caption.dart';

enum _DatePickMode {
  /// 10/3, 10/7처럼 찍은 날만
  individual,

  /// 10/1 ~ 10/31처럼 사이 날짜 전부
  range,

  /// 기간 안 선택한 요일만 (예: 매주 월/수/금)
  weekly,
}

/// 사장 — 직원 선택 · 날짜(개별/기간) · 출퇴근 · 예상 급여로 근무표 배정
class CreateScheduleScreen extends StatefulWidget {
  const CreateScheduleScreen({
    super.key,
    required this.room,
    this.initialStaff,
    this.initialDate,
  });

  final RoomModel room;

  /// 특정 직원으로 미리 선택한 경우 (근무표 상세 등)
  final RoomMemberModel? initialStaff;

  /// 달력에서 고른 날짜 — 개별 모드로 미리 선택
  final DateTime? initialDate;

  @override
  State<CreateScheduleScreen> createState() => _CreateScheduleScreenState();
}

class _CreateScheduleScreenState extends State<CreateScheduleScreen> {
  final _wageController = TextEditingController();

  RoomMemberModel? _selectedStaff;
  _DatePickMode _mode = _DatePickMode.individual;

  /// 개별 선택 날짜 (date-only)
  final Set<DateTime> _selectedDates = {};

  /// 기간 선택
  DateTime? _rangeStart;
  DateTime? _rangeEnd;

  /// 기간 안에서도 쉬어야 해서 제외한 날짜
  final Set<DateTime> _excludedInRange = {};

  /// 매주 반복 요일 (DateTime.weekday: 월=1 … 일=7) — 기본 미선택
  final Set<int> _weeklyWeekdays = {};

  static const _weekdayLabels = <int, String>{
    DateTime.monday: '월',
    DateTime.tuesday: '화',
    DateTime.wednesday: '수',
    DateTime.thursday: '목',
    DateTime.friday: '금',
    DateTime.saturday: '토',
    DateTime.sunday: '일',
  };

  late DateTime _focusedDay;
  /// 직원 전환 시 달력 즉시 재마운트 (선택 해제 AnimatedContainer 방지)
  int _calendarEpoch = 0;
  TimeOfDay _start = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 18, minute: 0);

  /// 무급 휴게(분)
  int _breakMinutes = 60;
  bool _breakManuallySet = false;
  BreakTimeType _breakTimeType = BreakTimeType.auto;

  bool _includeWeeklyHoliday = false;
  bool _includeNightPay = false;
  bool _includeOvertimePay = false;
  bool _submitting = false;
  bool _assignCompleted = false;
  final _submitGuard = ActionGuard(cooldown: Duration(milliseconds: 1000));

  /// 고정 휴게 선택지(분). 자동계산은 별도 항목.
  static const List<int> _breakOptions = [0, 15, 30, 45, 60, 90, 120];

  /// 바텀시트 자동계산 선택 센티널
  static const int _breakAutoSentinel = -1;

  bool get _includeOvertimeNight =>
      _includeNightPay || _includeOvertimePay;

  bool get _isBreakAuto =>
      _breakTimeType == BreakTimeType.auto && !_breakManuallySet;

  static DateTime _dateOnly(DateTime d) => DateOnly.of(d);

  /// 신규 배정 가능 최소일 = 오늘(KST). 조회용 달력과 달리 과거는 비활성.
  DateTime get _minAssignableDay => KstDateTime.today();

  bool _isAssignableDay(DateTime day) =>
      !_dateOnly(day).isBefore(_minAssignableDay);

  static const String _pastAssignMessage =
      '지나간 날짜에는 새 근무를 배정할 수 없습니다.';

  void _showPastAssignBlocked() {
    if (!mounted) return;
    showAppSnackBar(
      context,
      message: _pastAssignMessage,
      aboveStickyActions: true,
    );
  }

  /// 한 번에 배정 가능한 최대 일수 (경계·성능 가드)
  static const int _maxAssignDays = 366;

  bool get _rangeComplete => _rangeStart != null && _rangeEnd != null;

  bool _isExcluded(DateTime day) =>
      _excludedInRange.any((d) => isSameDay(d, day));

  /// 제외 전 기간 전체 일수 (월말·윤년 안전 일 단위 증가)
  List<DateTime> get _rangeDaysRaw {
    if (_rangeStart == null) return const [];
    return DateOnly.daysInclusive(
      _rangeStart!,
      _rangeEnd ?? _rangeStart!,
      maxDays: _maxAssignDays,
    );
  }

  @override
  void initState() {
    super.initState();
    final today = _minAssignableDay;
    final requested = widget.initialDate != null
        ? _dateOnly(widget.initialDate!)
        : null;
    // 조회 달력에서 과거일을 고른 뒤 배정으로 들어오면 오늘로 보정
    final seedDay = (requested != null && !requested.isBefore(today))
        ? requested
        : today;
    _focusedDay = seedDay;
    if (requested != null && !requested.isBefore(today)) {
      _mode = _DatePickMode.individual;
      _selectedDates.add(seedDay);
    } else if (requested != null && requested.isBefore(today)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showPastAssignBlocked();
      });
    }
    final staff = MockStore.instance.activeStaffMembers(widget.room.id);
    final initial = widget.initialStaff;
    if (initial != null &&
        staff.any((s) => s.userId == initial.userId)) {
      _applyStaff(staff.firstWhere((s) => s.userId == initial.userId));
    } else if (staff.isNotEmpty) {
      // 첫 직원 계약 조건으로 prefill — 칩에서 바꾸면 다시 불러옴
      _applyStaff(staff.first);
    }
  }

  @override
  void dispose() {
    _wageController.dispose();
    super.dispose();
  }

  void _applyStaff(RoomMemberModel staff) {
    // 최신 계약값 반영 (설정 화면에서 바꾼 뒤 다시 선택해도 동기화)
    final live = MockStore.instance.getMembership(staff.roomId, staff.userId) ??
        staff;
    final switching =
        _selectedStaff != null && _selectedStaff!.userId != live.userId;
    final c = live.contract;
    _selectedStaff = live;
    _wageController.text = NumberFormat('#,###').format(c.hourlyWage);
    _breakTimeType = c.breakTimeType;
    _breakManuallySet = c.breakTimeType == BreakTimeType.fixed ||
        c.breakTimeType == BreakTimeType.none;
    _includeWeeklyHoliday = c.isWeekPayEnabled;
    _includeNightPay = c.isNightPayEnabled;
    _includeOvertimePay = c.isOvertimePayEnabled;
    if (c.breakTimeType == BreakTimeType.fixed) {
      _breakMinutes = c.fixedBreakMinutes;
    } else if (c.breakTimeType == BreakTimeType.none) {
      _breakMinutes = 0;
    }
    // 다른 직원으로 바꾸면 이전 날짜·기간·요일 선택은 이어지지 않음
    if (switching) {
      _selectedDates.clear();
      _rangeStart = null;
      _rangeEnd = null;
      _excludedInRange.clear();
      _weeklyWeekdays.clear();
      _calendarEpoch++;
    }
    _syncEstimatedPay();
  }

  int get _hourlyWage {
    final parsed = int.tryParse(_wageController.text.replaceAll(',', '').trim());
    if (parsed != null && parsed > 0) return parsed;
    return _selectedStaff?.contract.hourlyWage ??
        AppConstants.minimumHourlyWage;
  }

  DateTime _combine(DateTime day, TimeOfDay time) =>
      DateTime(day.year, day.month, day.day, time.hour, time.minute);

  /// 배정에 사용할 날짜 목록 (오름차순) — 개별/매주는 `_selectedDates` 단일 소스
  List<DateTime> get _effectiveDates {
    if (_mode == _DatePickMode.individual || _mode == _DatePickMode.weekly) {
      final list = _selectedDates.map(_dateOnly).toList()..sort();
      return list;
    }
    return _rangeDaysRaw.where((d) => !_isExcluded(d)).toList();
  }

  /// 현재 포커스 달의 1일~말일
  List<DateTime> _daysInFocusedMonth() {
    final y = _focusedDay.year;
    final m = _focusedDay.month;
    return DateOnly.daysInMonth(y, m);
  }

  bool _datesContain(DateTime day) {
    final d = _dateOnly(day);
    return _selectedDates.any((x) => isSameDay(x, d));
  }

  void _addDate(DateTime day) {
    final d = _dateOnly(day);
    _selectedDates.removeWhere((x) => isSameDay(x, d));
    _selectedDates.add(d);
  }

  void _removeDate(DateTime day) {
    final d = _dateOnly(day);
    _selectedDates.removeWhere((x) => isSameDay(x, d));
  }

  /// 포커스 월에서 해당 요일 날짜만 `_selectedDates`에 추가 (기존 선택 유지)
  void _addWeekdayInFocusedMonth(int weekday) {
    for (final d in _daysInFocusedMonth()) {
      if (d.weekday == weekday && _isAssignableDay(d)) _addDate(d);
    }
  }

  /// 해당 요일에 속하는 선택일을 `_selectedDates`에서 제거
  void _removeWeekdayFromSelected(int weekday) {
    _selectedDates.removeWhere((d) => d.weekday == weekday);
  }

  void _syncSuggestedBreakIfNeeded() {
    final base = _dateOnly(KstDateTime.now());
    final start = _combine(base, _start);
    final end = _combine(base, _end);
    final total = end.difference(start).inMinutes;
    if (total <= 0) return;

    // 없음 / 고정 → 계약값 유지 (사장이 배정 화면에서 직접 바꾸기 전)
    if (_breakTimeType == BreakTimeType.none && !_breakManuallySet) {
      _breakMinutes = 0;
      return;
    }
    if (_breakTimeType == BreakTimeType.fixed && !_breakManuallySet) {
      final fixed = _selectedStaff?.contract.fixedBreakMinutes ?? _breakMinutes;
      _breakMinutes = fixed.clamp(0, total);
      return;
    }
    // 자동 + 사장이 아직 수동 변경 안 함 → 법정 권장
    if (_breakManuallySet) return;
    _breakMinutes = PayrollCalculator.suggestedBreakMinutes(total);
  }

  PayEstimate? _computeEstimate() {
    if (_selectedStaff == null) return null;
    final base = _dateOnly(KstDateTime.now());
    final start = _combine(base, _start);
    final end = _combine(base, _end);
    if (!end.isAfter(start)) return null;
    return PayrollCalculator.estimate(
      startTime: start,
      endTime: end,
      hourlyWage: _hourlyWage,
      breakMinutes: _breakMinutes,
      includeWeeklyHoliday: _includeWeeklyHoliday,
      includeOvertimeNight: _includeOvertimeNight,
    );
  }

  void _syncEstimatedPay() {
    _syncSuggestedBreakIfNeeded();
  }

  String _breakOptionLabel(int minutes) {
    if (minutes <= 0) return '없음';
    return PayEstimate.formatDuration(minutes);
  }

  /// 메인 입력 칸에 표시할 현재 휴게 값
  String get _breakFieldLabel {
    if (_isBreakAuto) return '근무시간 기준 자동계산';
    return _breakOptionLabel(_breakMinutes);
  }

  Future<void> _pickBreakMinutes() async {
    if (_submitting) return; // 연타·중복 배정 요청 차단
    final selected = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final textTheme = Theme.of(ctx).textTheme;
        final options = <({int value, String label})>[
          for (final m in _breakOptions)
            (value: m, label: _breakOptionLabel(m)),
          (
            value: _breakAutoSentinel,
            label: '근무시간 기준 자동계산',
          ),
        ];
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 10),
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                  child: Text(
                    '휴게시간 선택',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(ctx).height * 0.65,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const ClampingScrollPhysics(),
                    itemCount: options.length,
                    separatorBuilder: (_, _) => const Divider(
                      height: 1,
                      indent: 20,
                      endIndent: 20,
                    ),
                    itemBuilder: (context, index) {
                      final opt = options[index];
                      final isSelected = opt.value == _breakAutoSentinel
                          ? _isBreakAuto
                          : !_isBreakAuto && _breakMinutes == opt.value;
                      return InkWell(
                        onTap: () => Navigator.pop(ctx, opt.value),
                        child: Container(
                          color: isSelected
                              ? AppColors.primary.withValues(alpha: 0.06)
                              : null,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  opt.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: textTheme.bodyLarge?.copyWith(
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? AppColors.primary
                                        : AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              if (isSelected)
                                const Icon(
                                  Icons.check,
                                  size: 22,
                                  color: AppColors.primary,
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (selected == null || !mounted) return;
    setState(() {
      if (selected == _breakAutoSentinel) {
        _breakTimeType = BreakTimeType.auto;
        _breakManuallySet = false;
      } else {
        _breakMinutes = selected;
        _breakManuallySet = true;
        _breakTimeType =
            selected == 0 ? BreakTimeType.none : BreakTimeType.fixed;
      }
      _syncEstimatedPay();
    });
  }

  void _setMode(_DatePickMode mode) {
    if (_mode == mode) return;
    setState(() {
      _mode = mode;
      _excludedInRange.clear();
      _selectedDates.clear();
      _rangeStart = null;
      _rangeEnd = null;
      _weeklyWeekdays.clear();
    });
  }

  /// 날짜·요일·기간 선택 중 하나라도 있으면 true
  bool get _hasDateSelection {
    if (_mode == _DatePickMode.range) return _rangeStart != null;
    return _selectedDates.isNotEmpty || _weeklyWeekdays.isNotEmpty;
  }

  void _onResetSelectedDates() {
    if (!_hasDateSelection || _submitting) return;
    setState(() {
      _selectedDates.clear();
      _weeklyWeekdays.clear();
      _rangeStart = null;
      _rangeEnd = null;
      _excludedInRange.clear();
      _calendarEpoch++;
    });
  }

  /// 반복 요일 칩 토글 — 현재 월 해당 요일을 `_selectedDates`에 가산/감산 (전체 초기화 없음)
  void _onDayOfWeekToggled(int weekday) {
    setState(() {
      if (_weeklyWeekdays.contains(weekday)) {
        _weeklyWeekdays.remove(weekday);
        _removeWeekdayFromSelected(weekday);
      } else {
        _weeklyWeekdays.add(weekday);
        _addWeekdayInFocusedMonth(weekday);
      }
    });
  }

  String _weeklyWeekdaySummary() {
    if (_weeklyWeekdays.isEmpty) {
      return _selectedDates.isEmpty
          ? '요일을 선택하세요'
          : '달력에서 고른 날짜 포함';
    }
    final ordered = _weekdayLabels.keys
        .where(_weeklyWeekdays.contains)
        .map((d) => _weekdayLabels[d]!)
        .join('/');
    return '매주 $ordered';
  }

  /// 개별·매주 공통 — `_selectedDates` 토글 (기존 선택 유지)
  void _onDayToggled(DateTime selectedDay, DateTime focusedDay) {
    final day = _dateOnly(selectedDay);
    if (!_isAssignableDay(day)) {
      _showPastAssignBlocked();
      return;
    }
    setState(() {
      if (_focusedDay.year != focusedDay.year ||
          _focusedDay.month != focusedDay.month) {
        _focusedDay = focusedDay;
      }
      if (_datesContain(day)) {
        _removeDate(day);
      } else {
        _addDate(day);
      }
    });
  }

  /// 비행기/숙소 예매형 Date Range Picker (기간 모드)
  /// 1) 첫 탭 → 시작일
  /// 2) 시작일 이후 탭 → 종료일 (범위 확정)
  /// 3) 범위 확정 후 중간·이후 탭 → 시작 유지, 종료만 갱신
  /// 4) 시작일보다 이전 탭 → 새 시작일
  void _onBookingRangeDaySelected(DateTime selectedDay, DateTime focusedDay) {
    final day = _dateOnly(selectedDay);
    if (!_isAssignableDay(day)) {
      _showPastAssignBlocked();
      return;
    }
    setState(() {
      if (_focusedDay.year != focusedDay.year ||
          _focusedDay.month != focusedDay.month) {
        _focusedDay = focusedDay;
      }
      _excludedInRange.clear();

      if (_rangeStart == null) {
        _rangeStart = day;
        _rangeEnd = null;
      } else if (_rangeEnd != null) {
        if (day.isBefore(_rangeStart!)) {
          _rangeStart = day;
          _rangeEnd = null;
        } else if (isSameDay(day, _rangeStart!)) {
          _rangeEnd = null;
        } else {
          _rangeEnd = day;
        }
      } else if (isSameDay(day, _rangeStart!)) {
        // 시작일만 있는 상태에서 같은 날 재탭 → 선택 해제
        _rangeStart = null;
        _rangeEnd = null;
      } else if (day.isBefore(_rangeStart!)) {
        _rangeStart = day;
        _rangeEnd = null;
      } else {
        _rangeEnd = day;
      }
    });
  }

  Future<void> _pickTime({required bool isStart}) async {
    final initial = isStart ? _start : _end;
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      initialEntryMode: TimePickerEntryMode.inputOnly,
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isStart) {
        _start = picked;
      } else {
        _end = picked;
      }
      _syncEstimatedPay();
    });
  }

  String _rangePeriodLabel(DateTime from, DateTime to, {required int totalDays}) {
    final fmt = DateFormat('M월 d일', 'ko_KR');
    return '선택된 기간: ${fmt.format(from)} ~ ${fmt.format(to)} (총 $totalDays일)';
  }

  String _summaryLabel() {
    final days = _effectiveDates;
    final dayFmt = DateFormat('M/d', 'ko_KR');

    if (_mode == _DatePickMode.weekly) {
      if (days.isEmpty) {
        return '요일을 고르거나 달력에서 날짜를 선택하세요';
      }
      return '${_weeklyWeekdaySummary()} · 총 ${days.length}개 날짜가 선택되었습니다.';
    }

    if (_mode == _DatePickMode.range) {
      if (_rangeStart != null && _rangeEnd == null) {
        final startLabel = DateFormat('M월 d일', 'ko_KR').format(_rangeStart!);
        return '$startLabel부터 · 종료일을 선택하세요';
      }
      if (_rangeComplete) {
        final raw = _rangeDaysRaw;
        return _rangePeriodLabel(
          raw.first,
          raw.last,
          totalDays: raw.length,
        );
      }
      return '시작일을 선택하세요';
    }

    if (days.isEmpty) return '날짜를 선택하세요';
    if (days.length == 1) return dayFmt.format(days.first);
    if (days.length <= 5) {
      return days.map(dayFmt.format).join(', ');
    }
    return '${days.take(3).map(dayFmt.format).join(', ')} 외 '
        '${days.length - 3}일 · 총 ${days.length}일';
  }

  Future<void> _submit() async {
    final staff = _selectedStaff;
    if (staff == null) {
      showAppSnackBar(
        context,
        message: '배정할 직원을 선택하세요.',
        aboveStickyActions: true,
      );
      return;
    }

    final days = _effectiveDates;
    if (days.isEmpty) {
      showAppSnackBar(
        context,
        message: '근무 날짜를 선택하세요.',
        aboveStickyActions: true,
      );
      return;
    }

    if (days.any((d) => !_isAssignableDay(d))) {
      _showPastAssignBlocked();
      return;
    }

    if (days.length > _maxAssignDays) {
      showAppSnackBar(
        context,
        message: '한 번에 $_maxAssignDays일까지 배정할 수 있습니다.',
        aboveStickyActions: true,
      );
      return;
    }

    final sampleStart = _combine(days.first, _start);
    final sampleEnd = _combine(days.first, _end);
    if (!sampleEnd.isAfter(sampleStart)) {
      showAppSnackBar(
        context,
        message: '퇴근 시간은 출근 시간보다 늦어야 합니다.',
        aboveStickyActions: true,
      );
      return;
    }

    final estimate = _computeEstimate();
    if (estimate == null || estimate.total < 0) {
      showAppSnackBar(
        context,
        message: '예상 급여를 확인할 수 없습니다.',
        aboveStickyActions: true,
      );
      return;
    }

    if (_submitting || _assignCompleted || !_submitGuard.tryStart()) return;
    setState(() => _submitting = true);
    try {
      MockStore.instance.createSchedulesForDates(
        roomId: widget.room.id,
        workerId: staff.userId,
        dates: days,
        startHour: _start.hour,
        startMinute: _start.minute,
        endHour: _end.hour,
        endMinute: _end.minute,
        estimatedPay: estimate.total,
        hourlyWage: _hourlyWage,
        includeWeeklyHoliday: _includeWeeklyHoliday,
        includeOvertimeNight: _includeOvertimeNight,
        breakMinutes: _breakMinutes,
        note: '근무 배정',
        asPeriod: _mode == _DatePickMode.range,
      );
      if (!mounted) return;
      showAppSnackBar(
        context,
        message: '완료되었습니다',
        aboveStickyActions: true,
      );
      setState(() {
        _submitting = false;
        _assignCompleted = true;
      });
      // 배정 후에도 현재 화면·선택 직원/날짜 유지 (강제 pop 없음)
    } catch (e) {
      if (!mounted) return;
      final String message;
      if (e is PastDateAssignmentException) {
        message = e.message;
      } else if (e is DuplicateScheduleException) {
        message = e.message;
      } else {
        message = '근무표 작성 실패: $e';
      }
      showAppSnackBar(
        context,
        message: message,
        aboveStickyActions: true,
      );
      setState(() => _submitting = false);
    } finally {
      _submitGuard.end();
    }
  }

  static const double _dayCircleSize = 34;
  static const Color _rangeBandColor = Color(0xFFDEE2E6);

  /// TableCalendar 기본 AnimatedContainer 우회 — 즉시 표시
  Widget _plainDayCell(
    BuildContext context,
    DateTime day, {
    bool isHoliday = false,
  }) {
    final isRed = isHoliday || KoreanHolidays.isRedDay(day);
    return Center(
      child: Text(
        '${day.day}',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: isRed ? AppColors.holiday : AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }

  Widget _disabledDayCell(BuildContext context, DateTime day) {
    return Center(
      child: Text(
        '${day.day}',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.textSecondary.withValues(alpha: 0.4),
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }

  Widget _selectedDayCell(BuildContext context, DateTime day) {
    return Center(
      child: Container(
        width: _dayCircleSize,
        height: _dayCircleSize,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
        ),
        child: Text(
          '${day.day}',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
        ),
      ),
    );
  }

  /// 기간 밴드 — 원 높이와 동일, 시작/끝은 반쪽만 채워 원과 매끄럽게 연결
  Widget? _rangeBandHighlight(DateTime day, bool isWithinRange) {
    if (_mode != _DatePickMode.range || !isWithinRange) return null;
    final isStart =
        _rangeStart != null && isSameDay(day, _rangeStart!);
    final isEnd = _rangeEnd != null && isSameDay(day, _rangeEnd!);
    return LayoutBuilder(
      builder: (context, constraints) {
        return Center(
          child: Container(
            margin: EdgeInsetsDirectional.only(
              start: isStart ? constraints.maxWidth * 0.5 : 0,
              end: isEnd ? constraints.maxWidth * 0.5 : 0,
            ),
            height: _dayCircleSize,
            color: _rangeBandColor,
          ),
        );
      },
    );
  }

  Widget _fieldTap({
    required String value,
    required VoidCallback onTap,
  }) {
    return AppBorderedField(
      height: 52,
      child: InkWell(
        onTap: _submitting ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF191F28),
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool _isSelectedDay(DateTime day) => _datesContain(day);

  @override
  Widget build(BuildContext context) {
    final staff = MockStore.instance.activeStaffMembers(widget.room.id);
    final textTheme = Theme.of(context).textTheme;
    final dayCount = _effectiveDates.length;
    // 날짜가 선택된 경우에만 예상 급여·산정 내역을 표시
    final liveEstimate = dayCount > 0 ? _computeEstimate() : null;
    final dailyPay = liveEstimate?.total;
    final periodPay =
        (dailyPay != null && dayCount > 0) ? dailyPay * dayCount : null;
    final lockedStaff = widget.initialStaff != null;
    final staffName = _selectedStaff?.displayName ??
        widget.initialStaff?.displayName ??
        '';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(lockedStaff ? '근무배정표' : '근무표 작성'),
      ),
      body: ColoredBox(
        color: Colors.white,
        child: ScrollablePageBody(
          top: false,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (lockedStaff) ...[
                Text(
                  staffName.isEmpty
                      ? '근무 일정을 배정합니다'
                      : '$staffName님 근무배정표',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '등록 즉시 캘린더·내 근무표에 반영됩니다.',
                  style: textTheme.bodyMedium,
                ),
              ] else ...[
                Text(
                  '직원에게 근무 일정을 배정합니다',
                  style: textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  '직원을 고르면 기본 시급·휴게·수당이 자동으로 채워집니다. '
                  '기본값은 직원목록에서 바꿀 수 있어요.',
                  style: textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),
                Text('직원 선택', style: textTheme.titleSmall),
                const SizedBox(height: 10),
                if (staff.isEmpty)
                  AppCard(
                    child: Text(
                      '배정할 직원이 없습니다. 직원목록에서 먼저 초대해 주세요.',
                      style: textTheme.bodyMedium,
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
                          selected: _selectedStaff?.userId == m.userId,
                          onTap: _submitting
                              ? null
                              : () => setState(() => _applyStaff(m)),
                        ),
                    ],
                  ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text('날짜 선택', style: textTheme.titleSmall),
                  ),
                  if (_hasDateSelection)
                    TextButton(
                      onPressed: _submitting ? null : _onResetSelectedDates,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textCaption,
                        disabledForegroundColor: AppColors.border,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: const Size(0, 32),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '초기화',
                            style: textTheme.labelMedium?.copyWith(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textCaption,
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Icon(
                            Icons.refresh_rounded,
                            size: 16,
                            color: AppColors.textCaption,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final mode in _DatePickMode.values) ...[
                    if (mode != _DatePickMode.values.first)
                      const SizedBox(width: 8),
                    Expanded(
                      child: AppSelectChip(
                        label: switch (mode) {
                          _DatePickMode.individual => '개별',
                          _DatePickMode.range => '기간',
                          _DatePickMode.weekly => '매주',
                        },
                        selected: _mode == mode,
                        expand: true,
                        onTap: _submitting ? null : () => _setMode(mode),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _mode == _DatePickMode.individual
                    ? '원하는 날짜를 하나씩 눌러 선택·해제하세요. (예: 10/3, 10/7)'
                    : _mode == _DatePickMode.weekly
                        ? '요일을 고르면 이 달의 해당 날짜가 추가됩니다. '
                            '달력에서 날짜를 눌러 개별 추가·해제할 수 있어요.'
                        : '시작일을 누른 뒤 종료일을 누르세요. '
                            '기간이 잡힌 뒤 중간 날짜를 누르면 시작일은 유지되고 종료일만 바뀝니다.',
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              if (_mode == _DatePickMode.weekly) ...[
                const SizedBox(height: 10),
                Text('반복 요일', style: textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final entry in _weekdayLabels.entries)
                      AppSelectChip(
                        label: entry.value,
                        selected: _weeklyWeekdays.contains(entry.key),
                        onTap: _submitting
                            ? null
                            : () => _onDayOfWeekToggled(entry.key),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _weeklyWeekdaySummary(),
                  style: textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: _selectedDates.isEmpty
                        ? AppColors.warning
                        : AppColors.textPrimary,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              AppCard(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
                child: TableCalendar(
                  key: ValueKey<String>(
                    'assign-cal-${_selectedStaff?.userId ?? 'none'}-$_calendarEpoch',
                  ),
                  firstDay: DateTime.utc(2024, 1, 1),
                  lastDay: DateTime.utc(2030, 12, 31),
                  focusedDay: _focusedDay,
                  locale: 'ko_KR',
                  startingDayOfWeek: StartingDayOfWeek.sunday,
                  calendarFormat: CalendarFormat.month,
                  availableCalendarFormats: const {
                    CalendarFormat.month: 'Month',
                  },
                  // 신규 배정만 오늘 이전 비활성 (조회용 달력은 과거 선택 유지)
                  enabledDayPredicate: _isAssignableDay,
                  pageAnimationEnabled: SnappyCalendar.pageAnimationEnabled,
                  pageAnimationDuration: SnappyCalendar.pageAnimationDuration,
                  formatAnimationDuration:
                      SnappyCalendar.formatAnimationDuration,
                  headerStyle: HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                    titleTextStyle: textTheme.bodyLarge!.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  selectedDayPredicate: _mode == _DatePickMode.individual ||
                          _mode == _DatePickMode.weekly
                      ? _isSelectedDay
                      : _rangeStart != null && _rangeEnd == null
                          ? (day) => isSameDay(day, _rangeStart!)
                          : null,
                  rangeStartDay: _mode == _DatePickMode.range && _rangeComplete
                      ? _rangeStart
                      : null,
                  rangeEndDay: _mode == _DatePickMode.range && _rangeComplete
                      ? _rangeEnd
                      : null,
                  rangeSelectionMode: RangeSelectionMode.toggledOff,
                  onDaySelected: _submitting
                      ? null
                      : _mode == _DatePickMode.individual ||
                              _mode == _DatePickMode.weekly
                          ? _onDayToggled
                          : _mode == _DatePickMode.range
                              ? _onBookingRangeDaySelected
                              : null,
                  onPageChanged: (focused) {
                    setState(() {
                      _focusedDay = focused;
                      // 켜 둔 요일 칩 → 새 달의 해당 요일도 선택에 가산
                      if (_mode == _DatePickMode.weekly) {
                        for (final weekday in _weeklyWeekdays) {
                          _addWeekdayInFocusedMonth(weekday);
                        }
                      }
                    });
                  },
                  holidayPredicate: KoreanHolidays.isHoliday,
                  daysOfWeekStyle: DaysOfWeekStyle(
                    weekdayStyle: textTheme.labelSmall!.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                    weekendStyle: textTheme.labelSmall!.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.holiday,
                    ),
                  ),
                  calendarBuilders: CalendarBuilders(
                    // AnimatedContainer 기본 셀 대신 즉시 전환
                    defaultBuilder: (context, day, focused) =>
                        _plainDayCell(context, day),
                    holidayBuilder: (context, day, focused) =>
                        _plainDayCell(context, day, isHoliday: true),
                    disabledBuilder: (context, day, focused) =>
                        _disabledDayCell(context, day),
                    // 중간 일은 텍스트만 — 밴드는 rangeHighlightBuilder
                    withinRangeBuilder: (context, day, focused) =>
                        _plainDayCell(context, day),
                    rangeStartBuilder: (context, day, focused) =>
                        _selectedDayCell(context, day),
                    rangeEndBuilder: (context, day, focused) =>
                        _selectedDayCell(context, day),
                    rangeHighlightBuilder: (context, day, isWithinRange) =>
                        _rangeBandHighlight(day, isWithinRange),
                    // 선택일은 항상 원형으로 강제 (기본 사각형 오버레이 방지)
                    selectedBuilder: (context, day, focused) =>
                        _selectedDayCell(context, day),
                    todayBuilder: (context, day, focused) {
                      final inRangeEndpoints = _mode == _DatePickMode.range &&
                          _rangeComplete &&
                          ((_rangeStart != null &&
                                  isSameDay(day, _rangeStart!)) ||
                              (_rangeEnd != null &&
                                  isSameDay(day, _rangeEnd!)));
                      if (inRangeEndpoints) return null;
                      if (((_mode == _DatePickMode.weekly ||
                                  _mode == _DatePickMode.individual) &&
                              _isSelectedDay(day)) ||
                          (_mode == _DatePickMode.range &&
                              _rangeStart != null &&
                              _rangeEnd == null &&
                              isSameDay(day, _rangeStart!))) {
                        return null;
                      }
                      final isRed = KoreanHolidays.isRedDay(day);
                      return Center(
                        child: Text(
                          '${day.day}',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: isRed
                                ? AppColors.holiday
                                : AppColors.textPrimary,
                            fontWeight: FontWeight.w800,
                            decoration: TextDecoration.underline,
                            decorationColor: AppColors.primary,
                            decorationThickness: 1.5,
                          ),
                        ),
                      );
                    },
                  ),
                  calendarStyle: CalendarStyle(
                    outsideDaysVisible: false,
                    holidayDecoration: const BoxDecoration(),
                    selectedDecoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    selectedTextStyle: textTheme.labelSmall!.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                    // 밴드는 rangeHighlightBuilder 에서 원 높이에 맞춰 그림
                    rangeHighlightColor: Colors.transparent,
                    rangeStartDecoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    rangeEndDecoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    rangeStartTextStyle: textTheme.labelSmall!.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                    rangeEndTextStyle: textTheme.labelSmall!.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                    withinRangeTextStyle: textTheme.labelSmall!.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                    todayDecoration: const BoxDecoration(
                      color: Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    defaultTextStyle: textTheme.labelSmall!.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                    weekendTextStyle: textTheme.labelSmall!.copyWith(
                      color: AppColors.holiday,
                      fontWeight: FontWeight.w700,
                    ),
                    holidayTextStyle: textTheme.labelSmall!.copyWith(
                      color: AppColors.holiday,
                      fontWeight: FontWeight.w700,
                    ),
                    todayTextStyle: textTheme.labelSmall!.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                      decoration: TextDecoration.underline,
                      decorationColor: AppColors.primary,
                      decorationThickness: 1.5,
                    ),
                    disabledTextStyle: textTheme.labelSmall!.copyWith(
                      color: AppColors.textSecondary.withValues(alpha: 0.45),
                      fontWeight: FontWeight.w600,
                    ),
                    disabledDecoration: const BoxDecoration(),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _summaryLabel(),
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: dayCount == 0
                      ? AppColors.warning
                      : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              Text('출근 · 퇴근', style: textTheme.titleSmall),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _fieldTap(
                      value: _start.format(context),
                      onTap: () => _pickTime(isStart: true),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('~'),
                  ),
                  Expanded(
                    child: _fieldTap(
                      value: _end.format(context),
                      onTap: () => _pickTime(isStart: false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text('시급 (원)', style: textTheme.titleSmall),
                  const SizedBox(width: 6),
                  Text(
                    '${AppConstants.minimumWageYear}년 최저시급 '
                    '${NumberFormat('#,###').format(AppConstants.minimumHourlyWage)}원',
                    style: textTheme.labelSmall?.copyWith(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              AppBorderedField(
                height: 52,
                child: Center(
                  child: TextField(
                    controller: _wageController,
                    enabled: !_submitting,
                    keyboardType: TextInputType.number,
                    autocorrect: false,
                    enableSuggestions: false,
                    spellCheckConfiguration:
                        const SpellCheckConfiguration.disabled(),
                    smartDashesType: SmartDashesType.disabled,
                    smartQuotesType: SmartQuotesType.disabled,
                    inputFormatters: const [
                      _ThousandsSeparatorInputFormatter(),
                    ],
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF191F28),
                      decoration: TextDecoration.none,
                    ),
                    decoration: const InputDecoration(
                      hintText: '직원 기본 시급',
                      hintStyle: TextStyle(
                        color: Color(0xFF8B95A1),
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                      filled: false,
                      isDense: true,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                    onChanged: (_) {
                      setState(_syncEstimatedPay);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '직원 기본 설정의 시급·휴게·수당을 자동으로 불러옵니다. '
                '이번 배정에만 수정되며, 직원 프로필 기본값은 유지됩니다.',
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              Text('휴게시간', style: textTheme.titleSmall),
              const SizedBox(height: 8),
              AppBorderedField(
                height: 52,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _submitting ? null : _pickBreakMinutes,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _breakFieldLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: _submitting
                                    ? AppColors.textSecondary
                                    : const Color(0xFF191F28),
                              ),
                            ),
                          ),
                          Icon(
                            Icons.keyboard_arrow_down,
                            size: 22,
                            color: _submitting
                                ? AppColors.textSecondary
                                : AppColors.textCaption,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _isBreakAuto
                    ? '근무 시간에 맞춰 법정 권장 휴게가 자동 적용됩니다. (4h↑ 30분 · 8h↑ 60분)'
                    : _breakTimeType == BreakTimeType.none && !_breakManuallySet
                        ? '직원 기본 설정: 휴게 없음(0분). 이번 배정에 한해 변경할 수 있습니다.'
                        : '무급 휴게로 차감됩니다. 이번 배정에 한해 변경할 수 있습니다.',
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              Text('수당 옵션', style: textTheme.titleSmall),
              const SizedBox(height: 8),
              AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Column(
                  children: [
                    AllowanceOptionTile(
                      title: '주휴수당 포함',
                      subtitle:
                          '주 ${PayrollCalculator.weeklyHolidayThresholdHours.toStringAsFixed(0)}시간 이상 근무 시 '
                          '주휴수당이 발생할 수 있습니다. '
                          '(근무시간÷40)×8×시급으로 일할 반영',
                      value: _includeWeeklyHoliday,
                      onChanged: _submitting
                          ? null
                          : (v) {
                              setState(() {
                                _includeWeeklyHoliday = v;
                                _syncEstimatedPay();
                              });
                            },
                    ),
                    const Divider(height: 1),
                    AllowanceOptionTile(
                      title: '야간수당 포함',
                      subtitle: '22시~06시 구간에 시급의 0.5배를 가산합니다.',
                      value: _includeNightPay,
                      onChanged: _submitting
                          ? null
                          : (v) {
                              setState(() {
                                _includeNightPay = v;
                                _syncEstimatedPay();
                              });
                            },
                    ),
                    const Divider(height: 1),
                    AllowanceOptionTile(
                      title: '연장수당 포함',
                      subtitle: '1일 8시간 초과분에 시급의 0.5배를 가산합니다.',
                      value: _includeOvertimePay,
                      onChanged: _submitting
                          ? null
                          : (v) {
                              setState(() {
                                _includeOvertimePay = v;
                                _syncEstimatedPay();
                              });
                            },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                dayCount > 1
                    ? '예상 급여 (선택 $dayCount일)'
                    : dayCount == 1
                        ? '예상 급여 (원 / 하루)'
                        : '예상 급여',
                style: textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              AppBorderedField(
                height: 52,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      periodPay != null
                          ? NumberFormat('#,###').format(periodPay)
                          : '날짜를 선택하면 예상 급여와 산정 내역이 표시됩니다.',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: periodPay == null ? 13 : 15,
                        fontWeight: FontWeight.w600,
                        color: periodPay == null
                            ? const Color(0xFF8B95A1)
                            : const Color(0xFF191F28),
                      ),
                    ),
                  ),
                ),
              ),
              if (dayCount > 1 && dailyPay != null) ...[
                const SizedBox(height: 6),
                Text(
                  '1일 ${NumberFormat('#,###').format(dailyPay)}원 × $dayCount일',
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              if (liveEstimate != null && dayCount > 0) ...[
                const SizedBox(height: 10),
                AppCard(
                  child: PayBreakdownView(
                    estimateOverride: liveEstimate,
                    showTitleTotal: false,
                    dayCount: dayCount,
                    cardTitle: dayCount > 1
                        ? '산정 내역 (선택 $dayCount일)'
                        : '산정 내역',
                  ),
                ),
                const PayDisclaimerCaption(
                  padding: EdgeInsets.only(top: 10, left: 2, right: 2),
                ),
              ],
              if (dayCount > 1) ...[
                const SizedBox(height: 6),
                Text(
                  '선택 $dayCount일에 동일한 출퇴근·수당·일당이 각각 적용됩니다.',
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: 28),
              StickyActionButton(
                label: dayCount > 1
                    ? '근무 $dayCount일 배정하기'
                    : '근무 배정하기',
                variant: StickyActionVariant.filled,
                onPressed: (_submitting || _assignCompleted) ? null : _submit,
                enabled: !_submitting &&
                    !_assignCompleted &&
                    staff.isNotEmpty &&
                    dayCount > 0,
                isLoading: _submitting,
                isCompleted: _assignCompleted,
                completedLabel: '완료됨',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 시급 입력: 10320 → 10,320
class _ThousandsSeparatorInputFormatter extends TextInputFormatter {
  const _ThousandsSeparatorInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return const TextEditingValue(text: '');
    }
    final formatted = NumberFormat('#,###').format(int.parse(digits));
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
