import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

import 'enums/change_request_status.dart';
import 'enums/schedule_change_type.dart';

/// 스케줄에 대기 중인 근무 일정 변경 요청
class PendingChange extends Equatable {
  const PendingChange({
    required this.startTime,
    required this.endTime,
    required this.reason,
    required this.requestedBy,
    this.requestedAt,
    this.changeType = ScheduleChangeType.timeChange,
    this.status = ChangeRequestStatus.pending,
    this.substituteWorkerId,
    this.rejectReason,
    this.resolvedAt,
  });

  /// 변경 후 시작 (취소 요청 시 기존 시작과 동일할 수 있음)
  final DateTime startTime;

  /// 변경 후 종료
  final DateTime endTime;

  final String reason;
  final String requestedBy;
  final DateTime? requestedAt;

  final ScheduleChangeType changeType;
  final ChangeRequestStatus status;

  /// [ScheduleChangeType.substitute] 일 때 지명 대상
  final String? substituteWorkerId;

  /// 직원이 거절 시 작성한 사유
  final String? rejectReason;
  final DateTime? resolvedAt;

  Duration get duration => endTime.difference(startTime);

  bool get isPending => status == ChangeRequestStatus.pending;

  factory PendingChange.fromMap(Map<String, dynamic> map) {
    return PendingChange(
      startTime: _requireDateTime(map['startTime']),
      endTime: _requireDateTime(map['endTime']),
      reason: map['reason'] as String? ?? '',
      requestedBy: map['requestedBy'] as String? ?? '',
      requestedAt: _toDateTime(map['requestedAt']),
      changeType: ScheduleChangeType.fromFirestore(
        map['changeType'] as String? ?? map['change_type'] as String?,
      ),
      status: ChangeRequestStatus.fromFirestore(
        map['status'] as String? ?? map['changeRequestStatus'] as String?,
      ),
      substituteWorkerId: map['substituteWorkerId'] as String? ??
          map['substitute_worker_id'] as String?,
      rejectReason: map['rejectReason'] as String? ??
          map['reject_reason'] as String?,
      resolvedAt: _toDateTime(map['resolvedAt'] ?? map['resolved_at']),
    );
  }

  Map<String, dynamic> toMap({bool forCreate = false}) {
    return {
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'reason': reason,
      'requestedBy': requestedBy,
      'changeType': changeType.firestoreValue,
      'status': status.firestoreValue,
      if (substituteWorkerId != null)
        'substituteWorkerId': substituteWorkerId,
      if (rejectReason != null) 'rejectReason': rejectReason,
      if (forCreate)
        'requestedAt': FieldValue.serverTimestamp()
      else if (requestedAt != null)
        'requestedAt': Timestamp.fromDate(requestedAt!),
      if (resolvedAt != null) 'resolvedAt': Timestamp.fromDate(resolvedAt!),
    };
  }

  PendingChange copyWith({
    DateTime? startTime,
    DateTime? endTime,
    String? reason,
    String? requestedBy,
    DateTime? requestedAt,
    ScheduleChangeType? changeType,
    ChangeRequestStatus? status,
    String? substituteWorkerId,
    String? rejectReason,
    DateTime? resolvedAt,
  }) {
    return PendingChange(
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      reason: reason ?? this.reason,
      requestedBy: requestedBy ?? this.requestedBy,
      requestedAt: requestedAt ?? this.requestedAt,
      changeType: changeType ?? this.changeType,
      status: status ?? this.status,
      substituteWorkerId: substituteWorkerId ?? this.substituteWorkerId,
      rejectReason: rejectReason ?? this.rejectReason,
      resolvedAt: resolvedAt ?? this.resolvedAt,
    );
  }

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
        startTime,
        endTime,
        reason,
        requestedBy,
        requestedAt,
        changeType,
        status,
        substituteWorkerId,
        rejectReason,
        resolvedAt,
      ];
}
