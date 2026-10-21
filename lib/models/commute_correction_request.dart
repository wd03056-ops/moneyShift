import 'package:equatable/equatable.dart';

import 'enums/commute_correction_status.dart';

/// 사장님 직권 출·퇴근 수정 → 알바 승인 대기 요청
class CommuteCorrectionRequest extends Equatable {
  const CommuteCorrectionRequest({
    required this.id,
    required this.roomId,
    required this.workerId,
    required this.requestedBy,
    required this.intent,
    required this.status,
    required this.createdAt,
    this.scheduleId,
    this.originalClockIn,
    this.originalClockOut,
    this.proposedClockIn,
    this.proposedClockOut,
    this.reason = '',
    this.resolvedAt,
  });

  final String id;
  final String roomId;
  final String workerId;
  final String requestedBy;
  final String? scheduleId;
  final CommuteCorrectionIntent intent;
  final CommuteCorrectionStatus status;

  final DateTime? originalClockIn;
  final DateTime? originalClockOut;
  final DateTime? proposedClockIn;
  final DateTime? proposedClockOut;

  final String reason;
  final DateTime createdAt;
  final DateTime? resolvedAt;

  CommuteCorrectionRequest copyWith({
    CommuteCorrectionStatus? status,
    DateTime? resolvedAt,
    DateTime? proposedClockIn,
    DateTime? proposedClockOut,
    CommuteCorrectionIntent? intent,
    String? reason,
  }) {
    return CommuteCorrectionRequest(
      id: id,
      roomId: roomId,
      workerId: workerId,
      requestedBy: requestedBy,
      scheduleId: scheduleId,
      intent: intent ?? this.intent,
      status: status ?? this.status,
      originalClockIn: originalClockIn,
      originalClockOut: originalClockOut,
      proposedClockIn: proposedClockIn ?? this.proposedClockIn,
      proposedClockOut: proposedClockOut ?? this.proposedClockOut,
      reason: reason ?? this.reason,
      createdAt: createdAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        roomId,
        workerId,
        status,
        intent,
        proposedClockIn,
        proposedClockOut,
      ];
}
