import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:intl/intl.dart';

import '../core/constants/firestore_paths.dart';
import 'enums/schedule_status.dart';
import 'pay_estimate.dart';
import 'pending_change.dart';

/// `schedules/{scheduleId}` 문서 — 날짜별 근무 일정
///
/// 확정 후 시간 변경은 즉시 반영되지 않고
/// [status] / [pendingChange] 상호 승인 흐름을 거칩니다.
class ScheduleModel extends Equatable {
  const ScheduleModel({
    required this.id,
    required this.roomId,
    required this.workerId,
    required this.assignedBy,
    required this.date,
    required this.startTime,
    required this.endTime,
    this.isConfirmed = false,
    this.confirmedAt,
    this.status = ScheduleStatus.normal,
    this.pendingChange,
    this.reason,
    this.estimatedPay,
    this.includeWeeklyHoliday = false,
    this.includeOvertimeNight = false,
    this.breakMinutes = 0,
    this.basePay,
    this.weeklyHolidayPay,
    this.overtimeNightPay,
    this.payEstimate,
    this.note,
    this.assignmentBatchId,
    this.isPeriodBatch = false,
    this.isAbsent = false,
    this.absentMarkedAt,
    this.absentMarkedBy,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String roomId;

  /// 근무 대상 알바생 userId
  final String workerId;

  /// 일정 작성자 (사장/매니저)
  final String assignedBy;

  /// 근무일 `yyyy-MM-dd`
  final String date;

  final DateTime startTime;
  final DateTime endTime;

  /// 일괄 배정 묶음 ID (기간·복수 선택 시 동일)
  final String? assignmentBatchId;

  /// 기간 선택으로 배정된 묶음이면 true → UI에서 `시작일 ~ 종료일` 표기
  final bool isPeriodBatch;

  /// 사장이 결근 처리한 근무
  final bool isAbsent;
  final DateTime? absentMarkedAt;
  final String? absentMarkedBy;

  /// 알바생 [확인했습니다] 여부 — false: 확인 대기(Pending), true: 확인 완료(Confirmed)
  final bool isConfirmed;
  final DateTime? confirmedAt;

  /// UI 뱃지용 확인 상태 라벨
  String get confirmStatusLabel => isConfirmed ? '확인 완료' : '확인 대기';

  /// 결근 우선 표시용 상태 라벨
  String get attendanceStatusLabel => isAbsent ? '결근' : confirmStatusLabel;

  /// `normal` | `change_requested_by_owner` | `change_requested_by_staff`
  final ScheduleStatus status;

  /// 승인 대기 중인 변경 내용 (`pending_change`)
  final PendingChange? pendingChange;

  /// 최근 승인된(또는 요청 중인) 수정 사유
  final String? reason;

  /// 예상 급여 합계(원) — 기본급 + 수당
  final int? estimatedPay;

  /// 주휴수당 포함 여부
  final bool includeWeeklyHoliday;

  /// 연장·야간 가산 적용 여부
  final bool includeOvertimeNight;

  /// 무급 휴게 차감(분)
  final int breakMinutes;

  final int? basePay;
  final int? weeklyHolidayPay;
  final int? overtimeNightPay;

  /// 상세 산정 스냅샷 (선택)
  final PayEstimate? payEstimate;

  final String? note;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Duration get plannedDuration => endTime.difference(startTime);

  bool get hasPendingChange =>
      status.hasPendingChange && pendingChange != null;

  /// 변경 요청 대기 중 여부 (`changeRequestStatus: PENDING`)
  bool get isChangeRequested =>
      pendingChange != null && pendingChange!.isPending;

  /// PENDING / ACCEPTED / REJECTED
  String? get changeRequestStatus =>
      pendingChange?.status.firestoreValue;

  bool get hasAllowanceOptions =>
      includeWeeklyHoliday || includeOvertimeNight;

  factory ScheduleModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return ScheduleModel.fromMap(data, id: doc.id);
  }

  factory ScheduleModel.fromMap(Map<String, dynamic> map, {String? id}) {
    final start = _requireDateTime(map['startTime']);
    final end = _requireDateTime(map['endTime']);
    final dateStr =
        map['date'] as String? ?? DateFormat('yyyy-MM-dd').format(start);

    final pendingRaw = map['pending_change'] ?? map['pendingChange'];
    PendingChange? pending;
    if (pendingRaw is Map<String, dynamic>) {
      pending = PendingChange.fromMap(pendingRaw);
    }

    PayEstimate? estimate;
    final estimateRaw = map['payEstimate'];
    if (estimateRaw is Map<String, dynamic>) {
      estimate = PayEstimate.fromMap(estimateRaw);
    }

    return ScheduleModel(
      id: id ?? map['id'] as String? ?? '',
      roomId: map['roomId'] as String? ?? '',
      workerId: map['workerId'] as String? ?? '',
      assignedBy: map['assignedBy'] as String? ?? '',
      date: dateStr,
      startTime: start,
      endTime: end,
      isConfirmed: map['isConfirmed'] as bool? ?? false,
      confirmedAt: _toDateTime(map['confirmedAt']),
      status: ScheduleStatus.fromFirestore(map['status'] as String?),
      pendingChange: pending,
      reason: map['reason'] as String?,
      estimatedPay: map['estimatedPay'] as int?,
      includeWeeklyHoliday: map['includeWeeklyHoliday'] as bool? ?? false,
      includeOvertimeNight: map['includeOvertimeNight'] as bool? ?? false,
      breakMinutes: map['breakMinutes'] as int? ?? 0,
      basePay: map['basePay'] as int?,
      weeklyHolidayPay: map['weeklyHolidayPay'] as int?,
      overtimeNightPay: map['overtimeNightPay'] as int?,
      payEstimate: estimate,
      note: map['note'] as String?,
      assignmentBatchId: map['assignmentBatchId'] as String?,
      isPeriodBatch: map['isPeriodBatch'] as bool? ?? false,
      isAbsent: map['isAbsent'] as bool? ?? false,
      absentMarkedAt: _toDateTime(map['absentMarkedAt']),
      absentMarkedBy: map['absentMarkedBy'] as String?,
      createdAt: _toDateTime(map['createdAt']),
      updatedAt: _toDateTime(map['updatedAt']),
    );
  }

  Map<String, dynamic> toFirestore({bool forCreate = false}) {
    return {
      'roomId': roomId,
      'workerId': workerId,
      'assignedBy': assignedBy,
      'date': date,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'isConfirmed': isConfirmed,
      if (confirmedAt != null) 'confirmedAt': Timestamp.fromDate(confirmedAt!),
      'status': status.firestoreValue,
      if (pendingChange != null)
        'pending_change': pendingChange!.toMap(forCreate: forCreate)
      else
        'pending_change': null,
      if (reason != null) 'reason': reason,
      if (estimatedPay != null) 'estimatedPay': estimatedPay,
      'includeWeeklyHoliday': includeWeeklyHoliday,
      'includeOvertimeNight': includeOvertimeNight,
      'breakMinutes': breakMinutes,
      if (basePay != null) 'basePay': basePay,
      if (weeklyHolidayPay != null) 'weeklyHolidayPay': weeklyHolidayPay,
      if (overtimeNightPay != null) 'overtimeNightPay': overtimeNightPay,
      if (payEstimate != null) 'payEstimate': payEstimate!.toMap(),
      if (note != null) 'note': note,
      if (assignmentBatchId != null) 'assignmentBatchId': assignmentBatchId,
      'isPeriodBatch': isPeriodBatch,
      'isAbsent': isAbsent,
      if (absentMarkedAt != null)
        'absentMarkedAt': Timestamp.fromDate(absentMarkedAt!),
      if (absentMarkedBy != null) 'absentMarkedBy': absentMarkedBy,
      'updatedAt': FieldValue.serverTimestamp(),
      if (forCreate) 'createdAt': FieldValue.serverTimestamp(),
    };
  }

  /// 알바생 확인 처리용 부분 업데이트 맵
  Map<String, dynamic> toConfirmUpdate() {
    return {
      'isConfirmed': true,
      'confirmedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  ScheduleModel copyWith({
    String? id,
    String? roomId,
    String? workerId,
    String? assignedBy,
    String? date,
    DateTime? startTime,
    DateTime? endTime,
    bool? isConfirmed,
    DateTime? confirmedAt,
    ScheduleStatus? status,
    PendingChange? pendingChange,
    bool clearPendingChange = false,
    String? reason,
    int? estimatedPay,
    bool? includeWeeklyHoliday,
    bool? includeOvertimeNight,
    int? breakMinutes,
    int? basePay,
    int? weeklyHolidayPay,
    int? overtimeNightPay,
    PayEstimate? payEstimate,
    String? note,
    String? assignmentBatchId,
    bool? isPeriodBatch,
    bool clearAssignmentBatch = false,
    bool? isAbsent,
    DateTime? absentMarkedAt,
    String? absentMarkedBy,
    bool clearAbsent = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ScheduleModel(
      id: id ?? this.id,
      roomId: roomId ?? this.roomId,
      workerId: workerId ?? this.workerId,
      assignedBy: assignedBy ?? this.assignedBy,
      date: date ?? this.date,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      isConfirmed: isConfirmed ?? this.isConfirmed,
      confirmedAt: confirmedAt ?? this.confirmedAt,
      status: status ?? this.status,
      pendingChange:
          clearPendingChange ? null : (pendingChange ?? this.pendingChange),
      reason: reason ?? this.reason,
      estimatedPay: estimatedPay ?? this.estimatedPay,
      includeWeeklyHoliday: includeWeeklyHoliday ?? this.includeWeeklyHoliday,
      includeOvertimeNight: includeOvertimeNight ?? this.includeOvertimeNight,
      breakMinutes: breakMinutes ?? this.breakMinutes,
      basePay: basePay ?? this.basePay,
      weeklyHolidayPay: weeklyHolidayPay ?? this.weeklyHolidayPay,
      overtimeNightPay: overtimeNightPay ?? this.overtimeNightPay,
      payEstimate: payEstimate ?? this.payEstimate,
      note: note ?? this.note,
      assignmentBatchId: clearAssignmentBatch
          ? null
          : (assignmentBatchId ?? this.assignmentBatchId),
      isPeriodBatch: clearAssignmentBatch
          ? false
          : (isPeriodBatch ?? this.isPeriodBatch),
      isAbsent: clearAbsent ? false : (isAbsent ?? this.isAbsent),
      absentMarkedAt:
          clearAbsent ? null : (absentMarkedAt ?? this.absentMarkedAt),
      absentMarkedBy:
          clearAbsent ? null : (absentMarkedBy ?? this.absentMarkedBy),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  String get docPath => FirestorePaths.schedule(id);

  static DateTime? _toDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  static DateTime _requireDateTime(dynamic value) {
    final parsed = _toDateTime(value);
    if (parsed == null) {
      throw ArgumentError('Invalid Timestamp/DateTime: $value');
    }
    return parsed;
  }

  @override
  List<Object?> get props => [
        id,
        roomId,
        workerId,
        assignedBy,
        date,
        startTime,
        endTime,
        isConfirmed,
        confirmedAt,
        status,
        pendingChange,
        reason,
        estimatedPay,
        includeWeeklyHoliday,
        includeOvertimeNight,
        breakMinutes,
        basePay,
        weeklyHolidayPay,
        overtimeNightPay,
        payEstimate,
        note,
        assignmentBatchId,
        isPeriodBatch,
        isAbsent,
        absentMarkedAt,
        absentMarkedBy,
        createdAt,
        updatedAt,
      ];
}
