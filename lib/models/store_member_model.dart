import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

import '../core/constants/firestore_paths.dart';
import 'enums/member_role.dart';

/// `store_members/{storeId}_{kakaoUid}` — 매장 ↔ 사용자 권한 매칭
class StoreMemberModel extends Equatable {
  const StoreMemberModel({
    required this.storeId,
    required this.userId,
    required this.role,
    required this.displayName,
    this.invitedBy,
    this.isActive = true,
    this.hourlyWage,
    this.joinedAt,
  });

  final String storeId;

  /// 카카오 UID (users Document ID)
  final String userId;
  final MemberRole role;
  final String displayName;

  /// 초대한 사장 UID
  final String? invitedBy;
  final bool isActive;
  final int? hourlyWage;
  final DateTime? joinedAt;

  String get docId => FirestorePaths.storeMemberDocId(storeId, userId);
  String get docPath => FirestorePaths.storeMember(storeId, userId);

  bool get isOwnerOrManager =>
      role == MemberRole.owner || role == MemberRole.manager;

  factory StoreMemberModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return StoreMemberModel.fromMap(doc.data() ?? {});
  }

  factory StoreMemberModel.fromMap(Map<String, dynamic> map) {
    return StoreMemberModel(
      storeId: map['storeId'] as String? ?? '',
      userId: map['userId'] as String? ?? '',
      role: MemberRole.fromFirestore(map['role'] as String? ?? 'parttime'),
      displayName: map['displayName'] as String? ?? '',
      invitedBy: map['invitedBy'] as String?,
      isActive: map['isActive'] as bool? ?? true,
      hourlyWage: map['hourlyWage'] as int?,
      joinedAt: _toDateTime(map['joinedAt']),
    );
  }

  Map<String, dynamic> toFirestore({bool forCreate = false}) {
    return {
      'storeId': storeId,
      'userId': userId,
      'role': role.firestoreValue,
      'displayName': displayName,
      if (invitedBy != null) 'invitedBy': invitedBy,
      'isActive': isActive,
      if (hourlyWage != null) 'hourlyWage': hourlyWage,
      if (forCreate) 'joinedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  static DateTime? _toDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  @override
  List<Object?> get props => [
        storeId,
        userId,
        role,
        displayName,
        invitedBy,
        isActive,
        hourlyWage,
        joinedAt,
      ];
}
