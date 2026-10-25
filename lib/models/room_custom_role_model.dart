import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

import '../core/constants/firestore_paths.dart';
import 'enums/member_role.dart';

/// 사장이 만든 커스텀 직책 + 초대 코드
///
/// `rooms/{roomId}/custom_roles/{roleId}` 또는 목업 스토어에 저장.
/// 권한 판정은 [baseRole], UI 표시는 [name].
class RoomCustomRoleModel extends Equatable {
  const RoomCustomRoleModel({
    required this.id,
    required this.roomId,
    required this.name,
    required this.baseRole,
    required this.inviteCode,
    required this.inviteId,
    required this.createdBy,
    this.isActive = true,
    this.createdAt,
  });

  final String id;
  final String roomId;

  /// 표시용 직책명 (부점장, 야간 매니저 등)
  final String name;

  /// 실제 권한 매핑 (manager / staff / parttime)
  final MemberRole baseRole;

  final String inviteCode;
  final String inviteId;
  final String createdBy;
  final bool isActive;
  final DateTime? createdAt;

  String get docPath => FirestorePaths.roomCustomRole(roomId, id);

  factory RoomCustomRoleModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return RoomCustomRoleModel.fromMap(data, id: doc.id);
  }

  factory RoomCustomRoleModel.fromMap(Map<String, dynamic> map, {String? id}) {
    return RoomCustomRoleModel(
      id: id ?? map['id'] as String? ?? '',
      roomId: map['roomId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      baseRole: MemberRole.fromFirestore(
        map['baseRole'] as String? ?? MemberRole.staff.firestoreValue,
      ),
      inviteCode: map['inviteCode'] as String? ?? '',
      inviteId: map['inviteId'] as String? ?? '',
      createdBy: map['createdBy'] as String? ?? '',
      isActive: map['isActive'] as bool? ?? true,
      createdAt: _toDateTime(map['createdAt']),
    );
  }

  Map<String, dynamic> toFirestore({bool forCreate = false}) {
    return {
      'roomId': roomId,
      'name': name,
      'baseRole': baseRole.firestoreValue,
      'inviteCode': inviteCode,
      'inviteId': inviteId,
      'createdBy': createdBy,
      'isActive': isActive,
      if (forCreate) 'createdAt': FieldValue.serverTimestamp(),
    };
  }

  RoomCustomRoleModel copyWith({
    String? id,
    String? roomId,
    String? name,
    MemberRole? baseRole,
    String? inviteCode,
    String? inviteId,
    String? createdBy,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return RoomCustomRoleModel(
      id: id ?? this.id,
      roomId: roomId ?? this.roomId,
      name: name ?? this.name,
      baseRole: baseRole ?? this.baseRole,
      inviteCode: inviteCode ?? this.inviteCode,
      inviteId: inviteId ?? this.inviteId,
      createdBy: createdBy ?? this.createdBy,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  static DateTime? _toDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  @override
  List<Object?> get props => [
        id,
        roomId,
        name,
        baseRole,
        inviteCode,
        inviteId,
        createdBy,
        isActive,
        createdAt,
      ];
}
