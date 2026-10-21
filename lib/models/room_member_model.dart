import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

import '../core/constants/app_constants.dart';
import '../core/constants/firestore_paths.dart';
import 'employee_contract_model.dart';
import 'enums/break_time_type.dart';
import 'enums/member_role.dart';

/// `room_members/{roomId}_{userId}` 문서
///
/// 사장이 초대하면 알바생이 방에 참여하며
/// [MemberRole] (`owner` | `manager` | `staff` | `parttime`) 중 하나로 매핑됩니다.
class RoomMemberModel extends Equatable {
  const RoomMemberModel({
    required this.roomId,
    required this.userId,
    required this.role,
    required this.displayName,
    this.isActive = true,
    this.contract = const EmployeeContractModel(),
    this.joinedAt,
  });

  final String roomId;
  final String userId;
  final MemberRole role;
  final String displayName;
  final bool isActive;

  /// 직원별 기본 시급·휴게·수당 설정
  final EmployeeContractModel contract;

  /// 시급 (원) — [contract.hourlyWage] 별칭 (기존 호출부 호환)
  int? get hourlyWage => contract.hourlyWage;

  final DateTime? joinedAt;

  String get docId => FirestorePaths.roomMemberDocId(roomId, userId);
  String get docPath => FirestorePaths.roomMember(roomId, userId);

  factory RoomMemberModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return RoomMemberModel.fromMap(data);
  }

  factory RoomMemberModel.fromMap(Map<String, dynamic> map) {
    final rawContract = map['contract'];
    final EmployeeContractModel contract;
    if (rawContract is Map) {
      contract = EmployeeContractModel.fromMap(
        Map<String, dynamic>.from(rawContract),
      );
    } else {
      contract = EmployeeContractModel(
        hourlyWage: (map['hourlyWage'] as num?)?.toInt() ??
            AppConstants.minimumHourlyWage,
        breakTimeType:
            BreakTimeType.fromFirestore(map['breakTimeType'] as String?),
        fixedBreakMinutes: (map['fixedBreakMinutes'] as num?)?.toInt() ?? 60,
        isWeekPayEnabled: map['isWeekPayEnabled'] as bool? ?? false,
        isNightPayEnabled: map['isNightPayEnabled'] as bool? ?? false,
        isOvertimePayEnabled: map['isOvertimePayEnabled'] as bool? ?? false,
      );
    }

    return RoomMemberModel(
      roomId: map['roomId'] as String? ?? '',
      userId: map['userId'] as String? ?? '',
      role: MemberRole.fromFirestore(map['role'] as String? ?? 'parttime'),
      displayName: map['displayName'] as String? ?? '',
      isActive: map['isActive'] as bool? ?? true,
      contract: contract,
      joinedAt: _toDateTime(map['joinedAt']),
    );
  }

  Map<String, dynamic> toFirestore({bool forCreate = false}) {
    return {
      'roomId': roomId,
      'userId': userId,
      'role': role.firestoreValue,
      'displayName': displayName,
      'isActive': isActive,
      'hourlyWage': contract.hourlyWage,
      'contract': contract.toMap(),
      if (forCreate) 'joinedAt': FieldValue.serverTimestamp(),
    };
  }

  RoomMemberModel copyWith({
    String? roomId,
    String? userId,
    MemberRole? role,
    String? displayName,
    bool? isActive,
    EmployeeContractModel? contract,
    int? hourlyWage,
    DateTime? joinedAt,
  }) {
    final nextContract = contract ??
        (hourlyWage != null
            ? this.contract.copyWith(hourlyWage: hourlyWage)
            : this.contract);
    return RoomMemberModel(
      roomId: roomId ?? this.roomId,
      userId: userId ?? this.userId,
      role: role ?? this.role,
      displayName: displayName ?? this.displayName,
      isActive: isActive ?? this.isActive,
      contract: nextContract,
      joinedAt: joinedAt ?? this.joinedAt,
    );
  }

  static DateTime? _toDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  @override
  List<Object?> get props => [
        roomId,
        userId,
        role,
        displayName,
        isActive,
        contract,
        joinedAt,
      ];
}
