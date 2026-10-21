import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

import '../core/constants/firestore_paths.dart';
import 'enums/shift_request_status.dart';
import 'enums/shift_request_type.dart';

/// `shift_requests/{id}` — 근무 변경·교대·휴가 요청
class ShiftRequestModel extends Equatable {
  const ShiftRequestModel({
    required this.id,
    required this.storeId,
    required this.applicantUid,
    required this.type,
    required this.status,
    this.approverUid,
    this.scheduleId,
    this.targetWorkerUid,
    this.reason,
    this.proposedStart,
    this.proposedEnd,
    this.resolvedAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String storeId;

  /// 요청자 카카오 UID
  final String applicantUid;

  /// 승인자(사장/매니저) UID
  final String? approverUid;

  final ShiftRequestType type;
  final ShiftRequestStatus status;
  final String? scheduleId;

  /// 교대 대상 동료 UID
  final String? targetWorkerUid;
  final String? reason;
  final DateTime? proposedStart;
  final DateTime? proposedEnd;
  final DateTime? resolvedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get docPath => FirestorePaths.shiftRequest(id);

  factory ShiftRequestModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return ShiftRequestModel.fromMap(doc.data() ?? {}, id: doc.id);
  }

  factory ShiftRequestModel.fromMap(Map<String, dynamic> map, {String? id}) {
    return ShiftRequestModel(
      id: id ?? map['id'] as String? ?? '',
      storeId: map['storeId'] as String? ?? '',
      applicantUid: map['applicantUid'] as String? ?? '',
      approverUid: map['approverUid'] as String?,
      type: ShiftRequestType.fromFirestore(map['type'] as String?),
      status: ShiftRequestStatus.fromFirestore(map['status'] as String?),
      scheduleId: map['scheduleId'] as String?,
      targetWorkerUid: map['targetWorkerUid'] as String?,
      reason: map['reason'] as String?,
      proposedStart: _toDateTime(map['proposedStart']),
      proposedEnd: _toDateTime(map['proposedEnd']),
      resolvedAt: _toDateTime(map['resolvedAt']),
      createdAt: _toDateTime(map['createdAt']),
      updatedAt: _toDateTime(map['updatedAt']),
    );
  }

  Map<String, dynamic> toFirestore({bool forCreate = false}) {
    return {
      'storeId': storeId,
      'applicantUid': applicantUid,
      if (approverUid != null) 'approverUid': approverUid,
      'type': type.firestoreValue,
      'status': status.firestoreValue,
      if (scheduleId != null) 'scheduleId': scheduleId,
      if (targetWorkerUid != null) 'targetWorkerUid': targetWorkerUid,
      if (reason != null) 'reason': reason,
      if (proposedStart != null)
        'proposedStart': Timestamp.fromDate(proposedStart!),
      if (proposedEnd != null) 'proposedEnd': Timestamp.fromDate(proposedEnd!),
      if (resolvedAt != null) 'resolvedAt': Timestamp.fromDate(resolvedAt!),
      'updatedAt': FieldValue.serverTimestamp(),
      if (forCreate) 'createdAt': FieldValue.serverTimestamp(),
    };
  }

  static DateTime? _toDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  @override
  List<Object?> get props => [
        id,
        storeId,
        applicantUid,
        approverUid,
        type,
        status,
        scheduleId,
        targetWorkerUid,
        reason,
        proposedStart,
        proposedEnd,
        resolvedAt,
        createdAt,
        updatedAt,
      ];
}
