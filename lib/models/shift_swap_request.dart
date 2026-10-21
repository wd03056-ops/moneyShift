import 'package:equatable/equatable.dart';

import 'enums/shift_swap_status.dart';

/// 대타(Shift Swap) 요청
class ShiftSwapRequest extends Equatable {
  const ShiftSwapRequest({
    required this.id,
    required this.roomId,
    required this.scheduleId,
    required this.fromWorkerId,
    required this.toWorkerId,
    required this.reason,
    this.status = ShiftSwapStatus.pendingColleague,
    this.createdAt,
    this.resolvedAt,
  });

  final String id;
  final String roomId;
  final String scheduleId;

  /// 원래 근무자
  final String fromWorkerId;

  /// 대타 요청 대상 동료
  final String toWorkerId;

  final String reason;
  final ShiftSwapStatus status;
  final DateTime? createdAt;
  final DateTime? resolvedAt;

  ShiftSwapRequest copyWith({
    ShiftSwapStatus? status,
    DateTime? resolvedAt,
  }) {
    return ShiftSwapRequest(
      id: id,
      roomId: roomId,
      scheduleId: scheduleId,
      fromWorkerId: fromWorkerId,
      toWorkerId: toWorkerId,
      reason: reason,
      status: status ?? this.status,
      createdAt: createdAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        roomId,
        scheduleId,
        fromWorkerId,
        toWorkerId,
        reason,
        status,
        createdAt,
        resolvedAt,
      ];
}
