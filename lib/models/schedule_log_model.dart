import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

import '../core/constants/firestore_paths.dart';
import 'enums/schedule_log_action.dart';

/// `schedule_logs/{logId}` — 근무시간 변경 감사 이력
class ScheduleLogModel extends Equatable {
  const ScheduleLogModel({
    required this.id,
    required this.scheduleId,
    required this.roomId,
    required this.workerId,
    required this.action,
    required this.requestedBy,
    required this.reason,
    required this.previousStartTime,
    required this.previousEndTime,
    required this.newStartTime,
    required this.newEndTime,
    this.resolvedBy,
    this.createdAt,
  });

  final String id;
  final String scheduleId;
  final String roomId;
  final String workerId;
  final ScheduleLogAction action;

  /// 변경을 요청한 사람
  final String requestedBy;

  /// 승인/거절한 사람 (요청 시점에는 null)
  final String? resolvedBy;

  final String reason;
  final DateTime previousStartTime;
  final DateTime previousEndTime;
  final DateTime newStartTime;
  final DateTime newEndTime;
  final DateTime? createdAt;

  String get docPath => FirestorePaths.scheduleLog(id);

  factory ScheduleLogModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return ScheduleLogModel.fromMap(data, id: doc.id);
  }

  factory ScheduleLogModel.fromMap(Map<String, dynamic> map, {String? id}) {
    return ScheduleLogModel(
      id: id ?? map['id'] as String? ?? '',
      scheduleId: map['scheduleId'] as String? ?? '',
      roomId: map['roomId'] as String? ?? '',
      workerId: map['workerId'] as String? ?? '',
      action: ScheduleLogAction.fromFirestore(map['action'] as String?),
      requestedBy: map['requestedBy'] as String? ?? '',
      resolvedBy: map['resolvedBy'] as String?,
      reason: map['reason'] as String? ?? '',
      previousStartTime: _requireDateTime(map['previousStartTime']),
      previousEndTime: _requireDateTime(map['previousEndTime']),
      newStartTime: _requireDateTime(map['newStartTime']),
      newEndTime: _requireDateTime(map['newEndTime']),
      createdAt: _toDateTime(map['createdAt']),
    );
  }

  Map<String, dynamic> toFirestore({bool forCreate = false}) {
    return {
      'scheduleId': scheduleId,
      'roomId': roomId,
      'workerId': workerId,
      'action': action.firestoreValue,
      'requestedBy': requestedBy,
      if (resolvedBy != null) 'resolvedBy': resolvedBy,
      'reason': reason,
      'previousStartTime': Timestamp.fromDate(previousStartTime),
      'previousEndTime': Timestamp.fromDate(previousEndTime),
      'newStartTime': Timestamp.fromDate(newStartTime),
      'newEndTime': Timestamp.fromDate(newEndTime),
      if (forCreate) 'createdAt': FieldValue.serverTimestamp(),
    };
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
        id,
        scheduleId,
        roomId,
        workerId,
        action,
        requestedBy,
        resolvedBy,
        reason,
        previousStartTime,
        previousEndTime,
        newStartTime,
        newEndTime,
        createdAt,
      ];
}
